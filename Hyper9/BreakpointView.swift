//
//  BreakpointView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 2/15/25.
//

import SwiftUI

/// A single PC breakpoint with an enable flag. Identifiable so SwiftUI lists can
/// track rows across toggles, and Equatable so `.onChange(of:)` works in callers.
struct Breakpoint: Identifiable, Equatable {
    let id: UUID
    var address: UInt16
    var enabled: Bool

    init(id: UUID = UUID(), address: UInt16, enabled: Bool = true) {
        self.id = id
        self.address = address
        self.enabled = enabled
    }
}

struct BreakpointView: View {
    @EnvironmentObject var model: Turbo9ViewModel
    @Binding var breakpoints: [Breakpoint]
    @State private var newBreakpoint: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Address (hex, e.g. C100)", text: $newBreakpoint)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit(addBreakpoint)
                Button(action: addBreakpoint) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(parsedAddress(newBreakpoint) == nil)
                .help("Add breakpoint")
            }
            .padding()

            if breakpoints.isEmpty {
                Spacer()
                Text("No breakpoints.\nTip: click a line in the Code view to toggle one.")
                    .multilineTextAlignment(.center)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach($breakpoints) { $bp in
                        HStack {
                            Toggle("", isOn: $bp.enabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .help(bp.enabled ? "Enabled — execution will stop here" : "Disabled — execution will not stop here")

                            Text(String(format: "$%04X", bp.address))
                                .monospaced()
                                .foregroundColor(bp.enabled ? .primary : .secondary)

                            let symbol = model.turbo9.symbol(for: bp.address)
                            if !symbol.isEmpty {
                                Text(symbol)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(bp.enabled ? .purple : .secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: { removeBreakpoint(id: bp.id) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .help("Remove breakpoint")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func addBreakpoint() {
        guard let addr = parsedAddress(newBreakpoint) else { return }
        if !breakpoints.contains(where: { $0.address == addr }) {
            breakpoints.append(Breakpoint(address: addr))
        }
        newBreakpoint = ""
    }

    private func removeBreakpoint(id: UUID) {
        breakpoints.removeAll { $0.id == id }
    }

    private func parsedAddress(_ s: String) -> UInt16? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // asUInt16FromHex returns 0 for unparseable input; require at least one hex char to accept.
        var stripped = trimmed.uppercased()
        if stripped.hasPrefix("$") { stripped.removeFirst() }
        if stripped.hasPrefix("0X") { stripped.removeFirst(2) }
        guard !stripped.isEmpty, stripped.allSatisfy({ $0.isHexDigit }) else { return nil }
        return UInt16(stripped, radix: 16)
    }
}

#Preview {
    @Previewable @State var b: [Breakpoint] = [Breakpoint(address: 0xC100)]
    let model = Turbo9ViewModel()
    return BreakpointView(breakpoints: $b)
        .environmentObject(model)
}
