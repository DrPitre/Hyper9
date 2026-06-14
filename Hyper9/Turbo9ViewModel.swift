//
//  Turbo9ViewModel.swift
//  Hyper9
//
//  Created by Boisy Pitre on 1/22/25.
//

import SwiftUI
import Turbo9Sim
import CocoaLumberjackSwift

class Turbo9ViewModel: ObservableObject {
    @Published var A: UInt8 = 0x00
    @Published var B: UInt8 = 0x00
    @Published var DP: UInt8 = 0x00
    @Published var X: UInt16 = 0x0000
    @Published var Y: UInt16 = 0x0000
    @Published var U: UInt16 = 0x0000
    @Published var S: UInt16 = 0x0000
    @Published var PC: UInt16 = 0x0000
    @Published var CC: UInt8 = 0x00
    @Published var ccString: String = ""
    /// Set by other views (e.g. Module Directory, Processes) to ask MemoryView
    /// to scroll to a specific address. MemoryView consumes and resets it.
    @Published var memoryGotoTarget: UInt16? = nil

    @Published var symbolStatus: String = ""

    // Previous values, captured at the start of each updateUI(), for highlighting
    // what changed since the last step. Highlights are gated by `!running`.
    @Published var previousA: UInt8 = 0x00
    @Published var previousB: UInt8 = 0x00
    @Published var previousDP: UInt8 = 0x00
    @Published var previousCC: UInt8 = 0x00
    @Published var previousX: UInt16 = 0x0000
    @Published var previousY: UInt16 = 0x0000
    @Published var previousU: UInt16 = 0x0000
    @Published var previousS: UInt16 = 0x0000
    @Published var previousPC: UInt16 = 0x0000
    @Published var operations: [Disassembler.Turbo9Operation] = []
    @Published var memorySnapshot: [UInt8] = []
    @Published var previousMemorySnapshot: [UInt8] = []
    @Published var logging : Bool = false
    public var turbo9 = Disassembler(program: [UInt8].init(repeating: 0x00, count: 65536))
    public var output : UInt8 = 0
    @Published public var outputString = ""
    private let maxOutputLength = 8000
    private var outputBuffer = ""
    private let outputLock = NSLock()
    private var inputQueue: [UInt8] = []
    private let inputLock = NSLock()
    private var lastInputDeliveryCycle: UInt = 0
    @Published var running = false
    public var timerRunning = false
    public var instructionsPerSecond = 0.0
    private let fileLogger: DDFileLogger = DDFileLogger() // File Logger
    private var logBuffer : String = ""

    private let breakpointsLock = NSLock()
    private var breakpointAddresses: Set<UInt16> = []

    func setBreakpoints(_ addresses: [UInt16]) {
        breakpointsLock.lock()
        breakpointAddresses = Set(addresses)
        breakpointsLock.unlock()
    }

    func isBreakpoint(_ address: UInt16) -> Bool {
        breakpointsLock.lock()
        let hit = breakpointAddresses.contains(address)
        breakpointsLock.unlock()
        return hit
    }

    func disassemble(instructionCount: UInt) {
        let _ = turbo9.disassemble(instructionCount: instructionCount)
        updateUI()
    }

    func ensureDisassembly(lineCount: Int) {
        let current = turbo9.operations.count
        guard current < lineCount else { return }
        let extraCount = UInt(lineCount - current)
        let savedPC = turbo9.PC
        if let last = turbo9.operations.last {
            turbo9.PC = last.offset &+ UInt16(last.size)
        }
        let _ = turbo9.disassemble(instructionCount: extraCount)
        turbo9.PC = savedPC
        operations = turbo9.operations
    }

    /// Append up to `lines` more disassembled instructions after the last cached
    /// op, trimming from the front if the total would exceed `cap`. Used by the
    /// disassembly view's sliding window when the user scrolls past the bottom.
    /// Returns true if any new instructions were added.
    @discardableResult
    func extendDisassemblyForward(lines: Int, cap: Int) -> Bool {
        guard lines > 0, let last = turbo9.operations.last else { return false }
        let firstNew = last.offset &+ UInt16(last.size)
        // Don't wrap past $FFFF — refuse to extend if we'd roll over.
        if firstNew < last.offset { return false }
        var pc = firstNew
        var added = 0
        while added < lines {
            guard let op = turbo9.disassemble(pc: pc) else { break }
            turbo9.operations.append(op)
            let next = pc &+ UInt16(op.size)
            if next <= pc { break }                 // wrap guard
            pc = next
            added += 1
        }
        if turbo9.operations.count > cap {
            turbo9.operations.removeFirst(turbo9.operations.count - cap)
        }
        if added > 0 { operations = turbo9.operations }
        return added > 0
    }

