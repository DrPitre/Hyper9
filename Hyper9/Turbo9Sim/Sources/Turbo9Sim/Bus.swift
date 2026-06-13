import Foundation

/// The mechanism that calls back when an area of memory is read from.
///
/// Create a read handler when you want to respond to a read of an address in the memory mapped I/O area.
public struct BusReadHandler {
    var address : UInt16
    var callback: () -> UInt8
    
    /// Create a read handler.
    ///
    /// Parameters:
    /// - address: The 16 bit address within the range of $FF00-$FFEF to respond to the read.
    /// - callback: The closure ot call when a read occurs at the address. The closure returns an 8-bit value.
    public init(address: UInt16, callback: @escaping () -> UInt8) {
        self.address = address
        self.callback = callback
    }
}

/// The mechanism that calls back when an area of memory is written to.
///
/// Create a read handler when you want to respond to a write to an address in the memory mapped I/O area.
public struct BusWriteHandler {
    var address : UInt16
    var callback: (_ value: UInt8) -> Void
    
    /// Create a write handler.
    ///
    /// Parameters:
    /// - address: The 16 bit address within the range of $FF00-$FFEF to respond to the write.
    /// - callback: The closure ot call when a write occurs at the address. The closure receives the 8-bit value that was written.
    public init(address: UInt16, callback: @escaping (_: UInt8) -> Void) {
        self.address = address
        self.callback = callback
    }
}

/// The system bus that defines the interface to the CPU.
///
/// Memory mapped I/O begins at $FF00 and ends at $FFEF. To respond to reads from this area, register a `BusReadhandler`
/// Likewise, to respond to writes to this area, register a `BusWriteHandler`.
public class Bus {
    var busReadHandlers : [BusReadHandler] = []
    var busWriteHandlers : [BusWriteHandler] = []
    weak var cpu: Turbo9CPU?
//    var clockInterrupt : Timer? = nil
    var memory: [UInt8]
    var originalRam: [UInt8]
    var timerTriggersIRQ: Bool = false

    init(memory: [UInt8] = []) {
        if memory == [] {
            self.memory = Array(repeating: UInt8(0x12), count: 0xFFF0)
            self.memory.append(contentsOf: Array(repeating:UInt8(0x00), count: 0x10))
        } else {
            self.memory = memory
        }
        self.originalRam = self.memory
    }
    
    /// Add a read handler.
    ///
    /// Parameters:
    /// - handler: An object that contains the read address and callback.
    public func addReadHandler(handler : BusReadHandler) {
        self.busReadHandlers.append(handler)
    }
    
    /// Add a write handler.
    ///
    /// Create a write handler to receive a notification when there is a write to a particular address.
    ///
    /// Parameters:
    /// - handler: An object that contains the write address and callback.
    public func addWriteHandler(handler : BusWriteHandler) {
        self.busWriteHandlers.append(handler)
    }
    
/*
 */
    
    /// Refresh the bus.
    public func refresh() {
    }

    /// Reset the bus.
    public func reset() {
        self.memory = self.originalRam
    }

    /// Read a byte from memory.
    public func read(_ address: UInt16, readThroughIO: Bool = false) -> UInt8 {
        guard memory.indices.contains(Int(address)) else { return 0 }
        if address >= 0xFF00 && address < 0xFFF0 && readThroughIO == false {
            // Call the mapped I/O read handler.
           return  mappedIOReadHandler(address)
        } else {
            // It's memory -- read the data.
            return memory[Int(address)]
        }
    }
    
    /// Write a byte to memory.
    public func write(_ address: UInt16, data: UInt8, writeThroughIO: Bool = false) {
        guard memory.indices.contains(Int(address)) else { return }
        if address >= 0xFF00 && address < 0xFFF0 && writeThroughIO == false {
            // Call the mapped I/O write handler.
            mappedIOWriteHandler(address, data: data)
        } else {
            // It's memory -- write the data.
            memory[Int(address)] = data
        }
    }
    
    func mappedIOWriteHandler(_ address: UInt16, data: UInt8) {
        memory[Int(address)] = data
        for handler in busWriteHandlers {
            if address == handler.address {
                handler.callback(data)
                return
            }
        }
    }

    func mappedIOReadHandler(_ address: UInt16) -> UInt8 {
        for handler in busReadHandlers {
            if address == handler.address {
                return handler.callback()
            }
        }
        
        return memory[Int(address)]
    }
}
