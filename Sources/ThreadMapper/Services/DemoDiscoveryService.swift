import Foundation

/// Simulated Thread network for demo mode, App Store review, and SwiftUI Previews.
/// Provides a realistic 8-device home without requiring HomeKit authorization.
final class DemoDiscoveryService: DiscoveryService {

    var devices: [ThreadDevice] = []
    var discoveryError: DiscoveryError? = nil

    // MARK: - Simulated network topology

    // Fixed UUIDs so the demo is consistent across app launches.
    private static let id1 = UUID(uuidString: "D0000001-0000-0000-0000-000000000001")!
    private static let id2 = UUID(uuidString: "D0000002-0000-0000-0000-000000000002")!
    private static let id3 = UUID(uuidString: "D0000003-0000-0000-0000-000000000003")!
    private static let id4 = UUID(uuidString: "D0000004-0000-0000-0000-000000000004")!
    private static let id5 = UUID(uuidString: "D0000005-0000-0000-0000-000000000005")!
    private static let id6 = UUID(uuidString: "D0000006-0000-0000-0000-000000000006")!
    private static let id7 = UUID(uuidString: "D0000007-0000-0000-0000-000000000007")!
    private static let id8 = UUID(uuidString: "D0000008-0000-0000-0000-000000000008")!

    private static let demoDevices: [ThreadDevice] = [
        // Border routers
        ThreadDevice(
            name: "HomePod mini",
            manufacturer: "Apple", productName: "HomePod mini", deviceType: "Speaker",
            uniqueIdentifier: id1, isBorderRouter: true, isRouter: true,
            isSleepyEndDevice: false, channel: 15, rssi: -55, room: "Living Room"
        ),
        ThreadDevice(
            name: "HomePod mini — Bedroom",
            manufacturer: "Apple", productName: "HomePod mini", deviceType: "Speaker",
            uniqueIdentifier: id2, isBorderRouter: true, isRouter: true,
            isSleepyEndDevice: false, channel: 15, rssi: -62, room: "Bedroom"
        ),
        // Routers
        ThreadDevice(
            name: "Nanoleaf Shapes",
            manufacturer: "Nanoleaf", productName: "Shapes Hexagon", deviceType: "Light",
            uniqueIdentifier: id3, isBorderRouter: false, isRouter: true,
            isSleepyEndDevice: false, channel: 15, rssi: -68, room: "Living Room"
        ),
        ThreadDevice(
            name: "Eve Energy — Kitchen",
            manufacturer: "Eve Systems", productName: "Eve Energy", deviceType: "Outlet",
            uniqueIdentifier: id4, isBorderRouter: false, isRouter: true,
            isSleepyEndDevice: false, channel: 15, rssi: -63, room: "Kitchen"
        ),
        // End devices
        ThreadDevice(
            name: "Eve Motion — Living Room",
            manufacturer: "Eve Systems", productName: "Eve Motion", deviceType: "Sensor",
            uniqueIdentifier: id5, isBorderRouter: false, isRouter: false,
            isSleepyEndDevice: true, channel: 15, rssi: -70, batteryPercentage: 82, room: "Living Room"
        ),
        ThreadDevice(
            name: "Eve Contact — Bedroom Door",
            manufacturer: "Eve Systems", productName: "Eve Door & Window", deviceType: "Sensor",
            uniqueIdentifier: id6, isBorderRouter: false, isRouter: false,
            isSleepyEndDevice: true, channel: 15, rssi: -74, batteryPercentage: 54, room: "Bedroom"
        ),
        ThreadDevice(
            name: "Nanoleaf Bulb — Kitchen",
            manufacturer: "Nanoleaf", productName: "Essentials Bulb", deviceType: "Light",
            uniqueIdentifier: id7, isBorderRouter: false, isRouter: false,
            isSleepyEndDevice: false, channel: 15, rssi: -77, room: "Kitchen"
        ),
        // One weak device to make the dashboard interesting
        ThreadDevice(
            name: "Eve Door — Garage",
            manufacturer: "Eve Systems", productName: "Eve Door & Window", deviceType: "Sensor",
            uniqueIdentifier: id8, isBorderRouter: false, isRouter: false,
            isSleepyEndDevice: true, channel: 15, rssi: -85, batteryPercentage: 12, room: "Garage"
        ),
    ]

    // MARK: - DiscoveryService

    func startScanning() async throws {
        await MainActor.run {
            devices = Self.demoDevices
        }
    }

    func stopScanning() {}

    func measureSignalQualities() async -> [UUID: Int] {
        // Simulate realistic jitter (±5 dBm) so the sparklines show movement.
        var result: [UUID: Int] = [:]
        for device in devices {
            guard let base = device.rssi, base != -100 else { continue }
            let jitter = Int.random(in: -5...5)
            result[device.uniqueIdentifier] = max(-92, min(-55, base + jitter))
        }
        return result
    }
}
