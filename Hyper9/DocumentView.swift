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
    @State private var breakpoints : [String] = []

    var body: some View {
        HStack {
            VStack {
                MemoryView()
                TabView {
                    BreakpointView(breakpoints: $breakpoints)
                        .tabItem {
                            Label("Breakpoints", systemImage: "1.circle")
                        }
                        .padding()
                    TerminalView()
                        .tabItem {
                            Label("Terminal", systemImage: "1.circle")
                        }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            TurbOSGlobalsView()
                        }
                    }
                    .tabItem {
                        Label("System Globals", systemImage: "2.circle")
                    }
                    
                    ModuleDirectoryView()
                        .tabItem {
                            Label("Module Directory", systemImage: "1.circle")
                        }
                    ProcessView()
                        .tabItem {
                            Label("Processes", systemImage: "1.circle")
                        }
                }
                .padding()
            }
            .frame(width:640, height: 640)

            VStack {
                RegisterView()
                ZStack {
                    if model.running == true {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5) // Optional: makes the spinner larger
                            .padding()
                    }
                    DisassemblyView()
                }
                ControlView(breakpoints: $breakpoints)
                StatisticsView()
            }
            .padding()
            .task {
                let _ = model.disassemble(instructionCount: 2)
                model.updateUI()
                model.updateMemoryView()
            }
        }
        .onAppear() {
        }
        .onReceive(model.$PC) { _ in
        }
    }
}


#Preview {
    let model = Turbo9ViewModel()
    DocumentView(document: .constant(SimDocument()))
        .environmentObject(model)
}
