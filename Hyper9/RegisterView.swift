//
//  RegisterView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 1/26/25.
//

import SwiftUI

struct RegisterView : View {
    @EnvironmentObject var model: Turbo9ViewModel

    let viewWidth = 116.0
    let fieldWidth = 100.0
    let labelWidth = 28.0

    private var canHighlight: Bool { !model.running }

    var body: some View {
        GroupBox {
            HStack {
                VStack {
                    HStack {
                        LabeledHex8TextField(label: "A:", number: $model.A, update: {model.turbo9.A = model.A})
                            .changedHighlight(canHighlight && model.previousA != model.A)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        LabeledHex8TextField(label: "B:", number: $model.B, update: {model.turbo9.B = model.B})
                            .changedHighlight(canHighlight && model.previousB != model.B)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LabeledHex8TextField(label: "DP:", number: $model.DP, update: {model.turbo9.DP = model.DP})
                            .changedHighlight(canHighlight && model.previousDP != model.DP)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                VStack {
                    LabeledHex16TextField(label: "X:", number: $model.X, update: {model.turbo9.X = model.X})
                        .changedHighlight(canHighlight && model.previousX != model.X)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LabeledHex16TextField(label: "Y:", number: $model.Y, update: {model.turbo9.Y = model.Y})
                        .changedHighlight(canHighlight && model.previousY != model.Y)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack {
                    LabeledHex16TextField(label: "U:", number: $model.U, update: {model.turbo9.U = model.U})
                        .changedHighlight(canHighlight && model.previousU != model.U)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LabeledHex16TextField(label: "S:", number: $model.S, update: {model.turbo9.S = model.S})
                        .changedHighlight(canHighlight && model.previousS != model.S)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack {
                    LabeledHex16TextField(label: "PC:", number: $model.PC, update: {model.turbo9.PC = model.PC})
                        .changedHighlight(canHighlight && model.previousPC != model.PC)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Text("CC:")
                            .frame(width: 28)
                        CCFlagsView(cc: $model.CC, update: { model.turbo9.CC = model.CC })
                            .changedHighlight(canHighlight && model.previousCC != model.CC)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } label: {
            Label("Registers", systemImage: "cpu")
        }
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
        HStack(spacing: 2) {
            ForEach(flags, id: \.letter) { flag in
                let isSet = (cc & flag.mask) != 0
                Button(action: {
                    cc ^= flag.mask
                    update()
                }) {
                    Text(flag.letter)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 16, height: 18)
                        .foregroundColor(isSet ? .white : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isSet ? Color.accentColor : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
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
                    .fill(changed ? Color.yellow.opacity(0.35) : Color.clear)
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
