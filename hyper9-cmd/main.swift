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

func enableRawMode() {
    let attrs = UnsafeMutablePointer<termios>.allocate(capacity: 1)
    tcgetattr(STDIN_FILENO, attrs)
    var raw = attrs.pointee
    raw.c_lflag &= ~(UInt(ECHO | ICANON)) // Turn off echo and canonical mode
    tcsetattr(STDIN_FILENO, TCSANOW, &raw)
    attrs.deallocate()
}

func disableRawMode() {
    let attrs = UnsafeMutablePointer<termios>.allocate(capacity: 1)
    tcgetattr(STDIN_FILENO, attrs)
    var cooked = attrs.pointee
    cooked.c_lflag |= (UInt(ECHO | ICANON))
    tcsetattr(STDIN_FILENO, TCSANOW, &cooked)
    attrs.deallocate()
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
    let value = turbo9.bus.read(0xFF02)
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

// MARK: - Main Execution

// 1. Parse Arguments
let arguments = CommandLine.arguments
if arguments.count < 2 {
    print("Usage: \(arguments[0]) <image-file-path>")
    exit(EXIT_FAILURE)
}

let filePath = arguments[1]

// 2. Attempt to Load the Specified File
do {
    try turbo9.load(url: URL(fileURLWithPath: filePath))
} catch {
    print("Error loading file at path \(filePath): \(error)")
    exit(EXIT_FAILURE)
}

// 3. Prepare I/O Handlers
let outputHandler = BusWriteHandler(address: 0xFF00, callback: { value in
    print(String(format: "%c", value), terminator: "")
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
