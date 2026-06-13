import Testing
@testable import Turbo9Sim

/*
 IFF b7 of postbyte set, then:    SP' ← SP-1, (SP) ← PCL
 SP' ← SP-1, (SP) ← PCH
 IFF b6 of postbyte set, then:    SP' ← SP-1, (SP) ← USL
 SP' ← SP-1, (SP) ← USH
 IFF b5 of postbyte set, then:    SP' ← SP-1, (SP) ← IYL
 SP' ← SP-1, (SP) ← IYH
 IFF b4 of postbyte set, then:    SP' ← SP-1, (SP) ← IXL
 SP' ← SP-1, (SP) ← IXH
 IFF b3 of postbyte set, then:    SP' ← SP-1, (SP) ← DPR
 IFF b2 of postbyte set, then:    SP' ← SP-1, (SP) ← ACCB
 IFF b1 of postbyte set, then:    SP' ← SP-1, (SP) ← ACCA
 IFF b0 of postbyte set, then:    SP' ← SP-1, (SP) ← CCR
*/
struct TestPSHSPULS {
    @Test func test_pshs_cc() async throws {
        let cpu = Turbo9CPU.create(ram: [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.CC = 0x40
        cpu.S = 0x10
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .pshs, addressMode: .imm8)
        
        #expect(cpu.S == 0x00F)
        #expect(cpu.readByte(cpu.S) == 0x40)
        
        cpu.PC = cpu.PC &- 1
        
        cpu.CC = 0x00
        try cpu.perform(instruction: .puls, addressMode: .imm8)
        
        #expect(cpu.CC == 0x40)
    }
    
    @Test func test_pshs_a() async throws {
        let cpu = Turbo9CPU.create(ram: [0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.A = 0xF1
        cpu.S = 0x10
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .pshs, addressMode: .imm8)
        
        #expect(cpu.S == 0x00F)
        #expect(cpu.readByte(cpu.S) == 0xF1)
        
        cpu.PC = cpu.PC &- 1
        
        cpu.A = 0x00
        try cpu.perform(instruction: .puls, addressMode: .imm8)
        
        #expect(cpu.A == 0xF1)
    }
    
    @Test func test_pshs_b() async throws {
        let cpu = Turbo9CPU.create(ram: [0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.B = 0x1E
        cpu.S = 0x10
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .pshs, addressMode: .imm8)
        
        #expect(cpu.S == 0x00F)
        #expect(cpu.readByte(cpu.S) == 0x1E)
        
        cpu.PC = cpu.PC &- 1
        
        cpu.B = 0x00
        try cpu.perform(instruction: .puls, addressMode: .imm8)
        
        #expect(cpu.B == 0x1E)
    }
    
    @Test func test_pshs_dp() async throws {
        let cpu = Turbo9CPU.create(ram: [0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.DP = 0xA1
        cpu.S = 0x10
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .pshs, addressMode: .imm8)
        
        #expect(cpu.S == 0x00F)
        #expect(cpu.readByte(cpu.S) == 0xA1)
        
        cpu.PC = cpu.PC &- 1
        
        cpu.DP = 0x00
        try cpu.perform(instruction: .puls, addressMode: .imm8)
        
        #expect(cpu.DP == 0xA1)
    }
    
    @Test func test_pshs_x() async throws {
        let cpu = Turbo9CPU.create(ram: [0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.X = 0x3A4D
        cpu.S = 0x10
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .pshs, addressMode: .imm8)
        
        #expect(cpu.S == 0x00E)
        #expect(cpu.readWord(cpu.S) == 0x3A4D)
        
        cpu.PC = cpu.PC &- 1
        
        cpu.X = 0x0000
        try cpu.perform(instruction: .puls, addressMode: .imm8)
        
        #expect(cpu.X == 0x3A4D)
    }
    
    
    @Test func test_pshs_y() async throws {
        let cpu = Turbo9CPU.create(ram: [0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.Y = 0xF99E
        cpu.S = 0x10
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .pshs, addressMode: .imm8)
        
        #expect(cpu.S == 0x00E)
        #expect(cpu.readWord(cpu.S) == 0xF99E)
        
        cpu.PC = cpu.PC &- 1
        
        cpu.Y = 0x0000
        try cpu.perform(instruction: .puls, addressMode: .imm8)
        
        #expect(cpu.Y == 0xF99E)
    }
    
    @Test func test_pshs_u() async throws {
        let cpu = Turbo9CPU.create(ram: [0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.U = 0x77FA
        cpu.S = 0x10
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .pshs, addressMode: .imm8)
        
        #expect(cpu.S == 0x00E)
        #expect(cpu.readWord(cpu.S) == 0x77FA)
        
        cpu.PC = cpu.PC &- 1
        
        cpu.U = 0x0000
        try cpu.perform(instruction: .puls, addressMode: .imm8)
        
        #expect(cpu.U == 0x77FA)
    }
    
    
    @Test func test_pshs_pc() async throws {
        let cpu = Turbo9CPU.create(ram: [0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.S = 0x10
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .pshs, addressMode: .imm8)
        
        #expect(cpu.S == 0x00E)
        #expect(cpu.readWord(cpu.S) == 0x0001)
    }
}


// TODO: Write test cases for PSHU/PULU

struct TestPSHUPULU {
    @Test func test_pshu_a() async throws {
        let cpu = Turbo9CPU.create(ram: [0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.A = 0xF1
        cpu.U = 0x10
        cpu.setupAddressing(using: .imm8)

        try cpu.perform(instruction: .pshu, addressMode: .imm8)

        #expect(cpu.U == 0x0F)
        #expect(cpu.readByte(cpu.U) == 0xF1)

        cpu.PC = cpu.PC &- 1

        cpu.A = 0x00
        try cpu.perform(instruction: .pulu, addressMode: .imm8)

        #expect(cpu.A == 0xF1)
    }

    @Test func test_pshu_b() async throws {
        let cpu = Turbo9CPU.create(ram: [0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.B = 0x3C
        cpu.U = 0x10
        cpu.setupAddressing(using: .imm8)

        try cpu.perform(instruction: .pshu, addressMode: .imm8)

        #expect(cpu.U == 0x0F)
        #expect(cpu.readByte(cpu.U) == 0x3C)

        cpu.PC = cpu.PC &- 1

        cpu.B = 0x00
        try cpu.perform(instruction: .pulu, addressMode: .imm8)

        #expect(cpu.B == 0x3C)
    }

    @Test func test_pshu_x() async throws {
        let cpu = Turbo9CPU.create(ram: [0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        cpu.X = 0x4B5C
        cpu.U = 0x10
        cpu.setupAddressing(using: .imm8)

        try cpu.perform(instruction: .pshu, addressMode: .imm8)

        #expect(cpu.U == 0x0E)
        #expect(cpu.readWord(cpu.U) == 0x4B5C)

        cpu.PC = cpu.PC &- 1

        cpu.X = 0x0000
        try cpu.perform(instruction: .pulu, addressMode: .imm8)

        #expect(cpu.X == 0x4B5C)
    }

    @Test func test_pshu_s() async throws {
        let cpu = Turbo9CPU.create(ram: [0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], stackPointer: 0xABCD)
        cpu.U = 0x10
        cpu.setupAddressing(using: .imm8)

        try cpu.perform(instruction: .pshu, addressMode: .imm8)

        #expect(cpu.U == 0x0E)
        #expect(cpu.readWord(cpu.U) == 0xABCD)
    }
}

