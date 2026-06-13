import Foundation

private class Symbol {
    let label : String
    let file : String
    let address : UInt16

    init(label: String, file: String, address: UInt16) {
        self.label = label
        self.file = file
        self.address = address
    }

    init(line: String) {
        let tokens = line.components(separatedBy: " ")
        var theLabel = tokens[1]
        if theLabel.hasPrefix(".static.function.") {
            theLabel = String(theLabel.dropFirst(".static.function.".count))
        }
        if theLabel.hasPrefix(".local.static.") {
            theLabel = String(theLabel.dropFirst(".local.static.".count))
        }
        if theLabel.hasPrefix(".global.static.variable.") {
            theLabel = String(theLabel.dropFirst(".global.static.variable.".count))
        }
        self.label = theLabel
        self.file = tokens[2]
        self.address = UInt16(tokens[4], radix: 16)!
    }
}

@dynamicMemberLookup
public class Disassembler {

    private typealias OpCode = Turbo9CPU.OpCode

    // MARK: - Composed CPU

    public var cpu: Turbo9CPU

    // MARK: - Dynamic forwarding to cpu for any Turbo9CPU member

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<Turbo9CPU, T>) -> T {
        get { cpu[keyPath: keyPath] }
        set { cpu[keyPath: keyPath] = newValue }
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<Turbo9CPU, T>) -> T {
        cpu[keyPath: keyPath]
    }

    // MARK: - Disassembler-specific properties

    private var program: [UInt8] = []
    public var operations = [Turbo9Operation]()
    private var filePath: String = ""
    public var logging: Bool = true
    public var instructionClosure: ((String) -> Void)?
    var symbolTable: SymbolTable = SymbolTable()

    // MARK: - CPU property forwarding

    public var A: UInt8       { get { cpu.A }       set { cpu.A = newValue } }
    public var B: UInt8       { get { cpu.B }       set { cpu.B = newValue } }
    public var D: UInt16      { get { cpu.D }       set { cpu.D = newValue } }
    public var X: UInt16      { get { cpu.X }       set { cpu.X = newValue } }
    public var Y: UInt16      { get { cpu.Y }       set { cpu.Y = newValue } }
    public var U: UInt16      { get { cpu.U }       set { cpu.U = newValue } }
    public var S: UInt16      { get { cpu.S }       set { cpu.S = newValue } }
    public var PC: UInt16     { get { cpu.PC }      set { cpu.PC = newValue } }
    public var DP: UInt8      { get { cpu.DP }      set { cpu.DP = newValue } }
    public var CC: UInt8      { get { cpu.CC }      set { cpu.CC = newValue } }
    public var ccString: String { get { cpu.ccString } set { cpu.ccString = newValue } }
    public var bus: Bus       { cpu.bus }
    public var clockCycles: UInt          { get { cpu.clockCycles }          set { cpu.clockCycles = newValue } }
    public var instructionsExecuted: UInt { get { cpu.instructionsExecuted } set { cpu.instructionsExecuted = newValue } }
    public var interruptsReceived: UInt   { get { cpu.interruptsReceived }   set { cpu.interruptsReceived = newValue } }
    public var syncToInterrupt: Bool { get { cpu.syncToInterrupt } set { cpu.syncToInterrupt = newValue } }
    public var memoryBytes: [UInt8]  { cpu.memoryBytes }
    public var memoryDump: String    { cpu.memoryDump }

    // MARK: - CPU method forwarding

    public func reset() throws           { try cpu.reset() }
    public func assertIRQ()              { cpu.assertIRQ() }
    public func assertFIRQ()             { cpu.assertFIRQ() }
    public func assertNMI()              { cpu.assertNMI() }
    public func deassertIRQ()            { cpu.deassertIRQ() }
    public func readByte(_ address: UInt16) -> UInt8  { cpu.readByte(address) }
    public func readWord(_ address: UInt16) -> UInt16 { cpu.readWord(address) }

    public func memoryWindow(around address: UInt16, size: Int = 512) -> String {
        cpu.memoryWindow(around: address, size: size)
    }

    // MARK: - Init

    public init(program: [UInt8] = [], pc: UInt16 = 0x00) {
        self.program = program
        self.cpu = Turbo9CPU(
            bus: Bus(memory: .createRam(withProgram: program)),
            pc: pc
        )
    }

    struct SymbolTable {
        fileprivate var symbols: [Symbol] = []

        init() {}

        init(symbolFileURL: URL) {
            do {
                let symbolFileContents = try String(contentsOf: symbolFileURL)
                let lines = symbolFileContents.components(separatedBy: .newlines)
                for line in lines {
                    if line.hasPrefix("Symbol:") {
                        symbols.append(Symbol(line: line))
                    }
                }
            } catch {
            }
        }

        func lookup(address: UInt16) -> String {
            for symbol in symbols {
                if symbol.address == address {
                    return symbol.label
                }
            }
            return ""
        }
    }

    public init(filePath: String, pc: UInt16 = 0x00, logging: Bool = true) {
        self.filePath = filePath
        self.logging = logging
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            self.program = try [UInt8](Data(contentsOf: fileURL))
        } catch {
            self.program = []
        }
        self.cpu = Turbo9CPU(
            bus: Bus(memory: .createRam(withProgram: self.program)),
            pc: pc
        )
    }

    public func load(url: URL) throws {
        do {
            let program = try Data(contentsOf: url)
            symbolTable = SymbolTable(symbolFileURL: url.deletingPathExtension().appendingPathExtension("map"))
            self.program = [UInt8](program)
            let newRam = [UInt8].createRam(withProgram: self.program, loadAddress: UInt16(0x10000 - program.count))
            cpu.bus.memory = newRam
            cpu.bus.originalRam = newRam
            try cpu.reset()
        } catch {
            fatalError("Could not read file \(url)")
        }
    }

    /// Replace the entire 64 KB memory with the supplied bytes.
    /// Shorter data is zero-padded; longer data is truncated.
    /// The CPU is reset so PC is fetched from the reset vector of the new memory.
    public func loadMemorySnapshot(_ data: Data) {
        var bytes = [UInt8](data)
        if bytes.count < 0x10000 {
            bytes.append(contentsOf: [UInt8](repeating: 0, count: 0x10000 - bytes.count))
        } else if bytes.count > 0x10000 {
            bytes = Array(bytes.prefix(0x10000))
        }
        cpu.bus.memory = bytes
        cpu.bus.originalRam = bytes
        operations = []
        try? cpu.reset()
    }

    /// Returns the entire 64 KB memory as Data, suitable for persisting in a document.
    public func memorySnapshotData() -> Data {
        Data(cpu.bus.memory)
    }

    /// Returns the symbol-table label for the given address, or an empty string if none.
    public func symbol(for address: UInt16) -> String {
        symbolTable.lookup(address: address)
    }

    // MARK: - Document snapshot (memory + CPU registers)

    // Format v1:
    //   bytes  0..3   magic "HYP9"
    //   byte   4      version (1)
    //   bytes  5..7   reserved (zero)
    //   bytes  8..21  CPU registers: A, B, DP, CC, X, Y, U, S, PC
    //                 (UInt16 values are big-endian)
    //   bytes 22..    64 KB of memory
    private static let snapshotMagic: [UInt8] = [0x48, 0x59, 0x50, 0x39] // "HYP9"
    private static let snapshotVersion: UInt8 = 1
    private static let snapshotHeaderSize = 8
    private static let snapshotRegSize = 14
    private static let snapshotMemoryOffset = snapshotHeaderSize + snapshotRegSize

    /// Returns a versioned binary blob with the CPU registers and full memory.
    public func documentSnapshotData() -> Data {
        var data = Data()
        data.reserveCapacity(Disassembler.snapshotMemoryOffset + 0x10000)
        data.append(contentsOf: Disassembler.snapshotMagic)
        data.append(Disassembler.snapshotVersion)
        data.append(contentsOf: [0x00, 0x00, 0x00])
        data.append(cpu.A)
        data.append(cpu.B)
        data.append(cpu.DP)
        data.append(cpu.CC)
        func appendBE(_ v: UInt16) {
            data.append(UInt8((v >> 8) & 0xFF))
            data.append(UInt8(v & 0xFF))
        }
        appendBE(cpu.X)
        appendBE(cpu.Y)
        appendBE(cpu.U)
        appendBE(cpu.S)
        appendBE(cpu.PC)
        data.append(contentsOf: cpu.bus.memory)
        return data
    }

    /// Restore a document snapshot. Accepts either the versioned format above
    /// or a legacy raw 64 KB memory dump (in which case the CPU is reset).
    public func loadDocumentSnapshot(_ data: Data) {
        let bytes = [UInt8](data)
        let header = Disassembler.snapshotMagic
        let isVersioned = bytes.count >= Disassembler.snapshotMemoryOffset
            && bytes[0] == header[0]
            && bytes[1] == header[1]
            && bytes[2] == header[2]
            && bytes[3] == header[3]
        guard isVersioned, bytes[4] == Disassembler.snapshotVersion else {
            // Legacy / unknown — just treat as a memory image and reset.
            loadMemorySnapshot(data)
            return
        }

        // Memory
        let memOffset = Disassembler.snapshotMemoryOffset
        var mem = Array(bytes.dropFirst(memOffset))
        if mem.count < 0x10000 {
            mem.append(contentsOf: [UInt8](repeating: 0, count: 0x10000 - mem.count))
        } else if mem.count > 0x10000 {
            mem = Array(mem.prefix(0x10000))
        }
        cpu.bus.memory = mem
        cpu.bus.originalRam = mem
        operations = []

        // Registers
        let r = Disassembler.snapshotHeaderSize
        cpu.A  = bytes[r]
        cpu.B  = bytes[r + 1]
        cpu.DP = bytes[r + 2]
        cpu.CC = bytes[r + 3]
        func readBE(_ off: Int) -> UInt16 {
            (UInt16(bytes[r + off]) << 8) | UInt16(bytes[r + off + 1])
        }
        cpu.X  = readBE(4)
        cpu.Y  = readBE(6)
        cpu.U  = readBE(8)
        cpu.S  = readBE(10)
        cpu.PC = readBE(12)
    }

    public init(from url: URL, pc: UInt16 = 0x00) {
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not read file \(url)")
        }
        self.program = [UInt8](data)
        self.cpu = Turbo9CPU(
            bus: Bus(memory: .createRam(withProgram: self.program)),
            pc: pc
        )
    }

    // MARK: - Step with logging

    public func step() throws {
        var logLine = ""
        if cpu.syncToInterrupt == false && logging == true {
            if let op = disassemble(pc: cpu.PC) {
                logLine = op.asCode
            }
        }
        let syncToInterruptPre = cpu.syncToInterrupt
        try cpu.step()
        let syncToInterruptPost = cpu.syncToInterrupt
        if (cpu.syncToInterrupt == false || syncToInterruptPre != syncToInterruptPost) && logging == true {
            logLine = logLine.padding(toLength: 60, withPad: " ", startingAt: 0)
            let registers = registerLine()
            logLine += registers
            if let c = instructionClosure {
                c(logLine)
            }
        }
    }

    // MARK: - Disassembly

    public func disassemble(pc: UInt16 = UInt16.max) -> Turbo9Operation? {
        let oldPC = cpu.PC
        let oldA  = cpu.A
        let oldB  = cpu.B
        let oldDP = cpu.DP
        let oldCC = cpu.CC
        let oldX  = cpu.X
        let oldY  = cpu.Y
        let oldU  = cpu.U
        let oldS  = cpu.S

        var operation: Turbo9Operation? = nil

        if pc != UInt16.max {
            cpu.PC = pc
        }

        if program.isWithinBounds(cpu.PC) {
            let offset = cpu.PC
            var prebyte: PreByte = .none
            var opcodeByte = cpu.readByte(cpu.PC)
            cpu.PC = cpu.PC &+ 1

            var opcode: OpCode?
            if opcodeByte == 0x10 {
                prebyte = .page10
                opcodeByte = cpu.readByte(cpu.PC)
                opcode = Turbo9CPU.opcodes10[Int(opcodeByte)]
                cpu.PC = cpu.PC &+ 1
            } else if opcodeByte == 0x11 {
                prebyte = .page11
                opcodeByte = cpu.readByte(cpu.PC)
                opcode = Turbo9CPU.opcodes11[Int(opcodeByte)]
                cpu.PC = cpu.PC &+ 1
            } else {
                opcode = Turbo9CPU.opcodes[Int(opcodeByte)]
            }

            if let opcode = opcode {
                let currentPC = cpu.PC
                cpu.setupAddressing(using: opcode.1)
                let pcOffset = cpu.PC &- currentPC &- 1

                let operand = getOperand(using: opcode.1, offset: pcOffset)
                var postOperand: PostOperand = .none
                if opcode.1 == .ind {
                    if pcOffset == 1 {
                        postOperand = .byte(cpu.readByte(cpu.PC &- 1))
                    } else if pcOffset == 2 {
                        postOperand = .word(cpu.readWord(cpu.PC &- 2))
                    }
                }

                let label = symbolTable.lookup(address: offset)
                if opcode.0 == .swi2 {
                    cpu.PC = cpu.PC &+ 1
                    let swi2Operand = getOperand(using: .imm8, offset: cpu.PC)
                    let os9 = OpCode(.swi2, .imm8, 1)
                    operation = Turbo9Operation(label: label, offset: offset, preByte: prebyte, opcode: opcodeByte, instruction: os9.0, addressMode: opcode.1, operand: swi2Operand, postOperand: postOperand, size: cpu.PC &- oldPC)
                } else {
                    operation = Turbo9Operation(label: label, offset: offset, preByte: prebyte, opcode: opcodeByte, instruction: opcode.0, addressMode: opcode.1, operand: operand, postOperand: postOperand, size: cpu.PC &- oldPC)
                }
            }
        }

        cpu.PC = oldPC
        cpu.A  = oldA
        cpu.B  = oldB
        cpu.X  = oldX
        cpu.Y  = oldY
        cpu.U  = oldU
        cpu.S  = oldS
        cpu.DP = oldDP
        cpu.CC = oldCC

        return operation
    }

    public func disassemble(instructionCount: UInt = 1, startPC: UInt16 = UInt16.max) -> [String] {
        let oldPC = cpu.PC
        for _ in 0..<instructionCount {
            if let op = disassemble(pc: cpu.PC) {
                cpu.PC = cpu.PC &+ UInt16(op.size)
                operations.append(op)
            }
        }
        cpu.PC = oldPC
        return operations.map { $0.asCode }
    }

    public func checkDisassembly() {
        if let last = operations.last, let first = operations.first {
            if cpu.PC >= last.offset || cpu.PC <= first.offset {
                operations = []
                let _ = disassemble(instructionCount: 30, startPC: cpu.PC)
            }
        }
    }

    // MARK: - Private helpers

    private func registerLine() -> String {
        "A:\(String(format: "%02X", cpu.A)) B:\(String(format: "%02X", cpu.B)) DP:\(String(format: "%02X", cpu.DP)) CC:\(cpu.ccString) X:\(String(format: "%04X", cpu.X)) Y:\(String(format: "%04X", cpu.Y)) U:\(String(format: "%04X", cpu.U)) S:\(String(format: "%04X", cpu.S))"
    }

    private func getOperand(using addressMode: AddressMode, offset: UInt16) -> Operand {
        switch addressMode {
        case .inh:   return .none
        case .imm8:  return .immediate8(cpu.readByte(cpu.PC &- 1))
        case .imm16: return .immediate16(cpu.readWord(cpu.PC &- 2))
        case .dir:   return .direct(cpu.readByte(cpu.PC &- 1))
        case .ext:   return .extended(cpu.readWord(cpu.PC &- 2))
        case .ind:   return .indexed(cpu.readByte(cpu.PC &- 1 &- offset))
        case .rel8:  return .relative8(cpu.readByte(cpu.PC &- 1))
        case .rel16: return .relative16(cpu.readWord(cpu.PC &- 2))
        }
    }
}
