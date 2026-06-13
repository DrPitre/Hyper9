import Testing
@testable import Turbo9Sim

struct TestInterrupts {
    @Test func test_cwai_sets_sync_and_entire_flag_and_pushes_state() async throws {
        let cpu = Turbo9CPU.create(ram: [0xFF], acca: 0x11, accb: 0x22, stackPointer: 0x01FF)
        cpu.setupAddressing(using: .imm8)

        try cpu.perform(instruction: .cwai, addressMode: .imm8)

        #expect(cpu.syncToInterrupt == true)
        #expect(cpu.readCC(.entire) == true)
        // CWAI pushes PC(2), U(2), Y(2), X(2), DP(1), B(1), A(1), CC(1) = 12 bytes
        #expect(cpu.S == 0x01FF - 12)
    }

    @Test func test_sync_sets_sync_flag_without_changing_registers() async throws {
        let cpu = Turbo9CPU.create(ram: [0x00], acca: 0x42, accb: 0x55)
        cpu.setupAddressing(using: .inh)

        try cpu.perform(instruction: .sync, addressMode: .inh)

        #expect(cpu.syncToInterrupt == true)
        #expect(cpu.A == 0x42)
        #expect(cpu.B == 0x55)
        #expect(cpu.CC == 0x00)
    }
}
