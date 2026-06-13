import Foundation

enum RegisterType {
    case eightBit
    case sixteenBit
}

enum Register {
    case A
    case B
    case D
    case X
    case Y
    case U
    case SP
    case DP
    case CC
    case PC

    var type: RegisterType {
        switch self {
        case .A, .B, .DP, .CC:
            return .eightBit
        case .D, .X, .Y, .U, .SP, .PC:
            return .sixteenBit
        }
    }
    
    static func registerMapping(_ reg : Int) -> Register {
        switch reg {
        case 0:
            return .D
        case 1:
            return .X
        case 2:
            return .Y
        case 3:
            return .U
        case 4:
            return .SP
        case 5:
            return .PC
        case 8:
            return .A
        case 9:
            return .B
        case 10:
            return .CC
        case 11:
            return .DP
        default:
            return .D
        }
    }
}

public class Turbo9CPU {
    let SWI3Vector: UInt16 = 0xFFF2
    let SWI2Vector: UInt16 = 0xFFF4
    let FIRQVector: UInt16 = 0xFFF6
    let IRQVector: UInt16 = 0xFFF8
    let SWIVector: UInt16 = 0xFFFA
    let NMIVector: UInt16 = 0xFFFC
    let RESETVector: UInt16 = 0xFFFE

    /// The 16-bit program counter PC.
    public var PC: UInt16 = 0x0000
    
    /// The 16-bit  system stack pointer S.
    public var S: UInt16 = 0x00FF
    
    /// The 8-bit accumulator `A`.
    public var A: UInt8 = 0x00
    
    /// The 8-bit accumulator `B`.
    public var B: UInt8 = 0x00
    
    /// The 16-bit accumulator D.
    ///
    /// D is the concatentation of accumulators A and B.
    public var D: UInt16 {
        get {
            return UInt16(A) << 8 | UInt16(B)
        }
        set {
            A = UInt8(newValue >> 8)
            B = UInt8(newValue & 0xFF)
        }
    }
    
    public var memoryDump: String {
        self.bus.ramDump(address: 0, numBytes: 0x10000)
    }

    public func memoryWindow(around address: UInt16, size: Int = 512) -> String {
        let start = max(0, (Int(address) - size / 2) & ~0xF)
        let numBytes = min(size, 0x10000 - start)
        return bus.ramDump(address: UInt32(start), numBytes: numBytes)
    }
    
    /// The 16-bit index register `X`.
    public var X: UInt16 = 0x00
    
    /// The 16-bit index register `Y`.
    public var Y: UInt16 = 0x00
    
    /// The 16-bit user stack pointer Y.
    public var U: UInt16 = 0x0000
    
    /// The 8-bit direct page register `DP`.
    public var DP: UInt8 = 0x00
    
    /// The 8-bit condition code register `CC`.
    public  var CC: UInt8 = 0x00
    
    /// The interrupt input line
    var IRQ: Bool = false
    
    /// The fast interrupt input line
    var FIRQ : Bool = false

    /// The non-maskable interrupt input line
    var NMI : Bool = false

    public var clockCycles: UInt = 0
    var totalInstructionCycles: Int = 0
    public var instructionsExecuted: UInt = 0
    public var interruptsReceived: UInt = 0
    let cyclesPerInterrupt: UInt = 1000
    public var syncToInterrupt = false
    
    /// The string respresentation of the register `CC`.
    public var ccString : String {
        get {
            var states = ""
            if readCC(.entire) == true { states += "E"}
            else { states += "-" }
            if readCC(.firq) == true { states += "F" }
            else { states += "-" }
            if readCC(.halfcarry) == true { states += "H" }
            else { states += "-" }
            if readCC(.irq) == true { states += "I" }
            else { states += "-" }
            if readCC(.negative) == true { states += "N" }
            else { states += "-" }
            if readCC(.zero) == true { states += "Z" }
            else { states += "-" }
            if readCC(.overflow) == true { states += "O" }
            else { states += "-" }
            if readCC(.carry) == true { states += "C" }
            else { states += "-" }
            
            return states
        }
        set {
        }
    }
    
