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

    @AppStorage("terminalFontSize") private var fontSize: Double = 14
    private static let minFontSize: Double = 9
    private static let maxFontSize: Double = 28

    // SF Mono em width is ~0.6 of the font size. A slight slack avoids subpixel rounding pushing
    // the 80th column off-screen and triggering a wrap that would break the columnar alignment.
    private var charWidth: CGFloat { CGFloat(fontSize) * 0.62 }
    private var minTerminalWidth: CGFloat { CGFloat(80) * charWidth }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            terminalArea
        }
        .onAppear { focused = true }
    }

    // MARK: - Subviews

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button(action: { model.clearOutput() }) {
                Label("Clear", systemImage: "trash")
            }
            .controlSize(.small)
            .help("Clear the terminal output")

            Button(action: copyAll) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .controlSize(.small)
            .help("Copy all terminal output to the clipboard")

            Spacer()

            Text("\(Int(fontSize)) pt")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
            Button(action: { fontSize = max(Self.minFontSize, fontSize - 1) }) {
                Image(systemName: "textformat.size.smaller")
            }
            .controlSize(.small)
            .help("Decrease terminal font size")
            .disabled(fontSize <= Self.minFontSize)
            Button(action: { fontSize = min(Self.maxFontSize, fontSize + 1) }) {
                Image(systemName: "textformat.size.larger")
            }
            .controlSize(.small)
            .help("Increase terminal font size")
            .disabled(fontSize >= Self.maxFontSize)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var terminalArea: some View {
        ZStack {
            // Key capture sits BEHIND the scroll view so scroll events
            // reach the ScrollView; key events go to the first responder.
            KeyCaptureView(isFocused: focused) { byte in
                model.sendInputChar(byte)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(output + (cursor.visible ? "█" : " "))
                            .padding()
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: minTerminalWidth, alignment: .topLeading)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.visible)
                .onChange(of: output) { _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .font(.system(size: CGFloat(fontSize), design: .monospaced))
            .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(focused ? Color.accentColor : Color.secondary.opacity(0.4),
                              lineWidth: focused ? 2 : 1)
        )
        .simultaneousGesture(TapGesture().onEnded { focused = true })
        .onReceive(model.$outputString) { output = $0 }
    }

    // MARK: - Actions

    private func copyAll() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)
    }
}

#Preview {
    let model = Turbo9ViewModel()
    TerminalView()
        .environmentObject(model)
}