    /// Prepend up to `lines` instructions before the first cached op. 6809
    /// instructions are variable-length, so we scan forward from a point
    /// `4 × lines` bytes earlier and keep only the sequence that aligns
    /// exactly with the current top. Trims from the back if the total would
    /// exceed `cap`. Returns true if any instructions were prepended.
    @discardableResult
    func extendDisassemblyBackward(lines: Int, cap: Int) -> Bool {
        guard lines > 0, let first = turbo9.operations.first else { return false }
        let topAddr = first.offset
        let scanBytes = min(Int(topAddr), max(16, lines * 4))
        guard scanBytes > 0 else { return false }
        let start = topAddr &- UInt16(scanBytes)

        var collected: [Disassembler.Turbo9Operation] = []
        var pc = start
        while pc < topAddr {
            guard let op = turbo9.disassemble(pc: pc) else { break }
            let end = op.offset &+ UInt16(op.size)
            if end > topAddr { break }
            collected.append(op)
            if end == topAddr { break }
            pc = end
        }
        // Alignment check — the last op must end exactly at the current top.
        guard let lastOp = collected.last,
              lastOp.offset &+ UInt16(lastOp.size) == topAddr else {
            return false
        }
        let take = Array(collected.suffix(lines))
        guard !take.isEmpty else { return false }
        turbo9.operations.insert(contentsOf: take, at: 0)
        if turbo9.operations.count > cap {
            turbo9.operations.removeLast(turbo9.operations.count - cap)
        }
        operations = turbo9.operations
        return true
    }

    func step() {
        do {
            try turbo9.step()
        } catch {

        }
    }

    func load(url: URL) {
        do {
            try turbo9.load(url: url)
            outputLock.lock()
            outputBuffer = ""
            outputLock.unlock()
            outputString = ""
            updateUI()
        } catch {

        }
    }

    /// Load (or reload) a `.map` symbol file picked by the user. Refreshes the
    /// disassembly so labels and branch annotations appear immediately.
    func loadSymbols(from url: URL) {
        do {
            try turbo9.loadSymbols(from: url)
            symbolStatus = "Loaded \(turbo9.symbolCount) symbols from \(url.lastPathComponent)"
            turbo9.checkDisassembly()
            updateUI()
        } catch {
            symbolStatus = "Failed to load \(url.lastPathComponent)"
        }
    }

    /// Module-relative `.map` files (typical for OS-9 / TurbOS modules) need a
    /// base added to each symbol address so lookups match the runtime PC.
    /// Setting this triggers a disassembly refresh.
    func setSymbolBase(_ base: UInt16) {
        turbo9.symbolBase = base
        turbo9.checkDisassembly()
        updateUI()
    }

    /// Restore a full 64 KB memory snapshot (e.g. when opening a document).
    func loadMemorySnapshot(_ data: Data) {
        turbo9.loadMemorySnapshot(data)
        outputLock.lock(); outputBuffer = ""; outputLock.unlock()
        inputLock.lock(); inputQueue = []; inputLock.unlock()
        lastInputDeliveryCycle = 0
        outputString = ""
        instructionsPerSecond = 0.0
        turbo9.checkDisassembly()
        updateUI()
        updateMemoryView()
    }

    /// Snapshot the entire memory (for saving as a document).
    func memorySnapshotData() -> Data {
        turbo9.memorySnapshotData()
    }

    /// Restore a versioned document snapshot — both CPU registers and memory.
    /// Falls back to a raw memory image (with CPU reset) if the file is legacy / unrecognized.
    func loadDocumentSnapshot(_ data: Data) {
        turbo9.loadDocumentSnapshot(data)
        outputLock.lock(); outputBuffer = ""; outputLock.unlock()
        inputLock.lock(); inputQueue = []; inputLock.unlock()
        lastInputDeliveryCycle = 0
        outputString = ""
        instructionsPerSecond = 0.0
        turbo9.checkDisassembly()
        updateUI()
        updateMemoryView()
    }

    /// Snapshot the CPU registers + memory for saving as a document.
    func documentSnapshotData() -> Data {
        // Make sure any pending edits in the register text fields land in the CPU first.
        updateCPU()
        return turbo9.documentSnapshotData()
    }

    func reset() {
        do {
            try turbo9.reset()
            outputLock.lock(); outputBuffer = ""; outputLock.unlock()
            inputLock.lock(); inputQueue = []; inputLock.unlock()
            lastInputDeliveryCycle = 0
            outputString = ""
            instructionsPerSecond = 0.0
            // The CPU's PC has jumped to the reset vector. Invalidate any
            // cached disassembly so checkDisassembly() rebuilds from the new
            // PC, then publish both the fresh ops and memory to the views.
            turbo9.operations = []
            turbo9.checkDisassembly()
            updateUI()
            updateMemoryView()
        } catch {

        }
    }

