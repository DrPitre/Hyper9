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
    @Published var ccString: String = ""
    @Published var operations: [Disassembler.Turbo9Operation] = []
    @Published var memoryDump: String = ""
    @Published var logging : Bool = false
    public var turbo9 = Disassembler(program: [UInt8].init(repeating: 0x00, count: 65536))
    public var updateUI: (() -> Void) = {}
    public var updateCPU: (() -> Void) = {}
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

    func disassemble(instructionCount: UInt) {
        let _ = turbo9.disassemble(instructionCount: instructionCount)
        updateUI()
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

    func reset() {
        do {
            try turbo9.reset()
            outputLock.lock(); outputBuffer = ""; outputLock.unlock()
            inputLock.lock(); inputQueue = []; inputLock.unlock()
            outputString = ""
            instructionsPerSecond = 0.0
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

        // Set the model's update callback to update the published property.
        updateUI = { [weak self] in
            // Make sure to update on the main thread.
           DispatchQueue.main.async {
                if let self = self {
                    self.A = self.turbo9.A
                    self.B = self.turbo9.B
                    self.DP = self.turbo9.DP
                    self.X = self.turbo9.X
                    self.Y = self.turbo9.Y
                    self.U = self.turbo9.U
                    self.S = self.turbo9.S
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
        }

        updateCPU = { [weak self] in
            // Make sure to update on the main thread.
                if let self = self {
                    self.turbo9.A = self.A
                    self.turbo9.B = self.B
                    self.turbo9.DP = self.DP
                    self.turbo9.X = self.X
                    self.turbo9.Y = self.Y
                    self.turbo9.U = self.U
                    self.turbo9.S = self.S
                    self.turbo9.ccString = self.ccString
                    self.turbo9.PC = self.PC
                    self.turbo9.logging = self.logging
            }
        }

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

    func sendInputLine(_ line: String) {
        for byte in line.utf8 { sendInputChar(byte) }
        sendInputChar(0x0D)
    }

    func sendInputChar(_ char: UInt8) {
        inputLock.lock()
        inputQueue.append(char)
        inputLock.unlock()
    }

    func deliverNextInputIfReady() {
        guard turbo9.clockCycles - lastInputDeliveryCycle >= 500 else { return }
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
        let pc = turbo9.PC
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let dump = self.turbo9.memoryWindow(around: pc)
            let ops = self.turbo9.operations
            DispatchQueue.main.async {
                self.memoryDump = dump
                self.operations = ops
            }
        }
    }

    func startTask() {
        do {
            try turbo9.step()
            updateUI()
        } catch {

        }
    }
}