    /// A pointer to the address where an instruction reads or writes a value, or branches to.
    var addressAbsolute: UInt16 = 0x0000
    
    /// A flag that tindicates whether to show instructions as they execute.
    var debug : Bool = true
    
    // MARK: - Private properties
    
    public let bus: Bus
    
    // MARK: - Init
    
    init(
        bus: Bus = Bus(memory: []),
        pc: UInt16 = 0x0000,
        stackPointer: UInt16 = 0xFF,
        A: UInt8 = 0x00,
        B: UInt8 = 0x00,
        X: UInt16 = 0x00,
        Y: UInt16 = 0x00,
        U: UInt16 = 0x00,
        DP: UInt8 = 0x00,
        flags: UInt8 = 0x00
    ) {
        self.bus = bus
        self.bus.cpu = self
        self.PC = pc
        self.S = stackPointer
        self.A = A
        self.B = B
        self.X = X
        self.Y = Y
        self.U = U
        self.DP = DP
        self.CC = flags
        
        // Initialize Turbo9 SWI3 vector
        writeWord(SWI3Vector, data: 0x0100)
        
        // Initialize Turbo9 SWI2 vector
        writeWord(SWI2Vector, data: 0x0103)
        
        // Initialize Turbo9 FIRQ vector
        writeWord(FIRQVector, data: 0x010f)
        
        // Initialize Turbo9 IRQ vector
        writeWord(IRQVector, data: 0x010c)
        
        // Initialize Turbo9 SWI vector
        writeWord(SWIVector, data: 0x0106)
        
        // Initialize Turbo9 NMI vector
        writeWord(NMIVector, data: 0x0109)
        
        // Initialize Turbo9 RESET vector
        writeWord(RESETVector, data: 0x0000)
    }
    
    /// Reset the CPU.
    public func reset() throws {
        // Fetch the address at the reset vector
        let addr = readWord(RESETVector)
        A = 0
        B = 0
        X = 0
        Y = 0
        U = 0
        S = 0x500
        DP = 0
        CC = 0
        PC = addr
        instructionsExecuted = 0
        interruptsReceived = 0
        syncToInterrupt = false
        clockCycles = 0
        
        // Reset the bus.
        bus.reset()
    }

    /// Assert the interrupt
    public func assertIRQ() {
        IRQ = true
    }

    /// Assert the fast interrupt
    public func assertFIRQ() {
        FIRQ = true
    }

    /// Assert the non-maskable interrupt
    public func assertNMI() {
        NMI = true
    }

    /// Deassert the interrupt.
    public func deassertIRQ() {
        IRQ = false
    }

    /// Deassert the fast Interrupt.
    public func deassertFIRQ() {
        FIRQ = false
    }

    /// Deassert the non-maskable Interrupt.
    public func deassertNMI() {
        NMI = false
    }

