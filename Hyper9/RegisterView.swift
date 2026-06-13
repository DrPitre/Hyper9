//
//  RegisterView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 1/26/25.
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var model: Turbo9ViewModel

    private var canHighlight: Bool { !model.running }

    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 18) {
                accumulatorSection
                pointerSection
                Spacer(minLength: 0)
                ccSection
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        } label: {
            Label("Registers", systemImage: "cpu")
        }
    }

    // MARK: - Sections

    private var accumulatorSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("8-BIT")
            HStack(spacing: 6) {
                Reg8Cell(label: "A",  value: $model.A,  changed: canHighlight && model.previousA != model.A,  apply: { model.turbo9.A  = model.A })
                Reg8Cell(label: "B",  value: $model.B,  changed: canHighlight && model.previousB != model.B,  apply: { model.turbo9.B  = model.B })
                Reg8Cell(label: "DP", value: $model.DP, changed: canHighlight && model.previousDP != model.DP, apply: { model.turbo9.DP = model.DP })
            }
            // D = A:B, derived. Read-only.
            HStack(spacing: 6) {
                DerivedRegCell(label: "D",
                               value: (UInt16(model.A) << 8) | UInt16(model.B),
                               changed: canHighlight && (model.previousA != model.A || model.previousB != model.B))
            }
        }
    }

    private var pointerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("16-BIT")
            HStack(spacing: 6) {
                Reg16Cell(label: "X", value: $model.X, changed: canHighlight && model.previousX != model.X, apply: { model.turbo9.X = model.X })
                Reg16Cell(label: "Y", value: $model.Y, changed: canHighlight && model.previousY != model.Y, apply: { model.turbo9.Y = model.Y })
            }
            HStack(spacing: 6) {
                Reg16Cell(label: "U", value: $model.U, changed: canHighlight && model.previousU != model.U, apply: { model.turbo9.U = model.U })
                Reg16Cell(label: "S", value: $model.S, changed: canHighlight && model.previousS != model.S, apply: { model.turbo9.S = model.S })
            }
            HStack(spacing: 6) {
                Reg16Cell(label: "PC", value: $model.PC, changed: canHighlight && model.previousPC != model.PC, apply: { model.turbo9.PC = model.PC })
            }
        }
    }

    private var ccSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("CC")
            CCFlagsView(cc: $model.CC, update: { model.turbo9.CC = model.CC })
                .changedHighlight(canHighlight && model.previousCC != model.CC)
            Text(String(format: "$%02X", model.CC))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondary)
            .tracking(0.5)
    }
}

// MARK: - Register cells

/// Hex-editable 8-bit register cell with a "label = $XX (decimal)" stack.
private struct Reg8Cell: View {
    let label: String
    @Binding var value: UInt8
    let changed: Bool
    let apply: () -> Void

    @State private var editing: Bool = false
    @State private var text: String = ""

    private static let cellWidth: CGFloat = 66 // 18 (label) + 4 (gap) + 44 (field)

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 18, alignment: .leading)
                TextField("", text: textBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
                            )
                    )
            }
            Text("\(value)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: Self.cellWidth, alignment: .trailing)
                .padding(.trailing, 2)
        }
        .changedHighlight(changed)
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { String(format: "$%02X", value) },
            set: { newValue in
                var raw = newValue.uppercased().trimmingCharacters(in: .whitespaces)
                if raw.hasPrefix("$") { raw.removeFirst() }
                if raw.hasPrefix("0X") { raw.removeFirst(2) }
                if let v = UInt8(raw, radix: 16) {
                    value = v
                    apply()
                }
            }
        )
    }
}

/// Hex-editable 16-bit register cell.
private struct Reg16Cell: View {
    let label: String
    @Binding var value: UInt16
    let changed: Bool
    let apply: () -> Void

    private static let cellWidth: CGFloat = 86 // 18 (label) + 4 (gap) + 64 (field)

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 18, alignment: .leading)
                TextField("", text: textBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
                            )
                    )
            }
            Text("\(value)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: Self.cellWidth, alignment: .trailing)
                .padding(.trailing, 2)
        }
        .changedHighlight(changed)
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { String(format: "$%04X", value) },
            set: { newValue in
                var raw = newValue.uppercased().trimmingCharacters(in: .whitespaces)
                if raw.hasPrefix("$") { raw.removeFirst() }
                if raw.hasPrefix("0X") { raw.removeFirst(2) }
                if let v = UInt16(raw, radix: 16) {
                    value = v
                    apply()
                }
            }
        )
    }
}

/// Read-only derived register (e.g. D = A:B).
private struct DerivedRegCell: View {
    let label: String
    let value: UInt16
    let changed: Bool

    private static let cellWidth: CGFloat = 86

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 18, alignment: .leading)
                Text(String(format: "$%04X", value))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 64, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                            )
                    )
            }
            Text("\(value)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: Self.cellWidth, alignment: .trailing)
                .padding(.trailing, 2)
        }
        .changedHighlight(changed)
    }
}

// MARK: - CC flag toggle row

struct CCFlagsView: View {
    @Binding var cc: UInt8
    var update: () -> Void = {}

    // 6809 CC layout: bit 7 = E, ... , bit 0 = C
    private let flags: [(letter: String, mask: UInt8)] = [
        ("E", 0x80), ("F", 0x40), ("H", 0x20), ("I", 0x10),
        ("N", 0x08), ("Z", 0x04), ("V", 0x02), ("C", 0x01)
    ]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(flags, id: \.letter) { flag in
                let isSet = (cc & flag.mask) != 0
                Button(action: {
                    cc ^= flag.mask
                    update()
                }) {
                    Text(flag.letter)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 18, height: 20)
                        .foregroundColor(isSet ? .white : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSet ? Color.accentColor : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(isSet ? Color.accentColor : Color.secondary.opacity(0.35),
                                                      lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .help(name(for: flag.letter))
            }
        }
    }

    private func name(for letter: String) -> String {
        switch letter {
        case "E": return "Entire — all registers stacked"
        case "F": return "FIRQ mask"
        case "H": return "Half carry"
        case "I": return "IRQ mask"
        case "N": return "Negative"
        case "Z": return "Zero"
        case "V": return "Overflow"
        case "C": return "Carry"
        default: return letter
        }
    }
}

// MARK: - Changed value highlight modifier

private struct ChangedHighlightModifier: ViewModifier {
    let changed: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(changed ? Color.yellow.opacity(0.30) : Color.clear)
                    .padding(-2)
                    .animation(.easeOut(duration: 0.25), value: changed)
            )
    }
}

extension View {
    fileprivate func changedHighlight(_ changed: Bool) -> some View {
        modifier(ChangedHighlightModifier(changed: changed))
    }
}

#Preview {
    let model = Turbo9ViewModel()
    RegisterView()
        .environmentObject(model)
}
