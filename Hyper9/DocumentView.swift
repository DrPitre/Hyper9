//
//  DocumentView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 1/22/25.
//

import SwiftUI
import Turbo9Sim
import UniformTypeIdentifiers

struct DocumentView: View {
    // Bind to the document so changes are automatically saved.
    @Binding var document: SimDocument
    @EnvironmentObject var model: Turbo9ViewModel
    @State private var breakpoints: [Breakpoint] = []

    var body: some View {
        PersistentHSplitView(
            autosaveName: "Hyper9.MainSplit",
            leftMinWidth: 360,
            rightMinWidth: 360,
            model: model,
            left: { leftPane },
            right: { rightPane }
        )
        .onAppear { syncBreakpointsToModel() }
        .onChange(of: breakpoints) { _ in syncBreakpointsToModel() }
        .onReceive(model.$PC) { _ in }
    }

    // MARK: - Panes

    private var leftPane: some View {
        VStack {
            MemoryView()
            TabView {
                BreakpointView(breakpoints: $breakpoints)
                    .tabItem { Label("Breakpoints", systemImage: "stop.circle") }
                    .padding()
                TerminalView()
                    .tabItem { Label("Terminal", systemImage: "apple.terminal") }

                ScrollViewReader { _ in
                    ScrollView { TurbOSGlobalsView() }
                }
                .tabItem { Label("System Globals", systemImage: "globe") }

                ModuleDirectoryView()
                    .tabItem { Label("Module Directory", systemImage: "folder") }
                ProcessView()
                    .tabItem { Label("Processes", systemImage: "cpu") }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rightPane: some View {
        VStack(spacing: 6) {
            RegisterView()
            RunningStatusBar()
            DisassemblyView(breakpoints: $breakpoints)
            ControlView()
            StatisticsView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .task {
            model.updateUI()
            model.updateMemoryView()
        }
    }

    // MARK: -

    private func syncBreakpointsToModel() {
        let enabled = breakpoints.filter { $0.enabled }.map { $0.address }
        model.setBreakpoints(enabled)
    }
}

// MARK: - Running status bar

/// A pulsing red dot + "Running" + live counters that animate while the simulator runs;
/// collapses to a thin "Paused" pill when stopped, so the user always knows the state at a glance.
private struct RunningStatusBar: View {
    @EnvironmentObject var model: Turbo9ViewModel
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.running ? Color.red : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)
                .scaleEffect(model.running && pulse ? 1.35 : 1.0)
                .opacity(model.running && pulse ? 0.55 : 1.0)
                .animation(model.running
                           ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                           : .default,
                           value: pulse)

            Text(model.running ? "Running" : "Paused")
                .font(.system(.body, design: .default).weight(.semibold))
                .foregroundColor(model.running ? .red : .secondary)

            if model.running {
                Spacer().frame(width: 8)
                metric(icon: "gauge.medium",
                       value: model.turbo9.instructionsExecuted.formatted(.number))
                metric(icon: "speedometer",
                       value: formattedIPS(model.instructionsPerSecond))
                metric(icon: "clock",
                       value: model.turbo9.clockCycles.formatted(.number))
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((model.running ? Color.red : Color.secondary).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder((model.running ? Color.red : Color.secondary).opacity(0.35),
                                      lineWidth: 1)
                )
        )
        .onAppear { pulse.toggle() }
        .onChange(of: model.running) { _ in pulse.toggle() }
    }

    private func metric(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(value)
                .monospacedDigit()
                .contentTransition(.numericText())
                .font(.system(.body, design: .default))
        }
    }

    private func formattedIPS(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.2f MIPS", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.0f kIPS", value / 1_000)
        }
        return String(format: "%.0f IPS", value)
    }
}


#Preview {
    let model = Turbo9ViewModel()
    DocumentView(document: .constant(SimDocument()))
        .environmentObject(model)
}
