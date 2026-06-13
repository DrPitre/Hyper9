import SwiftUI
import AppKit

private class CursorBlinker: ObservableObject {
    @Published var visible = true
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.visible.toggle()
        }
    }
    deinit { timer?.invalidate() }
}

// MARK: - Key capture

private class KeyCaptureNSView: NSView {
    var onKey: (UInt8) -> Void = { _ in }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let chars = event.characters else { return }
        for byte in chars.utf8 {
            let out = byte == 0x0A ? UInt8(0x0D) : byte
            print("keyDown: 0x\(String(format: "%02X", out))")
            onKey(out)
        }
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    var isFocused: Bool
    var onKey: (UInt8) -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let v = KeyCaptureNSView()
        v.onKey = onKey
        return v
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKey = onKey
        if isFocused, let w = nsView.window, w.firstResponder !== nsView {
            w.makeFirstResponder(nsView)
        }
    }
}

// MARK: - Terminal view

struct TerminalView: View {
    @EnvironmentObject var model: Turbo9ViewModel
    @StateObject private var cursor = CursorBlinker()
    @State private var output: String = ""
    @State private var focused: Bool = false

    private let charWidth: CGFloat = 7

    var body: some View {
        GroupBox {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(output + (cursor.visible ? "█" : " "))
                                .padding()
                                .frame(
                                    width: CGFloat(80) * charWidth,
                                    alignment: .topLeading
                                )
                            Color.clear.frame(height: 1).id("bottom")
                        }
                    }
                    .onChange(of: output) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)

                KeyCaptureView(isFocused: focused) { byte in
                    model.sendInputChar(byte)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black.opacity(0.95))
            .border(focused ? Color.green : Color.gray)
            .onTapGesture { focused = true }
            .onReceive(model.$outputString) { output = $0 }
        } label: {
            Label("Terminal", systemImage: "apple.terminal")
        }
    }
}

#Preview {
    let model = Turbo9ViewModel()
    TerminalView()
        .environmentObject(model)
}
