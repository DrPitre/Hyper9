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
    @Binding var breakpoints: [String]

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
                DispatchQueue.global(qos: .userInitiated).async {
                    let startTime = Date()
                    var instructionCount = 0
                    var breakpoint = false
                    var pendingUIUpdate = false
                    let parsedBreakpoints = breakpoints.compactMap { $0.asUInt16FromHex }
                    repeat {
                        if breakpoint == false {
                            model.step()
                            instructionCount += 1
                            model.deliverNextInputIfReady()
                            if model.timerRunning == true && model.turbo9.clockCycles % cyclesPerTick == 0 {
                                model.invokeTimer()
                            }
                            if instructionCount % 50_000 == 0 && !pendingUIUpdate {
                                pendingUIUpdate = true
                                DispatchQueue.main.async {
                                    model.updateUI()
                                    pendingUIUpdate = false
                                }
                            }
                        }
                        for b in parsedBreakpoints {
                            if b == model.turbo9.PC {
                                breakpoint = true
                                break
                            }
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
                    
                    Button(action: {
                        model.running = false
                        model.turbo9.assertFIRQ()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "f.circle")
                    }
                    
                    Button(action: {
                        model.running = false
                        model.turbo9.assertNMI()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "n.circle")
                    }
                    
                    Button(action: {
                        model.running = false
                        model.invokeTimer()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "timer")
                    }
                }
            } label: {
                Label("Interrupts", systemImage: "stop.fill")
            }

            GroupBox {
                HStack {
                    Button(action: runClosure
                    ) {
                        Image(systemName: goLabel)
                    }

                    Button(action: {
                        if let operation = model.turbo9.disassemble() {
                            if operation.isBranchSubroutineType() == true
                            {
//                                gotoAddress = model.turbo9.PC &+ UInt16(operation.size)
                                runClosure()
                            } else {
                                stepClosure()
                            }
                        }
                    }) {
                        Image(systemName: "arrow.right")
                    }
                    .disabled(model.running == true)
                    
                    Button(action: {
                        stepClosure()
                    }) {
                        Image(systemName: "arrow.down")
                    }
                    .disabled(model.running == true)
                    
/*                    Button(action: {
                    }) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(model.running == true)

                    DecTextField(number: $stepCount)
 */
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
                    .disabled(model.running == true)
                    
                    Button(action: {
                        model.reset()
                        model.turbo9.checkDisassembly()
                        model.updateUI()
                    }) {
                        Image(systemName: "button.horizontal.top.press")
                    }
                    .disabled(model.running == true)
                    Toggle("log", systemImage: "text.alignleft", isOn: $model.logging)
                        .toggleStyle(.checkbox)
                }
            } label: {
                Label("Control", systemImage: "gamecontroller.fill")
            }

            /*
             .onChange(of: model.PC) { newValue in
             print("Text changed to: \(newValue)")
             model.turbo9.PC = newValue
             // Perform any additional actions when the text changes.
             }
             */
        }
    }
}

#Preview {
    @Previewable @State var b : [String] = []
    let model = Turbo9ViewModel()
    ControlView(breakpoints: $b)
        .environmentObject(model)
}
