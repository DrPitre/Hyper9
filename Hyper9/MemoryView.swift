import SwiftUI

private struct MemoryRowView: View {
    let row: Int
    let bytes: [UInt8]
    let pcRow: Int

    private var address: UInt16 { UInt16(row * 16) }

    private var text: String {
        guard !bytes.isEmpty else { return String(format: "%04X", address) }
        let start = row * 16
        guard start < bytes.count else { return String(format: "%04X", address) }
        let end = min(start + 16, bytes.count)
        var hex = ""
        var ascii = ""
        for i in start..<end {
            if i - start == 8 { hex += " " }
            hex += String(format: "%02X ", bytes[i])
            let b = bytes[i]
            ascii += (b >= 32 && b < 127) ? String(Character(UnicodeScalar(b))) : "."
        }
        return String(format: "%04X  ", address) + hex + " " + ascii
    }

    var body: some View {
        Text(text)
            .background(row == pcRow ? Color.yellow.opacity(0.3) : Color.clear)
    }
}

struct MemoryView: View {
    @EnvironmentObject var model: Turbo9ViewModel

    private let rowCount = 4096   // 65536 bytes / 16 per row

    var body: some View {
        GroupBox {
            ScrollViewReader { proxy in
                ScrollView {
                    Text("Addr   0  1  2  3  4  5  6  7   8  9  A  B  C  D  E  F  0123456789ABCDEF")
                        .padding(.horizontal, 4)
                    Divider()
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<rowCount, id: \.self) { row in
                            MemoryRowView(
                                row: row,
                                bytes: model.memorySnapshot,
                                pcRow: Int(model.PC) / 16
                            )
                            .id(row)
                            .padding(.horizontal, 4)
                        }
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .onChange(of: model.memorySnapshot) { _ in
                    proxy.scrollTo(Int(model.PC) / 16, anchor: .center)
                }
            }
        } label: {
            Label("Memory", systemImage: "memorychip")
        }
    }
}

#Preview {
    let model = Turbo9ViewModel()
    MemoryView()
        .environmentObject(model)
}
