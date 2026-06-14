import SwiftUI
import Turbo9Sim

extension String {
    /// Returns a new string padded with spaces to the specified total length.
    func padded(toLength length: Int) -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self } // No padding needed if already at or over the desired length
        return self + String(repeating: " ", count: padCount)
    }
}

struct DisassemblyView: View {
    @EnvironmentObject var model : Turbo9ViewModel
    @Binding var breakpoints: [Breakpoint]
    @State private var followPC: Bool = true

    private let fontSize: CGFloat = 14
    private let lineHeight: CGFloat = 20

    /// Sliding-window bounds: how many ops we add per scroll-edge trigger and
    /// the hard cap that prevents the array from growing without bound.
    private let edgeChunk: Int = 32
    private let windowCap: Int = 300
    /// Rows close to the top/bottom of the cached list that trigger a fetch
    /// when they appear (i.e. the user has scrolled to the edge).
    private let edgeTrigger: Int = 3
    /// Min interval between extensions in the same direction. Without this,
    /// prepending rows at index 0 fires `.onAppear` again on the new index 0,
    /// cascading until the cap is hit.
    private let extensionCooldown: TimeInterval = 0.25
    @State private var lastBackwardFire: Date = .distantPast
    @State private var lastForwardFire: Date = .distantPast

    var body: some View {
        GroupBox {
            VStack(spacing: 0) {
                HStack {
                    Toggle("Follow PC", isOn: $followPC)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    Spacer()
                    Text("Click a line to toggle a breakpoint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 4)

                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                // Key by op.offset so SwiftUI's diffing tracks
                                // each instruction by its address, not by its
                                // position in the array. Using index identity
                                // here led to clicks binding to the wrong row
                                // whenever the ops array was rebuilt/shifted
                                // (snapToPC, sliding-window edge extension,
                                // PC change after a run+pause). Pass index
                                // alongside for zebra striping / edge fetch.
                                ForEach(Array(model.operations.enumerated()), id: \.element.offset) { index, op in
                                    let isCurrent = (model.PC == op.offset) && model.running == false
                                    let bpState = breakpointState(at: op.offset)
                                    InstructionRow(
                                        op: op,
                                        targetSymbol: op.branchTarget.flatMap { addr -> String? in
                                            let s = model.turbo9.symbol(for: addr)
                                            return s.isEmpty ? nil : s
                                        },
                                        isCurrent: isCurrent,
                                        isZebra: index.isMultiple(of: 2),
                                        breakpoint: bpState,
                                        fontSize: fontSize,
                                        gotoOffset: { target in
                                            scrollToTarget(target, proxy: proxy)
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { toggleBreakpoint(at: op.offset) }
                                    .onAppear { handleRowAppear(index: index) }
                                }
                            }
                        }
                        .onAppear {
                            fillDisassembly(for: geo.size.height)
                            scrollToPC(proxy: proxy, animated: false)
                        }
                        .onChange(of: geo.size.height) { _ in fillDisassembly(for: geo.size.height) }
                        .onChange(of: model.operations.count) { _ in
                            fillDisassembly(for: geo.size.height)
                            // Only chase PC on count changes when we're following
                            // it. Otherwise an edge-triggered extension would
                            // yank the view back to PC mid-scroll.
                            if followPC { scrollToPC(proxy: proxy, animated: true) }
                        }
                        .onChange(of: model.PC) { _ in scrollToPC(proxy: proxy, animated: true) }
                        .onChange(of: followPC) { enabled in
                            if enabled { scrollToPC(proxy: proxy, animated: true) }
                        }
                        .onChange(of: model.running) { isRunning in
                            // PLAY just pressed — snap to PC so the user can see
                            // where execution is starting from, even if they'd
                            // scrolled away. Bypass the normal scrollToPC guards
                            // (which suppress scrolling while `running` is true).
                            if isRunning {
                                snapToPC(proxy: proxy)
                            }
                        }
                    }
                }
                .frame(minWidth: 480, idealWidth: 640, maxWidth: .infinity,
                       minHeight: 300, idealHeight: 540, maxHeight: .infinity)
            }
        } label: {
            Label("Code", systemImage: "text.page")
        }
    }

    private func fillDisassembly(for height: CGFloat) {
        let visible = max(1, Int(ceil(height / lineHeight)))
        // Pre-fill comfortably more than what fits on screen so the scroll
        // bar is active and the user has room to drag past the visible edge
        // before the sliding-window edge triggers kick in.
        let needed = max(visible * 3, 60)
        model.ensureDisassembly(lineCount: needed)
    }

    /// Sliding-window trigger: when a row near either edge of the cached ops
    /// appears, fetch more in that direction. Cooldown-gated so a single
    /// user scroll doesn't fire repeatedly while LazyVStack churn settles.
    private func handleRowAppear(index: Int) {
        let count = model.operations.count
        guard count > 0 else { return }
        let now = Date()
        if index <= edgeTrigger {
            guard now.timeIntervalSince(lastBackwardFire) > extensionCooldown else { return }
            lastBackwardFire = now
            model.extendDisassemblyBackward(lines: edgeChunk, cap: windowCap)
        } else if index >= count - 1 - edgeTrigger {
            guard now.timeIntervalSince(lastForwardFire) > extensionCooldown else { return }
            lastForwardFire = now
            model.extendDisassemblyForward(lines: edgeChunk, cap: windowCap)
        }
    }

