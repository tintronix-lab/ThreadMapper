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
}
