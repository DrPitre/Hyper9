import Testing
@testable import Turbo9Sim

struct TestLDAB {
    @Test func test_A_it_loads_memory() async throws {
        let cpu = Turbo9CPU.create(ram: [0x0F])
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .lda, addressMode: .imm8)
        
        #expect(cpu.A == 0x0F)
        #expect(cpu.readCC(.zero) == false)
        #expect(cpu.readCC(.negative) == false)
    }
    
    @Test func test_B_it_loads_memory() async throws {
        let cpu = Turbo9CPU.create(ram: [0x0F])
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .ldb, addressMode: .imm8)
        
        #expect(cpu.B == 0x0F)
        #expect(cpu.readCC(.zero) == false)
        #expect(cpu.readCC(.negative) == false)
    }
    
    @Test func test_A_it_sets_zero_flag() async throws {
        let cpu = Turbo9CPU.create(ram: [0x00])
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .lda, addressMode: .imm8)
        
        #expect(cpu.A == 0x00)
        #expect(cpu.readCC(.zero) == true)
        #expect(cpu.readCC(.negative) == false)
    }
    
    @Test func test_B_it_sets_zero_flag() async throws {
        let cpu = Turbo9CPU.create(ram: [0x00])
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .ldb, addressMode: .imm8)
        
        #expect(cpu.B == 0x00)
        #expect(cpu.readCC(.zero) == true)
        #expect(cpu.readCC(.negative) == false)
    }
    
    @Test func test_A_it_sets_negative_flag() async throws {
        let cpu = Turbo9CPU.create(ram: [0xF0])
        cpu.setupAddressing(using: .imm8)
        
        try cpu.perform(instruction: .lda, addressMode: .imm8)
        
        #expect(cpu.A == 0xF0)
        #expect(cpu.readCC(.zero) == false)
        #expect(cpu.readCC(.negative) == true)
    }
    
    @Test func test_B_it_sets_negative_flag() async throws {
        let cpu = Turbo9CPU.create(ram: [0xF0])
        cpu.setupAddressing(using: .imm8)

        try cpu.perform(instruction: .ldb, addressMode: .imm8)

        #expect(cpu.B == 0xF0)
        #expect(cpu.readCC(.zero) == false)
        #expect(cpu.readCC(.negative) == true)
    }
}

struct TestLDD {
    @Test func test_D_immediate() async throws {
        let cpu = Turbo9CPU.create(ram: [0x0F, 0x30])
        cpu.setupAddressing(using: .imm16)

        try cpu.perform(instruction: .ldd, addressMode: .imm16)

        #expect(cpu.D == 0x0F30)
        #expect(cpu.readCC(.zero) == false)
        #expect(cpu.readCC(.negative) == false)
    }
}

struct TestLDXYUS {
    @Test func test_ldx_loads_value() async throws {
        let cpu = Turbo9CPU.create(ram: [0x12, 0x34])
        cpu.setupAddressing(using: .imm16)

        try cpu.perform(instruction: .ldx, addressMode: .imm16)

        #expect(cpu.X == 0x1234)
        #expect(cpu.readCC(.negative) == false)
        #expect(cpu.readCC(.zero) == false)
        #expect(cpu.readCC(.overflow) == false)
    }

    @Test func test_ldx_sets_zero_flag() async throws {
        let cpu = Turbo9CPU.create(ram: [0x00, 0x00])
        cpu.setupAddressing(using: .imm16)

        try cpu.perform(instruction: .ldx, addressMode: .imm16)

        #expect(cpu.X == 0x0000)
        #expect(cpu.readCC(.zero) == true)
        #expect(cpu.readCC(.negative) == false)
    }

    @Test func test_ldx_sets_negative_flag() async throws {
        let cpu = Turbo9CPU.create(ram: [0xF0, 0x00])
        cpu.setupAddressing(using: .imm16)

        try cpu.perform(instruction: .ldx, addressMode: .imm16)

        #expect(cpu.X == 0xF000)
        #expect(cpu.readCC(.negative) == true)
        #expect(cpu.readCC(.zero) == false)
    }

    @Test func test_ldy_loads_value() async throws {
        let cpu = Turbo9CPU.create(ram: [0xAB, 0xCD])
        cpu.setupAddressing(using: .imm16)

        try cpu.perform(instruction: .ldy, addressMode: .imm16)

        #expect(cpu.Y == 0xABCD)
        #expect(cpu.readCC(.negative) == true)
        #expect(cpu.readCC(.zero) == false)
    }

    @Test func test_ldu_loads_value() async throws {
        let cpu = Turbo9CPU.create(ram: [0x56, 0x78])
        cpu.setupAddressing(using: .imm16)

        try cpu.perform(instruction: .ldu, addressMode: .imm16)

        #expect(cpu.U == 0x5678)
        #expect(cpu.readCC(.negative) == false)
        #expect(cpu.readCC(.zero) == false)
    }

    @Test func test_lds_loads_value() async throws {
        let cpu = Turbo9CPU.create(ram: [0x01, 0xFF])
        cpu.setupAddressing(using: .imm16)

        try cpu.perform(instruction: .lds, addressMode: .imm16)

        #expect(cpu.S == 0x01FF)
        #expect(cpu.readCC(.negative) == false)
        #expect(cpu.readCC(.zero) == false)
    }
}