    func step() throws {
        // Increment instructions executed.
        instructionsExecuted = instructionsExecuted + 1

        // Increment clock cycles.
        clockCycles = clockCycles + 1
        
        bus.refresh()
        
        // Check if non-maskable interrupt preempts our execution
        if NMI == true {
            // NMI is TRUE
            PC = readWord(NMIVector)
        } else
        // Check if interrupt preempts our execution
        if readCC(.irq) == false && IRQ == true {
            // IRQ is TRUE, IRQs are unmasked, and we aren't currently in an IRQ state
            if syncToInterrupt == false {
                pushToS(word: PC)
                pushToS(word: U)
                pushToS(word: Y)
                pushToS(word: X)
                pushToS(byte: DP)
                pushToS(byte: B)
                pushToS(byte: A)
                setCC(.entire, true)
                pushToS(byte: CC)
            }
            // Mask the IRQ and FIRQ after pushing the CC onto the stack
            setCC(.irq, true)
            setCC(.firq, true)
            syncToInterrupt = false
            interruptsReceived = interruptsReceived + 1
            deassertIRQ()
            PC = readWord(IRQVector)
            return
        } else
        // Check if fast interrupt preempts our execution
        if readCC(.firq) == false && FIRQ == true {
            // FIRQ is TRUE, FIRQs are unmasked, and we aren't currently in an FIRQ state
            if syncToInterrupt == false {
                pushToS(word: PC)
                setCC(.entire, false)
                pushToS(byte: CC)
            }
            // Mask the IRQ and FIRQ after pushing the CC onto the stack
            setCC(.irq, true)
            setCC(.firq, true)
            syncToInterrupt = false
            interruptsReceived = interruptsReceived + 1
            deassertFIRQ()
            PC = readWord(FIRQVector)
        }
        
        // If SYNC or CWAI has executed, this flag will be set, so we just return
        if syncToInterrupt == true {
            return
        }
        
        var opcode : OpCode
        let opcodeByte = readByte(PC)
        PC = PC &+ 1
        
        if opcodeByte == 0x10 {
            let opcodeByte = readByte(PC)
            opcode = Self.opcodes10[Int(opcodeByte)]
            PC = PC &+ 1
        } else if opcodeByte == 0x11 {
            let opcodeByte = readByte(PC)
            opcode = Self.opcodes11[Int(opcodeByte)]
            PC = PC &+ 1
        } else {
            opcode = Self.opcodes[Int(opcodeByte)]
        }
        
        setupAddressing(using: opcode.1)
        try perform(instruction: opcode.0, addressMode: opcode.1)
    }
    
    /// Start a program.
    func run(count : UInt = UInt.max) throws {
        var counter = count
        if count == UInt.max {
            while true {
                try step()
            }
        } else {
            while (counter > 0) {
                try step()
                counter = counter - 1
            }
        }
    }
    
    // MARK: - Communicate with bus
    
    /// Read a single byte from memory.
    /// - Parameter address: The memory address.
    /// - Returns: A byte from memory.
    public func readByte(_ address: UInt16) -> UInt8 {
        bus.read(address)
    }
    
    /// Create a word from bytes read from `address` and `address + 1`.
    /// - Parameter address: The address in memory where the word to read starts.
    /// - Returns: A word.
    public func readWord(_ address: UInt16) -> UInt16 {
        let highByte = readByte(address)
        let lowByte = readByte(address &+ 1)
        
        return .createWord(highByte: highByte, lowByte: lowByte)
    }
    
    /// Write a single byte to memory.
    /// - Parameters:
    ///   - address: The address where to store the data.
    ///   - data: A byte.
    public func writeByte(_ address: UInt16, data: UInt8) {
        bus.write(address, data: data)
    }
    
    /// Write a word to memory.
    /// - Parameters:
    ///   - address: The address where to store the data.
    ///   - data: A word.
    public func writeWord(_ address: UInt16, data: UInt16) {
        bus.write(address, data: data.highByte)
        bus.write(address &+ 1, data: data.lowByte)
    }
    
    // MARK: - Flags
    
    /// Set a condition code on or off.
    /// - Parameters:
    ///   - flag: The flag to set.
    ///   - isOn: Whether the flag is on or not.
    func setCC(_ flag: CCFlag, _ isOn: Bool) {
        if isOn {
            // OR the current flags against the given flag.
            CC |= flag.rawValue
            ccString = "0"
        } else {
            // AND the current flags against the flipped bits on the given flag.
            CC &= ~flag.rawValue
            ccString = "0"
        }
    }
    
    /// Read the state of a condition code.
    /// - Parameter flag: The flag to read.
    /// - Returns: A `Bool` to indicate whether the flag is enabled or not.
    func readCC(_ flag: CCFlag) -> Bool {
        (CC & flag.rawValue) > 0
    }
    
    /// Load a program into memory.
    func loadMemory(fromFilePath filePath: String, loadAddress : UInt16 = 0) throws {
        let fileURL = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: fileURL)
        if data.count > UInt16.max - loadAddress {
            throw CPUError.invalidMemorySize
        }
        var address : UInt16 = loadAddress
        for byte in data {
            bus.write(address, data: byte)
            address = address + 1
        }
    }
    
    // MARK: - Debugging
}
