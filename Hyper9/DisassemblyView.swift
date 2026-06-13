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
                                ForEach(model.operations.indices, id: \.self) { index in
                                    let op = model.operations[index]
                                    let isCurrent = (model.PC == op.offset) && model.running == false
                                    let bpState = breakpointState(at: op.offset)
                                    InstructionRow(
                                        op: op,
                                        isCurrent: isCurrent,
                                        breakpoint: bpState,
                                        fontSize: fontSize
                                    )
                                    .id(op.offset)
                                    .contentShape(Rectangle())
                                    .onTapGesture { toggleBreakpoint(at: op.offset) }
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
                            scrollToPC(proxy: proxy, animated: true)
                        }
                        .onChange(of: model.PC) { _ in scrollToPC(proxy: proxy, animated: true) }
                        .onChange(of: followPC) { enabled in
                            if enabled { scrollToPC(proxy: proxy, animated: true) }
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
        let needed = max(1, Int(ceil(height / lineHeight)))
        model.ensureDisassembly(lineCount: needed)
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
}

private enum BreakpointState {
    case none, enabled, disabled
}

private struct InstructionRow: View {
    let op: Disassembler.Turbo9Operation
    let isCurrent: Bool
    let breakpoint: BreakpointState
    let fontSize: CGFloat

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

            // Mnemonic — bold accent
            Text(op.mnemonicText)
                .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: mnemonicColumnWidth, alignment: .leading)

            // Operand — primary
            Text(op.operandText)
                .monospaced()
                .font(.system(size: fontSize))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .background(isCurrent ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    // Column widths derived from font size so they scale together.
    private var charWidth: CGFloat { fontSize * 0.62 }
    private var addressColumnWidth: CGFloat { charWidth * 5 }   // "C100 "
    private var bytesColumnWidth: CGFloat { charWidth * 10 }    // up to 8 hex + slack
    private var labelColumnWidth: CGFloat { charWidth * 18 }
    private var mnemonicColumnWidth: CGFloat { charWidth * 8 }
}

