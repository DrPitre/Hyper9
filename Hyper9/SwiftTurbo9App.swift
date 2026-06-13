//
//  Hyper9App.swift
//  Hyper9
//
//  Created by Boisy Pitre on 1/22/25.
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct Hyper9App: App {
    var body: some Scene {
        DocumentGroup(newDocument: SimDocument()) { file in
            // Pass the document binding to your view.
            DocumentView(document: file.$document)
                .environmentObject(file.document.disassembler)
        }
        .defaultSize(width: 1400, height: 900)
    }
    
    func openAuxiliaryWindow(disassembler: Turbo9ViewModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TurbOS Globals"
        window.contentView = NSHostingView(
            rootView: TurbOSGlobalsView()
                .environmentObject(disassembler) // Inject the environment object
        )
        window.makeKeyAndOrderFront(nil)
    }
}