    public func invokeTimer() {
        // Set the bit indicating the timer has fired
        let value = turbo9.bus.read(0xFF02)
        turbo9.bus.write(0xFF02, data: value | 0x01)

        // If the timer control register's "interrupt on timer fire" is set, assert the IRQ
        if (turbo9.bus.read(0xFF03) & 0x01) == 0x01 {
            turbo9.assertIRQ()
        }
    }

    init() {
        let outputHandler = BusWriteHandler(address: 0xFF00, callback: { [weak self] value in
            guard let self else { return }
            let char = String(format: "%c", value)
            self.outputLock.lock()
            self.outputBuffer += char
            self.outputLock.unlock()
        })

        let irqStatusHandler = BusWriteHandler(address: 0xFF02, callback: { [weak self] value in
            guard let self else { return }
            if (value & 0x01) == 0x01 { self.turbo9.deassertIRQ() }
            if (value & 0x02) == 0x02 { self.turbo9.deassertIRQ() }
        })

        let timerControlHandler = BusWriteHandler(address: 0xFF03, callback: { value in
            if (value & 0x01) == 0x01 {
                self.timerRunning = true
            } else {
                self.timerRunning = false
            }
        })

        reset()

        turbo9.bus.addWriteHandler(handler: outputHandler)
        turbo9.bus.addWriteHandler(handler: irqStatusHandler)
        turbo9.bus.addWriteHandler(handler: timerControlHandler)

        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 20
        DDLog.add(fileLogger)

        func log(_ message: String) {
            logBuffer += message + "\n"
            if (logBuffer.count > 10000) {
                DDLogInfo(logBuffer)
                logBuffer = ""
            }
        }

        turbo9.instructionClosure = log
    }

    func updateUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Snapshot current values as "previous" so the UI can highlight what changed.
            self.previousA = self.A
            self.previousB = self.B
            self.previousDP = self.DP
            self.previousCC = self.CC
            self.previousX = self.X
            self.previousY = self.Y
            self.previousU = self.U
            self.previousS = self.S
            self.previousPC = self.PC

            self.A = self.turbo9.A
            self.B = self.turbo9.B
            self.DP = self.turbo9.DP
            self.X = self.turbo9.X
            self.Y = self.turbo9.Y
            self.U = self.turbo9.U
            self.S = self.turbo9.S
            self.CC = self.turbo9.CC
            self.ccString = self.turbo9.ccString
            self.PC = self.turbo9.PC
            self.outputLock.lock()
            let newOutput = self.outputBuffer
            self.outputBuffer = ""
            self.outputLock.unlock()
            if !newOutput.isEmpty {
                self.outputString += newOutput
                if self.outputString.count > self.maxOutputLength {
                    self.outputString = String(self.outputString.suffix(self.maxOutputLength))
                }
            }
        }
    }

    func updateCPU() {
        turbo9.A = A
        turbo9.B = B
        turbo9.DP = DP
        turbo9.X = X
        turbo9.Y = Y
        turbo9.U = U
        turbo9.S = S
        turbo9.CC = CC
        turbo9.ccString = ccString
        turbo9.PC = PC
        turbo9.logging = logging
    }

    func sendInputLine(_ line: String) {
        for byte in line.utf8 { sendInputChar(byte) }
        sendInputChar(0x0D)
    }

    func sendInputChar(_ char: UInt8) {
        inputLock.lock()
        inputQueue.append(char)
        inputLock.unlock()
    }

    /// Empty the terminal output buffer and the on-screen string.
    func clearOutput() {
        outputLock.lock()
        outputBuffer = ""
        outputLock.unlock()
        outputString = ""
    }

    func deliverNextInputIfReady() {
        guard turbo9.clockCycles &- lastInputDeliveryCycle >= 500 else { return }
        inputLock.lock()
        guard !inputQueue.isEmpty else { inputLock.unlock(); return }
        let char = inputQueue.removeFirst()
        inputLock.unlock()
        lastInputDeliveryCycle = turbo9.clockCycles
        turbo9.bus.write(0xFF01, data: char)
        turbo9.bus.write(0xFF02, data: 0x02)
        if (turbo9.bus.read(0xFF03) & 0x02) == 0x02 {
            turbo9.assertIRQ()
        }
    }

    func updateMemoryView() {
        previousMemorySnapshot = memorySnapshot
        memorySnapshot = turbo9.memoryBytes
        operations = turbo9.operations
    }

    func startTask() {
        do {
            try turbo9.step()
            updateUI()
        } catch {

        }
    }
}
