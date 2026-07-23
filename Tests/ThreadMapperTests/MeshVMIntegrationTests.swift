@testable import ThreadMapper
import XCTest

@MainActor
final class MeshViewModelOnlyTests: XCTestCase {
    func testWarnings_noRouters_reportsBorderRouter() throws {
        let devices = [
            ThreadDevice(name: "B", manufacturer: "T", productName: "B", deviceType: "Lightbulb", uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: false, isSleepyEndDevice: true)
        ]
        let vm = MeshViewModel()
        vm.devices = devices
        XCTAssertTrue(vm.warnings().contains { $0.contains("No Thread border router detected") })
    }

    func testRouterDensity_filtersByRoom() throws {
        let d1 = ThreadDevice(name: "A", manufacturer: "T", productName: "A", deviceType: "Sensor", uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: true, isSleepyEndDevice: false, parentNodeID: nil, channel: nil, rssi: nil, batteryPercentage: nil, room: "Kitchen")
        let d2 = ThreadDevice(name: "B", manufacturer: "T", productName: "B", deviceType: "Sensor", uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: true, isSleepyEndDevice: false, parentNodeID: nil, channel: nil, rssi: nil, batteryPercentage: nil, room: "Garage")
        let vm = MeshViewModel()
        vm.devices = [d1, d2]
        XCTAssertEqual(vm.routerDensity(for: "Kitchen"), 1)
        XCTAssertEqual(vm.routerDensity(), 2)
    }

    /// End-to-end guard for the non-Thread override: a device marked non-Thread
    /// (by `uniqueIdentifier`) must be dropped from the built mesh graph. This is
    /// where the id-vs-uniqueIdentifier mismatch used to silently no-op — the
    /// toggle wrote one key while the filter read the other.
    func testNonThreadOverrideHidesDeviceFromMesh() throws {
        let hub = ThreadDevice(name: "Thread Hub", manufacturer: "Apple", productName: "HomePod",
                               deviceType: "Speaker", uniqueIdentifier: UUID(),
                               isBorderRouter: true, isRouter: true, isSleepyEndDevice: false,
                               parentNodeID: nil, channel: 15, rssi: -55, batteryPercentage: nil, room: "Living Room")
        let zigbee = ThreadDevice(name: "Zigbee Bridge", manufacturer: "IKEA", productName: "DIRIGERA",
                                  deviceType: "Bridge", uniqueIdentifier: UUID(),
                                  isBorderRouter: true, isRouter: true, isSleepyEndDevice: false,
                                  parentNodeID: nil, channel: 15, rssi: -60, batteryPercentage: nil, room: "Living Room")
        let vm = MeshViewModel()
        vm.devices = [hub, zigbee]

        let store = DeviceOverrideStore.shared
        store.setNonThread(zigbee.uniqueIdentifier, false)  // clean slate
        defer { store.setNonThread(zigbee.uniqueIdentifier, false) }

        vm.selectedChannel = 15                             // didSet -> applyFilters (nil -> 15)
        XCTAssertTrue(vm.nodes.contains { $0.deviceID == hub.uniqueIdentifier })
        XCTAssertTrue(vm.nodes.contains { $0.deviceID == zigbee.uniqueIdentifier },
                      "both devices are visible before the override is applied")

        store.setNonThread(zigbee.uniqueIdentifier, true)
        vm.selectedChannel = 15                             // re-trigger applyFilters (15 -> 15)
        XCTAssertTrue(vm.nodes.contains { $0.deviceID == hub.uniqueIdentifier })
        XCTAssertFalse(vm.nodes.contains { $0.deviceID == zigbee.uniqueIdentifier },
                       "the excluded device must be filtered out of the mesh graph")
    }
}
