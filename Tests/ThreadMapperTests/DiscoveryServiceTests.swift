import Testing
import Foundation
@testable import ThreadMapper

@Suite("DemoDiscoveryService")
struct DemoDiscoveryServiceTests {

    @Test("startScanning populates devices")
    func startScanningPopulatesDevices() async throws {
        let service = DemoDiscoveryService()
        #expect(service.devices.isEmpty)
        try await service.startScanning()
        #expect(!service.devices.isEmpty)
    }

    @Test("demo network contains exactly 8 devices")
    func exactDeviceCount() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        #expect(service.devices.count == 8)
    }

    @Test("demo network contains border routers")
    func containsBorderRouters() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        let brs = service.devices.filter(\.isBorderRouter)
        #expect(brs.count >= 2)
    }

    @Test("demo network contains end devices")
    func containsEndDevices() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        let endDevices = service.devices.filter { !$0.isBorderRouter && !$0.isRouter }
        #expect(!endDevices.isEmpty)
    }

    @Test("all demo devices have unique identifiers")
    func uniqueIdentifiers() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        let ids = service.devices.map(\.uniqueIdentifier)
        let unique = Set(ids)
        #expect(ids.count == unique.count)
    }

    @Test("demo devices span multiple rooms")
    func multipleRooms() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        let rooms = Set(service.devices.compactMap(\.room))
        #expect(rooms.count >= 2)
    }

    @Test("discoveryError is nil after startScanning")
    func noErrorAfterScan() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        #expect(service.discoveryError == nil)
    }

    @Test("measureSignalQualities returns values for all non-offline devices")
    func signalQualitiesForAllDevices() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        let qualities = await service.measureSignalQualities()
        let measurableDevices = service.devices.filter { $0.rssi != -100 }
        for device in measurableDevices {
            #expect(qualities[device.uniqueIdentifier] != nil)
        }
    }

    @Test("measureSignalQualities returns values in valid RSSI range")
    func signalQualitiesInRange() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        let qualities = await service.measureSignalQualities()
        for (_, q) in qualities {
            #expect(q >= -100 && q <= -40)
        }
    }

    @Test("stopScanning does not throw or crash")
    func stopScanningIsSafe() async throws {
        let service = DemoDiscoveryService()
        try await service.startScanning()
        service.stopScanning()
        #expect(service.devices.count == 8)
    }
}

@Suite("DiscoveryService protocol conformance")
struct DiscoveryServiceConformanceTests {

    @Test("MatterDiscoveryService conforms to DiscoveryService")
    func matterConforms() {
        let _: any DiscoveryService = MatterDiscoveryService.shared
    }

    @Test("DemoDiscoveryService conforms to DiscoveryService")
    func demoConforms() {
        let _: any DiscoveryService = DemoDiscoveryService()
    }
}
