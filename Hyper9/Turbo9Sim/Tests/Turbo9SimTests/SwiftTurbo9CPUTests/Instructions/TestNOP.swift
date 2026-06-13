import Testing
@testable import Turbo9Sim

struct TestNOP {
    @Test func test_nop_leaves_all_registers_unchanged() async throws {
        let cpu = Turbo9CPU.create(ram: [0x00], acca: 0x08, accb: 0x42, X: 0x1234, Y: 0x5678)
        cpu.setupAddressing(using: .inh)

        try cpu.perform(instruction: .nop, addressMode: .inh)

        #expect(cpu.A == 0x08)
        #expect(cpu.B == 0x42)
        #expect(cpu.X == 0x1234)
        #expect(cpu.Y == 0x5678)
        #expect(cpu.U == 0x0000)
        #expect(cpu.DP == 0x00)
        #expect(cpu.CC == 0x00)
    }
}
