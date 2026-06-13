import Testing
@testable import Turbo9Sim

struct TestProgram {
    @Test func test_brn_does_not_branch_and_bra_branches_backward() throws {
        // BRN $3D (branch never) followed by BRA $FC (branch back 4 bytes to 0x0000)
        let cpu = Turbo9CPU.create(ram: [0x21, 0x3D, 0x20, 0xFC], pc: 0x0000)

        try cpu.step()                   // BRN: not taken
        #expect(cpu.PC == 0x0002)

        try cpu.step()                   // BRA $FC (-4): jumps back to 0x0000
        #expect(cpu.PC == 0x0000)
    }

    @Test func test_lda_immediate_loads_register() throws {
        // LDA #$42 followed by NOP
        let cpu = Turbo9CPU.create(ram: [0x86, 0x42, 0x12], pc: 0x0000)

        try cpu.step()                   // LDA #$42

        #expect(cpu.A == 0x42)
        #expect(cpu.readCC(.negative) == false)
        #expect(cpu.readCC(.zero) == false)
        #expect(cpu.PC == 0x0002)
    }
}
