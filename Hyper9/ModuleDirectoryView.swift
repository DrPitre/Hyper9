//
//  ModuleDirectoryView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 2/1/25.
//

import SwiftUI

// MARK: - Parsed module entry

struct ModuleEntry: Identifiable, Hashable {
    let id = UUID()
    let slot: UInt16        // address of the directory pointer (0x0300 + 4*i)
    let address: UInt16     // address of the module header
    let name: String
    let typeRaw: UInt8
    let size: UInt16
    let revision: UInt8

    var type: String {
        // TurbOS module type codes (from turbos.d):
        //   $10 Prgrm  $20 Sbrtn  $40 Data
        //   $C0 Systm  $D0 FlMgr  $E0 Drivr  $F0 Devic
        switch typeRaw & 0xF0 {
        case 0x10: return "Program"
        case 0x20: return "Subroutine"
        case 0x40: return "Data"
        case 0xC0: return "System"
        case 0xD0: return "File Mgr"
        case 0xE0: return "Driver"
        case 0xF0: return "Device Desc"
        default:   return String(format: "$%02X", typeRaw & 0xF0)
        }
    }

    var revisionText: String { String(format: "%d", revision & 0x0F) }
}

// MARK: - View

struct ModuleDirectoryView: View {
    @EnvironmentObject var model: Turbo9ViewModel
    @State private var modules: [ModuleEntry] = []
    @State private var sortOrder: [KeyPathComparator<ModuleEntry>] = [
        .init(\.address, order: .forward)
    ]
    @State private var selection: ModuleEntry.ID?
    @State private var autoRefresh: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            Table(modules.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Slot", value: \.slot) { Self.hex16Cell($0.slot) }
                    .width(min: 60, ideal: 70)
                TableColumn("Address", value: \.address) { Self.hex16Cell($0.address) }
                    .width(min: 70, ideal: 80)
                TableColumn("Name", value: \.name) { entry in
                    Text(entry.name)
                        .font(.system(size: 12, design: .monospaced))
                }
                .width(min: 90, ideal: 140)
                TableColumn("Type", value: \.type) { Text($0.type).font(.caption) }
                    .width(min: 70, ideal: 90)
                TableColumn("Size", value: \.size) { entry in
                    Text("\(entry.size)")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 50, ideal: 60)
                TableColumn("Rev", value: \.revision) { entry in
                    Text(entry.revisionText).font(.caption)
                }
                .width(min: 40, ideal: 50)
            }
            .contextMenu(forSelectionType: ModuleEntry.ID.self) { ids in
                if let id = ids.first, let entry = modules.first(where: { $0.id == id }) {
                    Button("Jump to \(String(format: "$%04X", entry.address)) in Memory") {
                        model.memoryGotoTarget = entry.address
                    }
                }
            } primaryAction: { ids in
                if let id = ids.first, let entry = modules.first(where: { $0.id == id }) {
                    model.memoryGotoTarget = entry.address
                }
            }
        }
        .onAppear { refresh() }
        .onChange(of: model.memorySnapshot) { _ in
            if autoRefresh { refresh() }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("\(modules.count) module\(modules.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Toggle("Auto-refresh", isOn: $autoRefresh)
                .toggleStyle(.switch)
                .controlSize(.small)
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
            }
            .controlSize(.small)
            .help("Re-scan the module directory")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Module-directory parsing

    private func refresh() {
        var entries: [ModuleEntry] = []
        for slot in stride(from: UInt16(0x0300), to: UInt16(0x0400), by: 4) {
            let modulePointer = model.turbo9.readWord(slot)
            guard modulePointer != 0 else { continue }
            guard let entry = parseModule(slot: slot, address: modulePointer) else { continue }
            entries.append(entry)
        }
        modules = entries
    }

    private func parseModule(slot: UInt16, address: UInt16) -> ModuleEntry? {
        let sync = model.turbo9.readWord(address)
        guard sync == 0x87CD else { return nil }
        let size       = model.turbo9.readWord(address &+ 2)
        let nameOffset = model.turbo9.readWord(address &+ 4)
        let typeByte   = model.turbo9.readByte(address &+ 6)
        let revisionB  = model.turbo9.readByte(address &+ 7)

        var nameAddr = address &+ nameOffset
        var name = ""
        var iterations = 0
        while iterations < 32 {
            let ch = model.turbo9.readByte(nameAddr)
            let stripped = ch & 0x7F
            if stripped >= 0x20 && stripped < 0x7F {
                name.append(Character(UnicodeScalar(stripped)))
            }
            if ch & 0x80 != 0 { break }
            nameAddr = nameAddr &+ 1
            iterations += 1
        }

        return ModuleEntry(
            slot: slot,
            address: address,
            name: name.isEmpty ? "?" : name,
            typeRaw: typeByte,
            size: size,
            revision: revisionB
        )
    }

    // MARK: - Cell helpers

    private static func hex16Cell(_ v: UInt16) -> some View {
        Text(String(format: "$%04X", v))
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.secondary)
    }
}

#Preview {
    let model = Turbo9ViewModel()
    return ModuleDirectoryView()
        .environmentObject(model)
}
