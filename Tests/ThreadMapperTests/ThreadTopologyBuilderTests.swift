@testable import ThreadMapper
import XCTest

final class ThreadTopologyBuilderTests: XCTestCase {

    private func dev(_ name: String, br: Bool = false, router: Bool = false,
                     battery: Int? = nil, room: String? = nil, rssi: Int? = -60,
                     parent: String? = nil) -> ThreadDevice {
        ThreadDevice(
            name: name, manufacturer: "T", productName: name, deviceType: "X",
            uniqueIdentifier: UUID(), isBorderRouter: br, isRouter: router,
            isSleepyEndDevice: !br && !router, parentNodeID: parent,
            channel: 15, rssi: rssi, batteryPercentage: battery, room: room
        )
    }

    func testBorderRouterCreatesGatewayAndBackbone() throws {
        let br = dev("BR", br: true, router: true)
        let end = dev("Sensor", battery: 80, room: "Bedroom")
        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [br, end])

        // gateway + BR + end
        XCTAssertEqual(nodes.count, 3)
        XCTAssertNotNil(nodes.first { $0.kind == .gateway })
        XCTAssertEqual(nodes.first { $0.name == "BR" }?.kind, .borderRouter)

        // backbone gateway→BR and mesh BR→end
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links.first { $0.kind == .backbone }?.targetID, br.id)
        // No router present, so the end device attaches straight to the BR.
        XCTAssertEqual(nodes.first { $0.name == "Sensor" }?.parentID, br.id)
    }

    func testEndDeviceHopsThroughSameRoomRouter() throws {
        // The core feature: a leaf routes through another Matter device (a router)
        // in its room rather than straight to a border router in another room.
        let br = dev("HomePod", br: true, router: true, room: "Living Room", rssi: -55)
        let router = dev("Kitchen Plug", router: true, room: "Kitchen", rssi: -63)
        let sensor = dev("Kitchen Sensor", battery: 70, room: "Kitchen", rssi: -78)
        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [br, router, sensor])

        let sensorNode = nodes.first { $0.name == "Kitchen Sensor" }
        XCTAssertEqual(sensorNode?.parentID, router.id, "sensor should relay through the same-room router")
        XCTAssertEqual(sensorNode?.tier, 3)
        XCTAssertEqual(nodes.first { $0.name == "Kitchen Plug" }?.parentID, br.id)
        // gateway→BR, BR→router, router→sensor
        XCTAssertEqual(links.count, 3)
    }

    func testExplicitParentNodeIDIsHonored() throws {
        let br = dev("BR", br: true, router: true)
        let sensor = dev("Sensor", battery: 60, room: "Attic", parent: nil)
        // Point the sensor's parent explicitly at the BR.
        let sensorWithParent = dev("Sensor2", battery: 60, room: "Attic", parent: br.id.uuidString)
        let (nodes, _) = MeshTopologyBuilder.buildGraph(from: [br, sensor, sensorWithParent])
        XCTAssertEqual(nodes.first { $0.name == "Sensor2" }?.parentID, br.id)
    }

    func testNoBorderRouterNoGatewayNoLinks() throws {
        let orphan = dev("Orphan", battery: 50)
        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [orphan])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertNil(nodes.first { $0.kind == .gateway })
        XCTAssertTrue(links.isEmpty)
        XCTAssertEqual(nodes.first?.kind, .endDevice)
    }

    func testMainsDeviceInferredAsRouterWithoutExplicitRoles() throws {
        // No device is explicitly a router → infer from power: no battery ⇒ relay.
        let br = dev("BR", br: true)                       // BR (isRouter false here)
        let bulb = dev("Bulb", battery: nil, room: "Den")  // mains, no battery ⇒ router
        let sensor = dev("Sensor", battery: 40, room: "Den") // battery ⇒ end device
        let (nodes, _) = MeshTopologyBuilder.buildGraph(from: [br, bulb, sensor])
        XCTAssertEqual(nodes.first { $0.name == "Bulb" }?.kind, .router)
        XCTAssertEqual(nodes.first { $0.name == "Sensor" }?.kind, .endDevice)
        // Sensor relays through the inferred same-room router.
        XCTAssertEqual(nodes.first { $0.name == "Sensor" }?.parentID, bulb.id)
    }
}
