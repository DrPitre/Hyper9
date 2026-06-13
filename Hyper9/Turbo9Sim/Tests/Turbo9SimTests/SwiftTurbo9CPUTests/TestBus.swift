import Testing
@testable import Turbo9Sim

struct TestBusHandlers {
    @Test func test_write_handler_fires_for_registered_address() {
        let bus = Bus()
        var received: UInt8? = nil
        bus.addWriteHandler(handler: BusWriteHandler(address: 0xFF00) { value in
            received = value
        })

        bus.write(0xFF00, data: 0x42)

        #expect(received == 0x42)
    }

    @Test func test_write_handler_does_not_fire_for_different_io_address() {
        let bus = Bus()
        var fired = false
        bus.addWriteHandler(handler: BusWriteHandler(address: 0xFF00) { _ in
            fired = true
        })

        bus.write(0xFF01, data: 0x42)

        #expect(fired == false)
    }

    @Test func test_write_handler_does_not_fire_for_normal_memory_address() {
        let bus = Bus()
        var fired = false
        bus.addWriteHandler(handler: BusWriteHandler(address: 0xFF00) { _ in
            fired = true
        })

        bus.write(0x1234, data: 0x42)

        #expect(fired == false)
        #expect(bus.read(0x1234, readThroughIO: true) == 0x42)
    }

    @Test func test_read_handler_fires_for_registered_address() {
        let bus = Bus()
        bus.addReadHandler(handler: BusReadHandler(address: 0xFF00) { 0x42 })

        let value = bus.read(0xFF00)

        #expect(value == 0x42)
    }

    @Test func test_read_returns_memory_when_no_handler_registered() {
        let bus = Bus()
        bus.write(0xFF00, data: 0x55, writeThroughIO: true)

        let value = bus.read(0xFF00)

        #expect(value == 0x55)
    }

    @Test func test_write_also_updates_memory() {
        let bus = Bus()
        bus.addWriteHandler(handler: BusWriteHandler(address: 0xFF00) { _ in })

        bus.write(0xFF00, data: 0x99)

        #expect(bus.read(0xFF00, readThroughIO: true) == 0x99)
    }

    @Test func test_writeThroughIO_bypasses_handler_but_updates_memory() {
        let bus = Bus()
        var fired = false
        bus.addWriteHandler(handler: BusWriteHandler(address: 0xFF00) { _ in
            fired = true
        })

        bus.write(0xFF00, data: 0x42, writeThroughIO: true)

        #expect(fired == false)
        #expect(bus.read(0xFF00, readThroughIO: true) == 0x42)
    }

    @Test func test_readThroughIO_bypasses_handler_and_returns_memory() {
        let bus = Bus()
        bus.addReadHandler(handler: BusReadHandler(address: 0xFF00) { 0xFF })
        bus.write(0xFF00, data: 0x42, writeThroughIO: true)

        let value = bus.read(0xFF00, readThroughIO: true)

        #expect(value == 0x42)
    }

    @Test func test_reset_restores_original_memory() {
        let bus = Bus()
        bus.write(0x1000, data: 0xAB, writeThroughIO: true)
        #expect(bus.read(0x1000, readThroughIO: true) == 0xAB)

        bus.reset()

        #expect(bus.read(0x1000, readThroughIO: true) != 0xAB)
    }
}
