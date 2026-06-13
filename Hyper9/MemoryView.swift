import SwiftUI

private struct MemoryRowView: View {
    let row: Int
    let bytes: [UInt8]
    let previousBytes: [UInt8]
    let highlight: Color
    let showChanges: Bool

    private var address: UInt16 { UInt16(row * 16) }

    private var attributedText: AttributedString {
        let start = row * 16
        guard !bytes.isEmpty, start < bytes.count else {
            return AttributedString(String(format: "%04X", address))
        }
        let end = min(start + 16, bytes.count)

        var result = AttributedString(String(format: "%04X  ", address))

        // Hex bytes
        for i in start..<end {
            if i - start == 8 {
                result += AttributedString(" ")
            }
            var byte = AttributedString(String(format: "%02X ", bytes[i]))
            if changed(at: i) {
                byte.backgroundColor = Color.yellow.opacity(0.45)
            }
            result += byte
        }

        // Gap + ASCII
        result += AttributedString(" ")
        for i in start..<end {
            let b = bytes[i]
            let ch = (b >= 32 && b < 127) ? String(Character(UnicodeScalar(b))) : "."
            var glyph = AttributedString(ch)
            if changed(at: i) {
                glyph.backgroundColor = Color.yellow.opacity(0.45)
            }
            result += glyph
        }

        return result
    }

    private func changed(at index: Int) -> Bool {
        showChanges
            && index < previousBytes.count
            && index < bytes.count
            && previousBytes[index] != bytes[index]
    }

    var body: some View {
        Text(attributedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlight)
    }
}

struct MemoryView: View {
    @EnvironmentObject var model: Turbo9ViewModel

    private let rowCount = 4096   // 65536 bytes / 16 per row

    @State private var followPC: Bool = true
    @State private var gotoInput: String = ""
    @State private var fontSize: CGFloat = 11

    private static let displayCharCount: CGFloat = 77
    private static let minFontSize: CGFloat = 9
    private static let maxFontSize: CGFloat = 22
    private static let monoCharRatio: CGFloat = 0.62
    private static let horizontalChrome: CGFloat = 8

    private func adjustedFontSize(for width: CGFloat) -> CGFloat {
        guard width > 0 else { return fontSize }
        let usable = max(0, width - Self.horizontalChrome)
        let raw = usable / (Self.displayCharCount * Self.monoCharRatio)
        return min(Self.maxFontSize, max(Self.minFontSize, raw))
    }

    var body: some View {
        GroupBox {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    toolbar(proxy: proxy)
                    Divider()
                    columnHeader
                    Divider()
                    memoryList
                }
                .onChange(of: model.PC) { _ in scrollToPC(proxy: proxy, animated: true) }
                .onChange(of: model.memorySnapshot) { _ in scrollToPC(proxy: proxy, animated: false) }
                .onChange(of: followPC) { enabled in
                    if enabled { scrollToPC(proxy: proxy, animated: true) }
                }
                .onAppear { scrollToPC(proxy: proxy, animated: false) }
            }
        } label: {
            Label("Memory", systemImage: "memorychip")
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { fontSize = adjustedFontSize(for: geo.size.width) }
                    .onChange(of: geo.size.width) { newWidth in
                        fontSize = adjustedFontSize(for: newWidth)
                    }
            }
        )
    }

    // MARK: - Subviews

    @ViewBuilder
    private func toolbar(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            Text("Go to:")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("$0000", text: $gotoInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 80)
                .onSubmit { performGoto(proxy: proxy) }
            Button("Go") { performGoto(proxy: proxy) }
                .controlSize(.small)
            Toggle("Follow PC", isOn: $followPC)
                .toggleStyle(.switch)
                .controlSize(.small)
            Spacer()
            legend
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendSwatch(Color.accentColor.opacity(0.35), "PC")
            legendSwatch(Color.green.opacity(0.35), "S")
            legendSwatch(Color.purple.opacity(0.15), "DP")
            legendSwatch(Color.orange.opacity(0.15), "IO")
            legendSwatch(Color.yellow.opacity(0.45), "Δ")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func legendSwatch(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 0.5))
                .frame(width: 10, height: 10)
            Text(label)
        }
    }

    private var columnHeader: some View {
        Text("Addr   0  1  2  3  4  5  6  7   8  9  A  B  C  D  E  F  0123456789ABCDEF")
            .font(.system(size: fontSize, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
    }

    private var memoryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { row in
                    let addr = UInt16(row * 16)
                    MemoryRowView(
                        row: row,
                        bytes: model.memorySnapshot,
                        previousBytes: model.previousMemorySnapshot,
                        highlight: rowHighlight(address: addr),
                        showChanges: !model.running
                    )
                    .id(row)
                    .padding(.horizontal, 4)
                }
            }
        }
        .font(.system(size: fontSize, design: .monospaced))
    }

    // MARK: - Helpers

    private func rowHighlight(address: UInt16) -> Color {
        let pcRowAddr = model.PC & 0xFFF0
        let sRowAddr  = model.S  & 0xFFF0
        if address == pcRowAddr { return Color.accentColor.opacity(0.35) }
        if address == sRowAddr  { return Color.green.opacity(0.35) }
        if address >= 0xFF00    { return Color.orange.opacity(0.15) }
        let dpBase = UInt16(model.DP) << 8
        if address >= dpBase && address < dpBase &+ 0x100 {
            return Color.purple.opacity(0.15)
        }
        return .clear
    }

    private func scrollToPC(proxy: ScrollViewProxy, animated: Bool) {
        guard followPC else { return }
        let target = Int(model.PC) / 16
        if animated {
            withAnimation(.easeInOut(duration: 0.15)) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func performGoto(proxy: ScrollViewProxy) {
        let trimmed = gotoInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let address = trimmed.asUInt16FromHex
        let row = Int(address) / 16
        withAnimation(.easeInOut(duration: 0.15)) {
            proxy.scrollTo(row, anchor: .top)
        }
    }
}

#Preview {
    let model = Turbo9ViewModel()
    MemoryView()
        .environmentObject(model)
}
