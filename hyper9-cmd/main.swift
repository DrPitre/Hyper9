//
//  main.swift
//  hyper9-cmd
//
//  Created by Boisy Pitre on 3/9/25.
//

import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Turbo9Sim

// MARK: - Terminal Mode Functions

var rawModeEnabled = false

func enableRawMode() {
    guard isatty(STDIN_FILENO) == 1 else { return }
    let attrs = UnsafeMutablePointer<termios>.allocate(capacity: 1)
    tcgetattr(STDIN_FILENO, attrs)
    var raw = attrs.pointee
    raw.c_lflag &= ~(UInt(ECHO | ICANON)) // Turn off echo and canonical mode
    tcsetattr(STDIN_FILENO, TCSANOW, &raw)
    attrs.deallocate()
    rawModeEnabled = true
}

func disableRawMode() {
    guard rawModeEnabled else { return }
    let attrs = UnsafeMutablePointer<termios>.allocate(capacity: 1)
    tcgetattr(STDIN_FILENO, attrs)
    var cooked = attrs.pointee
    cooked.c_lflag |= (UInt(ECHO | ICANON))
    tcsetattr(STDIN_FILENO, TCSANOW, &cooked)
    attrs.deallocate()
    rawModeEnabled = false
}

struct Options {
    var imagePath: String?
    var seconds: TimeInterval?
    var cycles: UInt?
    var expectOutput: String?
    var input: [UInt8] = []
    var inputAfterOutput: String?
}

func usage(_ program: String) -> Never {
    print("Usage: \(program) [--seconds N] [--cycles N] [--input TEXT] [--input-after-output TEXT] [--expect-output TEXT] <image-file-path>")
    exit(EXIT_FAILURE)
}

func decodeEscapes(_ text: String) -> [UInt8] {
    var bytes: [UInt8] = []
    var iterator = text.utf8.makeIterator()

    while let byte = iterator.next() {
        if byte != 92 {
            bytes.append(byte)
            continue
        }

        guard let escaped = iterator.next() else {
            bytes.append(byte)
            break
        }

        switch escaped {
        case 92:
            bytes.append(92)
        case 110:
            bytes.append(10)
        case 114:
            bytes.append(13)
        case 116:
            bytes.append(9)
        default:
            bytes.append(escaped)
        }
    }

    return bytes
}

func parseOptions(_ arguments: [String]) -> Options {
    var options = Options()
    var index = 1

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--seconds":
            index += 1
            guard index < arguments.count, let seconds = TimeInterval(arguments[index]) else {
                usage(arguments[0])
            }
            options.seconds = seconds
        case "--cycles":
            index += 1
            guard index < arguments.count, let cycles = UInt(arguments[index]) else {
                usage(arguments[0])
            }
            options.cycles = cycles
        case "--expect-output":
            index += 1
            guard index < arguments.count else {
                usage(arguments[0])
            }
            options.expectOutput = arguments[index]
        case "--input":
            index += 1
            guard index < arguments.count else {
                usage(arguments[0])
            }
            options.input = decodeEscapes(arguments[index])
        case "--input-after-output":
            index += 1
            guard index < arguments.count else {
                usage(arguments[0])
            }
            options.inputAfterOutput = arguments[index]
        case "-h", "--help":
            usage(arguments[0])
        default:
            if argument.hasPrefix("-") {
                usage(arguments[0])
            }
            guard options.imagePath == nil else {
                usage(arguments[0])
            }
            options.imagePath = argument
        }
        index += 1
    }

    guard options.imagePath != nil else {
        usage(arguments[0])
    }
    return options
}

// MARK: - IRQ Handlers

public func invokeTimerIRQ() {
    // Set the bit indicating the timer has fired
    let value = turbo9.bus.read(0xFF02)
    turbo9.bus.write(0xFF02, data: value | 0x01)
    
    // If the timer control register's "interrupt on timer" is set, assert the IRQ
    if (turbo9.bus.read(0xFF03) & 0x01) == 0x01 {
        turbo9.assertIRQ()
    }
}

public func invokeInputIRQ() {
    // Set the bit indicating there's an input character
    turbo9.bus.write(0xFF02, data: 0x02)
    
    // If the interrupt control register's "interrupt on input" is set, assert the IRQ
    if (turbo9.bus.read(0xFF03) & 0x02) == 0x02 {
        turbo9.assertIRQ()
    }
}

// MARK: - Globals

var timerRunning = false
var inputIRQEnabled = false
let turbo9 = Disassembler()

func sendInputByte(_ byte: UInt8) {
    var byteToSend = byte
    if byteToSend == 10 {
        byteToSend = 13
    }
    turbo9.bus.write(0xFF01, data: byteToSend)
    invokeInputIRQ()
}

