//
//  StatisticsView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 2/15/25.
//

import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var model: Turbo9ViewModel

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                StatRow(icon: "gauge.medium",
                        label: "Instr",
                        help: "Total instructions executed",
                        text: model.turbo9.instructionsExecuted.formatted(.number))
                StatRow(icon: "bolt.fill",
                        label: "Int",
                        help: "Interrupts received",
                        text: model.turbo9.interruptsReceived.formatted(.number))
                StatRow(icon: "clock",
                        label: "Cycles",
                        help: "Total clock cycles",
                        text: model.turbo9.clockCycles.formatted(.number))
                StatRow(icon: "speedometer",
                        label: "IPS",
                        help: "Instructions per second (most recent run)",
                        text: model.instructionsPerSecond.formatted(.number.precision(.fractionLength(0))))
            }
        } label: {
            Label("Statistics", systemImage: "chart.bar.fill")
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatRow: View {
    let icon: String
    let label: String
    let help: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .monospacedDigit()
                .contentTransition(.numericText())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 80, idealWidth: 100, maxWidth: 140, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 0.5)
                )
        }
        .help(help)
    }
}

#Preview {
    let model = Turbo9ViewModel()
    StatisticsView()
        .environmentObject(model)
}
