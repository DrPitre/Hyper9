//
//  ProcessView.swift
//  Hyper9
//
//  Created by Boisy Pitre on 2/1/25.
//

import SwiftUI

// MARK: - Parsed process descriptor entry

struct ProcessEntry: Identifiable, Hashable {
    let id = UUID()
    let address: UInt16     // address of the process descriptor
    let pid: UInt8
    let parent: UInt8
    let state: UInt8
    let priority: UInt8
    let age: UInt8
    let user: UInt16
    let stack: UInt16
    let moduleAddress: UInt16
    let moduleName: String

    var stateText: String {
        // TurbOS P$State flags (from turbos.d):
        //   $80 SysState   $40 TimSleep  $20 TimOut
        //   $10 ImgChg     $02 Condem    $01 Dead
        var parts: [String] = []
        if state & 0x01 != 0 { parts.append("Dead") }
        if state & 0x02 != 0 { parts.append("Condem") }
        if state & 0x40 != 0 { parts.append("Sleep") }
        if state & 0x20 != 0 { parts.append("Timeout") }
        if state & 0x10 != 0 { parts.append("ImgChg") }
        if state & 0x80 != 0 { parts.append("System") }
        if parts.isEmpty { return "Active" }
        return parts.joined(separator: "·")
    }

    var stateColor: Color {
        if state & 0x01 != 0 || state & 0x02 != 0 { return .red }
        if state & 0x40 != 0 { return .gray }
        if state & 0x20 != 0 { return .orange }
        return .green
    }
}

// MARK: - View