// MARK: - Main Execution

// 1. Parse Arguments
let options = parseOptions(CommandLine.arguments)
let filePath = options.imagePath!
let startTime = Date()
var capturedOutput = ""
var scriptedInputSent = false
var scriptedInputIndex = 0
var nextScriptedInputCycle: UInt = 0

// 2. Attempt to Load the Specified File
do {
    try turbo9.load(url: URL(fileURLWithPath: filePath))
} catch {
    print("Error loading file at path \(filePath): \(error)")
    exit(EXIT_FAILURE)
}

// 3. Prepare I/O Handlers
let outputHandler = BusWriteHandler(address: 0xFF00, callback: { value in
    let character = String(format: "%c", value)
    capturedOutput += character
    print(character, terminator: "")
    fflush(stdout)
})

let irqStatusHandler = BusWriteHandler(address: 0xFF02, callback: { value in
    // Writing 1 to bit 0 deasserts timer IRQ
    if (value & 0x01) == 0x01 {
        _ = turbo9.bus.read(0xFF02, readThroughIO: true) & 0xFE
        turbo9.deassertIRQ()
    }
    // Writing 1 to bit 1 deasserts input IRQ
    if (value & 0x02) == 0x02 {
        _ = turbo9.bus.read(0xFF02, readThroughIO: true) & 0xFD
        turbo9.deassertIRQ()
    }
})

let irqControlHandler = BusWriteHandler(address: 0xFF03, callback: { value in
    timerRunning = (value & 0x01) == 0x01
    inputIRQEnabled = (value & 0x02) == 0x02
})

// If you want to track specific writes for debugging, uncomment the following:
/*
let check0x503Handler = BusWriteHandler(address: 0x0503, callback: { value in
    print("0x503 written: \(value)")
})
*/

// 4. Set Up Terminal and Handlers
enableRawMode()
defer {
    disableRawMode()
}

let flags = fcntl(STDIN_FILENO, F_GETFL)
let _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)

turbo9.bus.addWriteHandler(handler: outputHandler)
turbo9.bus.addWriteHandler(handler: irqStatusHandler)
turbo9.bus.addWriteHandler(handler: irqControlHandler)
// turbo9.bus.addWriteHandler(handler: check0x503Handler)

// 5. Reset and Begin Execution
do {
    try turbo9.reset()
} catch {
    print("Error during reset: \(error)")
    exit(EXIT_FAILURE)
}

// Optional: If you'd like to log or trace instructions, uncomment and implement:
//func log(_ message: String) {
//    print(message)
//}
// turbo9.instructionClosure = log

// 6. Main Emulation Loop
repeat {
    try turbo9.step()

    if !scriptedInputSent && !options.input.isEmpty {
        if let marker = options.inputAfterOutput {
            if capturedOutput.contains(marker) {
                scriptedInputSent = true
                nextScriptedInputCycle = turbo9.clockCycles
            }
        } else {
            scriptedInputSent = true
            nextScriptedInputCycle = turbo9.clockCycles
        }
    }

    if scriptedInputSent && scriptedInputIndex < options.input.count && turbo9.clockCycles >= nextScriptedInputCycle {
        sendInputByte(options.input[scriptedInputIndex])
        scriptedInputIndex += 1
        nextScriptedInputCycle = turbo9.clockCycles + 300
    }

    if let expected = options.expectOutput, capturedOutput.contains(expected) {
        disableRawMode()
        exit(EXIT_SUCCESS)
    }

    if let maxCycles = options.cycles, turbo9.clockCycles >= maxCycles {
        if let expected = options.expectOutput {
            fputs("\nExpected output not seen: \(expected)\n", stderr)
            disableRawMode()
            exit(EXIT_FAILURE)
        }
        disableRawMode()
        exit(EXIT_SUCCESS)
    }

    if let seconds = options.seconds, Date().timeIntervalSince(startTime) >= seconds {
        if let expected = options.expectOutput {
            fputs("\nExpected output not seen: \(expected)\n", stderr)
            disableRawMode()
            exit(EXIT_FAILURE)
        }
        disableRawMode()
        exit(EXIT_SUCCESS)
    }
    
    if turbo9.clockCycles % 300 == 0 {
        invokeTimerIRQ()
    }
    
    var char: UInt8 = 0
    let readBytes = read(STDIN_FILENO, &char, 1)
    if readBytes == 1 {
        if char == 10 {  // Enter key (LF) -> convert to CR
            char = 13
        }
        
        turbo9.bus.write(0xFF01, data: char)
        invokeInputIRQ()
    }
} while true

disableRawMode()