    private func scrollToPC(proxy: ScrollViewProxy, animated: Bool) {
        guard followPC, !model.running else { return }
        let pc = model.PC
        guard model.operations.contains(where: { $0.offset == pc }) else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(pc, anchor: .center)
            }
        } else {
            proxy.scrollTo(pc, anchor: .center)
        }
    }

    /// One-shot scroll to the current PC that bypasses the `running` guard.
    /// If PC isn't in the cached operations (the user has scrolled far from
    /// it), refill the cache around PC first. Used when the user presses PLAY.
    private func snapToPC(proxy: ScrollViewProxy) {
        let pc = model.PC
        if !model.operations.contains(where: { $0.offset == pc }) {
            // Rebuild the cache so it's centered on PC.
            model.turbo9.operations = []
            model.turbo9.checkDisassembly()
            model.updateMemoryView()
        }
        // Defer to next runloop tick so SwiftUI has a chance to realize the
        // newly-published ops before we try to scroll to one of their ids.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(pc, anchor: .center)
            }
        }
    }

    private func breakpointState(at address: UInt16) -> BreakpointState {
        if let bp = breakpoints.first(where: { $0.address == address }) {
            return bp.enabled ? .enabled : .disabled
        }
        return .none
    }

    private func toggleBreakpoint(at address: UInt16) {
        if let idx = breakpoints.firstIndex(where: { $0.address == address }) {
            breakpoints.remove(at: idx)
        } else {
            breakpoints.append(Breakpoint(address: address))
        }
    }

    /// Branch-target click handler. If the target is in the loaded operations
    /// list, scroll the disassembly to it; otherwise fall back to jumping
    /// the memory view there.
    private func scrollToTarget(_ target: UInt16, proxy: ScrollViewProxy) {
        if model.operations.contains(where: { $0.offset == target }) {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            model.memoryGotoTarget = target
        }
    }
}

private enum BreakpointState {
    case none, enabled, disabled
}

private struct InstructionRow: View {
    let op: Disassembler.Turbo9Operation
    let targetSymbol: String?
    let isCurrent: Bool
    let isZebra: Bool
    let breakpoint: BreakpointState
    let fontSize: CGFloat
    let gotoOffset: (UInt16) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Gutter: breakpoint dot — solid for enabled, hollow for disabled
            ZStack {
                switch breakpoint {
                case .enabled:
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                case .disabled:
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 1.5)
                        .frame(width: 8, height: 8)
                case .none:
                    EmptyView()
                }
            }
            .frame(width: 16)

            // Left accent bar: highlights current PC
            Rectangle()
                .fill(isCurrent ? Color.accentColor : Color.clear)
                .frame(width: 3)
                .padding(.trailing, 6)

            // Address — dim, fixed width
            Text(op.addressText)
                .monospaced()
                .font(.system(size: fontSize))
                .foregroundColor(.secondary)
                .frame(width: addressColumnWidth, alignment: .leading)

            // Raw bytes — slightly dim, fixed width
            Text(op.bytesText)
                .monospaced()
                .font(.system(size: fontSize))
                .foregroundColor(Color.secondary.opacity(0.8))
                .frame(width: bytesColumnWidth, alignment: .leading)

            // Label — only shown if there is one
            Text(op.labelText)
                .monospaced()
                .font(.system(size: fontSize))
                .foregroundColor(.purple)
                .frame(width: labelColumnWidth, alignment: .leading)
                .lineLimit(1)

            // Mnemonic — bolder + accent-colored on the current PC line
            Text(op.mnemonicText)
                .font(.system(size: fontSize,
                              weight: isCurrent ? .bold : .semibold,
                              design: .monospaced))
                .foregroundColor(isCurrent ? Color.accentColor : .primary)
                .frame(width: mnemonicColumnWidth, alignment: .leading)

            // Operand — color-coded by addressing mode; hyperlinked when it
            // targets a code address.
            operandView

            // Optional trailing comment: resolved symbol for a branch target.
            if let symbol = targetSymbol {
                Text("→ \(symbol)")
                    .monospaced()
                    .font(.system(size: fontSize))
                    .foregroundColor(Color.purple.opacity(0.8))
                    .lineLimit(1)
                    .padding(.leading, 8)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .background(rowBackground)
    }

    @ViewBuilder
    private var operandView: some View {
        let target = op.branchTarget
        let base = Text(op.operandText)
            .monospaced()
            .font(.system(size: fontSize))
            .foregroundColor(operandColor)
            .lineLimit(1)
        if let target {
            base
                .underline()
                .help("Jump to \(String(format: "$%04X", target))")
                .highPriorityGesture(
                    TapGesture().onEnded { gotoOffset(target) }
                )
        } else {
            base
        }
    }

    /// Layered background: PC tint > zebra stripe > clear.
    @ViewBuilder
    private var rowBackground: some View {
        if isCurrent {
            Color.accentColor.opacity(0.18)
        } else if isZebra {
            Color.secondary.opacity(0.05)
        } else {
            Color.clear
        }
    }

    /// Operand color keyed off the addressing mode.
    private var operandColor: Color {
        switch op.addressMode {
        case .imm8, .imm16: return .orange     // #immediate
        case .dir:          return .teal       // <direct
        case .ext:          return .blue       // >extended
        case .ind:          return .purple     // ,X / ,Y / ,U / ,S
        case .rel8, .rel16: return .green      // branch target
        case .inh:          return .secondary  // no operand
        }
    }

    // Column widths derived from font size so they scale together.
    private var charWidth: CGFloat { fontSize * 0.62 }
    private var addressColumnWidth: CGFloat { charWidth * 5 }   // "C100 "
    private var bytesColumnWidth: CGFloat { charWidth * 10 }    // up to 8 hex + slack
    private var labelColumnWidth: CGFloat { charWidth * 18 }
    private var mnemonicColumnWidth: CGFloat { charWidth * 8 }
}

