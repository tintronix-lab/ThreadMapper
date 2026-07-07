import XCTest
@testable import ThreadMapper

final class ThreadDiagnosticsTests: XCTestCase {

    private func dev(_ name: String, br: Bool = false, battery: Int? = nil, room: String? = nil) -> ThreadDevice {
        ThreadDevice(id: UUID(), name: name, manufacturer: "T", productName: name, deviceType: "X",
                     uniqueIdentifier: UUID(), isBorderRouter: br, isRouter: br,
                     isSleepyEndDevice: !br, channel: 15, rssi: -60,
                     batteryPercentage: battery, room: room)
    }

    // Real routing table: BR(leader) ← router ← sleepy child, by RLOC parentage.
    func testRealDiagnosticsBuildsParentEdgesFromRLOC() throws {
        let br = dev("HomePod", br: true, room: "Living Room")
        let router = dev("Kitchen Plug", room: "Kitchen")
        let child = dev("Kitchen Sensor", battery: 70, room: "Kitchen")

        let diagnostics: [UUID: ThreadNodeDiagnostics] = [
            br.id: ThreadNodeDiagnostics(deviceID: br.id, role: .leader, rloc16: 0x0000),
            router.id: ThreadNodeDiagnostics(deviceID: router.id, role: .router,
                                             rloc16: 0x0400, parentRloc16: 0x0000),
            child.id: ThreadNodeDiagnostics(deviceID: child.id, role: .sleepyEndDevice,
                                            rloc16: 0x0401, parentRloc16: 0x0400),
        ]

        let (nodes, links) = MeshTopologyBuilder.buildGraph(from: [br, router, child],
                                                            diagnostics: diagnostics)

        XCTAssertNotNil(nodes.first { $0.kind == .gateway })
        let routerNode = nodes.first { $0.name == "Kitchen Plug" }
        let childNode = nodes.first { $0.name == "Kitchen Sensor" }
        XCTAssertEqual(routerNode?.kind, .router)
        XCTAssertEqual(routerNode?.parentID, br.id)
        XCTAssertEqual(childNode?.kind, .endDevice)
        XCTAssertTrue(childNode?.isBattery ?? false)
        XCTAssertEqual(childNode?.parentID, router.id, "child should route through the real parent router")
        // gateway→BR, BR→router, router→child
        XCTAssertEqual(links.count, 3)
    }

    func testEmptyDiagnosticsFallsBackToInference() throws {
        let br = dev("BR", br: true)
        let sensor = dev("Sensor", battery: 50, room: "Den")
        let real = MeshTopologyBuilder.buildGraph(from: [br, sensor], diagnostics: [:])
        let inferred = MeshTopologyBuilder.buildGraph(from: [br, sensor])
        XCTAssertEqual(real.0.count, inferred.0.count)
        XCTAssertEqual(real.1.count, inferred.1.count)
    }

    func testLinkQualityFromLinkMargin() throws {
        let strong = ThreadNodeDiagnostics(deviceID: UUID(), role: .child, neighbors: [
            .init(rloc16: 0x0400, linkMarginDB: 22, averageRSSI: nil, isChild: false),
        ])
        XCTAssertEqual(strong.linkQuality, 4)
        let weak = ThreadNodeDiagnostics(deviceID: UUID(), role: .child, neighbors: [
            .init(rloc16: 0x0400, linkMarginDB: 3, averageRSSI: nil, isChild: false),
        ])
        XCTAssertEqual(weak.linkQuality, 1)
    }

    func testRoleMapsToMeshKind() throws {
        func kind(_ role: ThreadNodeDiagnostics.Role) -> MeshNodeKind {
            ThreadNodeDiagnostics(deviceID: UUID(), role: role).meshKind
        }
        XCTAssertEqual(kind(.leader), .router)
        XCTAssertEqual(kind(.router), .router)
        XCTAssertEqual(kind(.reed), .router)
        XCTAssertEqual(kind(.child), .endDevice)
        XCTAssertEqual(kind(.sleepyEndDevice), .endDevice)
        XCTAssertEqual(kind(.unknown), .endDevice)
    }

    func testNoDiagnosticsProviderYieldsNothing() async {
        let provider = NoDiagnosticsProvider()
        let nets = await provider.threadNetworks()
        let nodes = await provider.nodeDiagnostics()
        XCTAssertTrue(nets.isEmpty)
        XCTAssertTrue(nodes.isEmpty)
    }

    func testProviderPopulatesThreadNetworksOnViewModel() async {
        let fake = FakeDiagnosticsProvider(
            networks: [ThreadNetworkInfo(networkName: "MyThread", channel: 20,
                                         panID: "0x1234", extendedPANID: nil, borderAgentID: nil)],
            diagnostics: [:]
        )
        let vm = MeshViewModel(discovery: DemoDiscoveryService(), diagnostics: fake)
        await vm.refreshDiagnostics()
        let net = await MainActor.run { vm.threadNetworks.first }
        XCTAssertEqual(net?.networkName, "MyThread")
        XCTAssertEqual(net?.channel, 20)
    }
}

private final class FakeDiagnosticsProvider: DiagnosticsProvider {
    let networks: [ThreadNetworkInfo]
    let diagnostics: [UUID: ThreadNodeDiagnostics]
    init(networks: [ThreadNetworkInfo], diagnostics: [UUID: ThreadNodeDiagnostics]) {
        self.networks = networks
        self.diagnostics = diagnostics
    }
    func threadNetworks() async -> [ThreadNetworkInfo] { networks }
    func nodeDiagnostics() async -> [UUID: ThreadNodeDiagnostics] { diagnostics }
}
