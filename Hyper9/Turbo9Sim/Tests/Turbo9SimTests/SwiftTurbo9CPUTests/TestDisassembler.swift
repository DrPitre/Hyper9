import Testing
@testable import Turbo9Sim

struct TestDisassembler {
    @Test func test_it_disassembles() {
        let disassembler = Disassembler(program: [0x20, 0x09, 0x00, 0x20, 0x0C, 0x00, 0x20, 0x12, 0x00, 0xA2, 0x00, 0x60, 0xE8, 0xE0, 0x05, 0xD0, 0xFB, 0x60, 0x00])

        let operation = disassembler.disassemble()

        #expect(operation != nil)
        #expect(operation?.opcode == 0x20)
        #expect(operation?.instruction == .bra)
        #expect(operation?.size == 2)
        if case .relative8(let offset) = operation?.operand {
            #expect(offset == 0x09)
        } else {
            Issue.record("Expected relative8 operand")
        }
    }

    @Test func test_dump() {
        let disassembler = Disassembler(program: [0x20, 0x09, 0x00, 0x20, 0x0C, 0x00, 0x20, 0x12, 0x00, 0xA2, 0x00, 0x60, 0xE8, 0xE0, 0x05, 0xD0, 0xFB, 0x60, 0x00])
        var s = disassembler.bus.ramDump(address: 0x00, numBytes: 1)
        #expect(s == "\n\n" +
                "Addr   0 1  2 3  4 5  6 7  8 9  A B  C D  E F 0 2 4 6 8 A C E\n" +
                "----  ---- ---- ---- ---- ---- ---- ---- ---- ----------------\n" +
                "0000  20                                       "
        )

        s = disassembler.bus.ramDump(address: 0x01, numBytes: 1)
        #expect(s == "\n\n" +
                "Addr   0 1  2 3  4 5  6 7  8 9  A B  C D  E F 0 2 4 6 8 A C E\n" +
                "----  ---- ---- ---- ---- ---- ---- ---- ---- ----------------\n" +
                "0001  09                                      ."
        )

        s = disassembler.bus.ramDump(address: 0x01, numBytes: 17)
        #expect(s == "\n\n" +
                "Addr   0 1  2 3  4 5  6 7  8 9  A B  C D  E F 0 2 4 6 8 A C E\n" +
                "----  ---- ---- ---- ---- ---- ---- ---- ---- ----------------\n" +
                "0001  0900 200c 0020 1200 a200 60e8 e005 d0fb .. .. ....`.....\n" +
                "0011  60                                      `"
        )
    }
}
