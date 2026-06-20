//
//  ControlView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 2/15/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ControlView: View {
    @EnvironmentObject var model: Turbo9ViewModel
    @State var stepCount : UInt16 = 1
    @State var goLabel = "play.fill"
    @State private var symbolBase: UInt16 = 0x0000

    var body: some View {
        let cyclesPerTick : UInt = 1000
        let stepClosure :() -> Void = {
            if stepCount > 0 {
                model.updateCPU()
                let startTime = Date()
                
                for _ in 1...stepCount {
                    model.step()
                }
                model.instructionsPerSecond = Double(stepCount) / Date().timeIntervalSince(startTime)
                model.turbo9.checkDisassembly()
                model.updateUI()
                model.updateMemoryView()
            }
        }
        let runClosure : () -> Void = {
            if model.running == true {
                model.running = false
                goLabel = "play.fill"
                model.updateUI()
            } else {
                model.running = true
                goLabel = "pause.fill"
                model.updateCPU()
                let targetClockHz = model.targetClockHz
                DispatchQueue.global(qos: .userInitiated).async {
                    let startTime = Date()
                    let startCycles = model.turbo9.clockCycles
                    var instructionCount = 0
                    var breakpoint = false
                    var pendingUIUpdate = false
                    var lastUIUpdateTime = startTime
                    let uiUpdateInterval: TimeInterval = 0.05  // ~20 fps live status
                    // 0 Hz means "unthrottled". Otherwise pace against a wall-clock
                    // target derived from elapsed CPU clock cycles so the emulator
                    // runs at (approximately) the requested cycle rate. Sleeps are
                    // chunked to ≤ 50 ms so Pause stays responsive.
                    let throttled = targetClockHz > 0
                    let secondsPerCycle: TimeInterval = throttled ? 1.0 / Double(targetClockHz) : 0
                    let maxSleepChunk: TimeInterval = 0.05
                    repeat {
                        if breakpoint == false {
                            model.step()
                            instructionCount += 1
                            model.deliverNextInputIfReady()
                            if model.timerRunning == true && model.turbo9.clockCycles % cyclesPerTick == 0 {
                                model.invokeTimer()
                            }
                            if throttled {
                                let cyclesElapsed = model.turbo9.clockCycles &- startCycles
                                let target = startTime.addingTimeInterval(Double(cyclesElapsed) * secondsPerCycle)
                                var now = Date()
                                while now < target && model.running {
                                    let remaining = target.timeIntervalSince(now)
                                    Thread.sleep(forTimeInterval: min(remaining, maxSleepChunk))
                                    // Refresh UI mid-sleep so low-rate runs still tick visibly.
                                    let mid = Date()
                                    if mid.timeIntervalSince(lastUIUpdateTime) >= uiUpdateInterval && !pendingUIUpdate {
                                        lastUIUpdateTime = mid
                                        pendingUIUpdate = true
                                        let elapsed = mid.timeIntervalSince(startTime)
                                        let ips = elapsed > 0 ? Double(instructionCount) / elapsed : 0
                                        DispatchQueue.main.async {
                                            model.instructionsPerSecond = ips
                                            model.updateUI()
                                            pendingUIUpdate = false
                                        }
                                    }
                                    now = Date()
                                }
                            }
                            // UI update — wall-clock paced so it fires at any rate,
                            // not just every 1000 instructions. Amortize the Date()
                            // call in the hot unthrottled path with the % 1000 gate.
                            if !pendingUIUpdate && (throttled || instructionCount % 1_000 == 0) {
                                let now = Date()
                                if now.timeIntervalSince(lastUIUpdateTime) >= uiUpdateInterval {
                                    lastUIUpdateTime = now
                                    pendingUIUpdate = true
                                    let elapsed = now.timeIntervalSince(startTime)
                                    let ips = elapsed > 0 ? Double(instructionCount) / elapsed : 0
                                    DispatchQueue.main.async {
                                        model.instructionsPerSecond = ips
                                        model.updateUI()
                                        pendingUIUpdate = false
                                    }
                                }
                            }
                        }
                        if model.isBreakpoint(model.turbo9.PC) {
                            breakpoint = true
                        }
                    } while model.running == true && breakpoint == false
                    DispatchQueue.main.async {
                        model.instructionsPerSecond = Double(instructionCount) / Date().timeIntervalSince(startTime)
                        model.running = false
                        goLabel = "play.fill"
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                        model.updateMemoryView()
                    }
                }
            }
        }
        HStack {
            GroupBox {
                HStack {
                    Button(action: {
                        model.running = false
                        model.turbo9.assertIRQ()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "i.circle")
                    }
                    .help("Assert IRQ (maskable interrupt)")

                    Button(action: {
                        model.running = false
                        model.turbo9.assertFIRQ()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "f.circle")
                    }
                    .help("Assert FIRQ (fast interrupt)")

                    Button(action: {
                        model.running = false
                        model.turbo9.assertNMI()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "n.circle")
                    }
                    .help("Assert NMI (non-maskable interrupt)")

                    Button(action: {
                        model.running = false
                        model.invokeTimer()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "timer")
                    }
                    .help("Invoke timer tick")
                }
            } label: {
                Label("Interrupts", systemImage: "stop.fill")
            }

            GroupBox {
                HStack {
                    Button(action: runClosure) {
                        Image(systemName: goLabel)
                    }
                    .help(model.running ? "Pause execution (⌘R)" : "Run until breakpoint (⌘R)")
                    .keyboardShortcut("r", modifiers: .command)

                    Button(action: {
                        if let operation = model.turbo9.disassemble() {
                            if operation.isBranchSubroutineType() == true
                            {
                                runClosure()
                            } else {
                                stepClosure()
                            }
                        }
                    }) {
                        Image(systemName: "arrow.right")
                    }
                    .help("Step Over — execute current instruction, running through any subroutine call (⌘')")
                    .keyboardShortcut("'", modifiers: .command)
                    .disabled(model.running == true)

                    Button(action: {
                        stepClosure()
                    }) {
                        Image(systemName: "arrow.down")
                    }
                    .help("Step Into — execute one instruction (⌘;)")
                    .keyboardShortcut(";", modifiers: .command)
                    .disabled(model.running == true)

                    Picker("", selection: $model.targetClockHz) {
                        Text("Unlimited").tag(0)
                        Text("100 Hz").tag(100)
                        Text("1 kHz").tag(1_000)
                        Text("10 kHz").tag(10_000)
                        Text("100 kHz").tag(100_000)
                        Text("1 MHz").tag(1_000_000)
                        Text("2 MHz").tag(2_000_000)
                        Text("4 MHz").tag(4_000_000)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .help("Target CPU clock rate (cycles/sec). Applies on next Run.")
                    .disabled(model.running == true)
                }
            } label: {
                Label("Execution", systemImage: "figure.step.training")
            }

            GroupBox {
                HStack {
                    Button(action: {
                        let openPanel = NSOpenPanel()
                        openPanel.title = "Choose an image file"
                        openPanel.showsHiddenFiles = false
                        openPanel.canChooseDirectories = false
                        openPanel.canChooseFiles = true
                        openPanel.allowsMultipleSelection = false
                        openPanel.allowedContentTypes = [UTType(filenameExtension: "img")!]
                        
                        openPanel.begin { (result) in
                            if result == .OK, let url = openPanel.url {
                                model.load(url: url)
                                model.turbo9.checkDisassembly()
                                model.updateUI()
                                model.updateMemoryView()
                            } else {
                                // User canceled the selection
                            }
                        }
                        model.reset()
                    }) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("Load an image file (.img) and reset")
                    .disabled(model.running == true)

                    Button(action: {
                        let openPanel = NSOpenPanel()
                        openPanel.title = "Choose a symbol map file"
                        openPanel.showsHiddenFiles = false
                        openPanel.canChooseDirectories = false
                        openPanel.canChooseFiles = true
                        openPanel.allowsMultipleSelection = false
                        if let mapType = UTType(filenameExtension: "map") {
                            openPanel.allowedContentTypes = [mapType]
                        }
                        openPanel.begin { (result) in
                            if result == .OK, let url = openPanel.url {
                                model.loadSymbols(from: url)
                                model.updateUI()
                            }
                        }
                    }) {
                        Image(systemName: "tag.fill")
                    }
                    .help("Load a symbol map (.map) file to annotate the disassembly")
                    .disabled(model.running == true)

                    Hex16TextField(number: $symbolBase) {
                        model.setSymbolBase(symbolBase)
                    }
                    .help("Symbol base — added to module-relative .map addresses so labels match the runtime PC")

                    Button(action: {
                        model.reset()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "button.horizontal.top.press")
                    }
                    .help("Reset CPU")
                    .disabled(model.running == true)

                    Toggle("log", systemImage: "text.alignleft", isOn: $model.logging)
                        .toggleStyle(.checkbox)
                        .help("Log each executed instruction to file")
                }
            } label: {
                Label("Control", systemImage: "gamecontroller.fill")
            }
        }
    }
}

#Preview {
    let model = Turbo9ViewModel()
    ControlView()
        .environmentObject(model)
}
