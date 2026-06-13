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
    private var outputBuffer = ""
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
            outputBuffer = ""
            updateUI()
        } catch {

        }
    }

    func reset() {
        do {
            try turbo9.reset()
            outputBuffer = ""
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
        let outputHandler = BusWriteHandler(address: 0xFF00, callback: { value in
            self.outputBuffer += String(format: "%c", value)
        })

        let timerStatusHandler = BusWriteHandler(address: 0xFF02, callback: { value in
            // Writing 1 to bit 0 deasserts IRQ
            if (value & 0x01) == 0x01 {
                let _ = self.turbo9.bus.read(0xFF02, readThroughIO: true) & 0xFE
                self.turbo9.deassertIRQ()
            }
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
        turbo9.bus.addWriteHandler(handler: timerStatusHandler)
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
                    self.memoryDump = self.turbo9.memoryDump
                    self.operations = self.turbo9.operations
                    self.outputString = self.outputBuffer
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

    func startTask() {
        do {
            try turbo9.step()
            updateUI()
        } catch {

        }
    }
}