struct ProcessView: View {
    @EnvironmentObject var model: Turbo9ViewModel
    @State private var processes: [ProcessEntry] = []
    @State private var sortOrder: [KeyPathComparator<ProcessEntry>] = [
        .init(\.pid, order: .forward)
    ]
    @State private var selection: ProcessEntry.ID?
    @State private var autoRefresh: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            Table(processes.sorted(using: sortOrder), selection: $selection, sortOrder: $sortOrder) {
                TableColumn("PID", value: \.pid) { entry in
                    HStack(spacing: 4) {
                        Circle().fill(entry.stateColor).frame(width: 8, height: 8)
                        Text(String(format: "%d", entry.pid))
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
                .width(min: 50, ideal: 60)
                TableColumn("Parent", value: \.parent) { entry in
                    Text(String(format: "%d", entry.parent))
                        .font(.system(size: 12, design: .monospaced))
                }
                .width(min: 50, ideal: 60)
                TableColumn("Module", value: \.moduleName) { entry in
                    Text(entry.moduleName)
                        .font(.system(size: 12, design: .monospaced))
                        .help(String(format: "Module @ $%04X", entry.moduleAddress))
                }
                .width(min: 90, ideal: 140)
                TableColumn("State", value: \.stateText) { entry in
                    Text(entry.stateText)
                        .font(.caption)
                        .foregroundColor(entry.stateColor)
                }
                .width(min: 80, ideal: 110)
                TableColumn("Prio", value: \.priority) { entry in
                    Text(String(format: "%d", entry.priority))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 40, ideal: 50)
                TableColumn("Age", value: \.age) { entry in
                    Text(String(format: "%d", entry.age))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 40, ideal: 50)
                TableColumn("User", value: \.user) { entry in
                    Text(String(format: "%d", entry.user))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 50, ideal: 60)
                TableColumn("Stack", value: \.stack) { entry in
                    Text(String(format: "$%04X", entry.stack))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .width(min: 60, ideal: 70)
                TableColumn("PD", value: \.address) { entry in
                    Text(String(format: "$%04X", entry.address))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .width(min: 60, ideal: 70)
            }
            .contextMenu(forSelectionType: ProcessEntry.ID.self) { ids in
                if let id = ids.first, let entry = processes.first(where: { $0.id == id }) {
                    Button("Jump to PD $\(String(format: "%04X", entry.address)) in Memory") {
                        model.memoryGotoTarget = entry.address
                    }
                    Button("Jump to Module $\(String(format: "%04X", entry.moduleAddress)) in Memory") {
                        model.memoryGotoTarget = entry.moduleAddress
                    }
                    Button("Jump to Stack $\(String(format: "%04X", entry.stack)) in Memory") {
                        model.memoryGotoTarget = entry.stack
                    }
                }
            } primaryAction: { ids in
                if let id = ids.first, let entry = processes.first(where: { $0.id == id }) {
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
            Text("\(processes.count) process\(processes.count == 1 ? "" : "es")")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            legend
            Toggle("Auto-refresh", isOn: $autoRefresh)
                .toggleStyle(.switch)
                .controlSize(.small)
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
            }
            .controlSize(.small)
            .help("Re-scan the process descriptor table")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendDot(.green,  "Active")
            legendDot(.orange, "Timeout")
            legendDot(.gray,   "Sleep")
            legendDot(.red,    "Dead")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func legendDot(_ c: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(label)
        }
    }

    // MARK: - Process-table parsing

    private func refresh() {
        var entries: [ProcessEntry] = []
        var seenPIDs = Set<UInt8>()

        // The kernel keeps the PD page table at D.PrcDBT. If it's zero the
        // process system hasn't been initialized yet, so there's nothing to show.
        let pageTable = model.turbo9.D_PrcDBT
        guard pageTable != 0 else {
            processes = []
            return
        }

        for slot in pageTable..<(pageTable &+ 0x40) {
            let pageUpper = model.turbo9.readByte(slot)
            guard pageUpper != 0 else { continue }

            var pageAddress = UInt16(pageUpper) &* 256
            if pageAddress == pageTable {
                pageAddress = pageAddress &+ 0x40
            }
            for slotOffset in stride(from: UInt16(0), to: UInt16(0x40 * 4), by: 0x40) {
                let pdAddress = pageAddress &+ slotOffset
                guard let entry = parseProcess(at: pdAddress) else { continue }
                if seenPIDs.insert(entry.pid).inserted {
                    entries.append(entry)
                }
            }
        }
        processes = entries
    }

    private func parseProcess(at address: UInt16) -> ProcessEntry? {
        let pid = model.turbo9.readByte(address)
        guard pid != 0 else { return nil }

        // TurbOS process descriptor layout (from turbos/source/include/turbos.d):
        //   $00 P$ID     1
        //   $01 P$PID    1
        //   $04 P$SP     2
        //   $09 P$User   2
        //   $0B P$Prior  1
        //   $0C P$Age    1
        //   $0D P$State  1
        //   $12 P$PModul 2
        let parent      = model.turbo9.readByte(address &+ 0x01)
        let stack       = model.turbo9.readWord(address &+ 0x04)
        let user        = model.turbo9.readWord(address &+ 0x09)
        let priority    = model.turbo9.readByte(address &+ 0x0B)
        let age         = model.turbo9.readByte(address &+ 0x0C)
        let state       = model.turbo9.readByte(address &+ 0x0D)
        let moduleAddr  = model.turbo9.readWord(address &+ 0x12)
        let name        = readModuleName(at: moduleAddr)

        return ProcessEntry(
            address: address,
            pid: pid,
            parent: parent,
            state: state,
            priority: priority,
            age: age,
            user: user,
            stack: stack,
            moduleAddress: moduleAddr,
            moduleName: name
        )
    }

    private func readModuleName(at address: UInt16) -> String {
        let sync = model.turbo9.readWord(address)
        guard sync == 0x87CD else { return "?" }
        let nameOffset = model.turbo9.readWord(address &+ 4)
        var nameAddr = address &+ nameOffset
        var name = ""
        for _ in 0..<32 {
            let ch = model.turbo9.readByte(nameAddr)
            let stripped = ch & 0x7F
            if stripped >= 0x20 && stripped < 0x7F {
                name.append(Character(UnicodeScalar(stripped)))
            }
            if ch & 0x80 != 0 { break }
            nameAddr = nameAddr &+ 1
        }
        return name.isEmpty ? "?" : name
    }
}

#Preview {
    let model = Turbo9ViewModel()
    return ProcessView()
        .environmentObject(model)
}
