import Foundation
import Testing
@testable import ThreadMapper

/// Regression guard for the device-identity root cause: `ThreadDevice` once
/// carried a separate stored `id` (a fresh random `UUID()` regenerated every
/// launch) alongside `uniqueIdentifier` (the stable HomeKit accessory ID).
/// Notifications, activity events, stats, and overrides all key on
/// `uniqueIdentifier`, so any lookup that matched on `id` silently failed
/// (nil device / "Unknown Device" / empty history) without crashing — which is
/// how the bug escaped review. `id` is now computed as `uniqueIdentifier`, so
/// the two can never diverge again. These tests pin that invariant.
@Suite struct DeviceIdentityResolutionTests {

    private func makeDevice(name: String, uniqueIdentifier: UUID) -> ThreadDevice {
        ThreadDevice(
            name: name,
            manufacturer: "Eve",
            productName: "Eve Door",
            deviceType: "Sensor",
            uniqueIdentifier: uniqueIdentifier,
            isBorderRouter: false,
            isRouter: false,
            rssi: SignalThresholds.offlineSentinel
        )
    }

    @Test("id is always backed by uniqueIdentifier")
    func idEqualsUniqueIdentifier() {
        let uid = UUID()
        let device = makeDevice(name: "Front Door", uniqueIdentifier: uid)
        #expect(device.id == uid)
        #expect(device.id == device.uniqueIdentifier)
    }

    @Test("Codable round-trip keeps id and uniqueIdentifier aligned")
    func codableRoundTripPreservesIdentity() throws {
        let uid = UUID()
        let original = makeDevice(name: "Bedroom Sensor", uniqueIdentifier: uid)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThreadDevice.self, from: data)
        #expect(decoded.uniqueIdentifier == uid)
        #expect(decoded.id == uid)
        #expect(decoded.id == decoded.uniqueIdentifier)
    }

    @Test("Automation suggestions resolve the device name by uniqueIdentifier")
    func automationSuggestionResolvesName() {
        let uid = UUID()
        let device = makeDevice(name: "Front Door", uniqueIdentifier: uid)

        // Three offline events keyed by uniqueIdentifier trip the "troubled
        // device" threshold (>= 3) inside automationSuggestions.
        let offlineEvents = (0..<3).map { i in
            ActivityEvent(
                id: UUID(),
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)),
                kind: .deviceOffline,
                deviceID: uid,
                deviceName: "Front Door",
                room: "Entry",
                detail: "Front Door went offline"
            )
        }

        let suggestions = SmartHomeAdvisor().automationSuggestions(
            devices: [device],
            offlineEvents: offlineEvents
        )

        // The interpolated device name is inserted verbatim regardless of the
        // simulator locale, so asserting on it is locale-safe.
        #expect(suggestions.contains { $0.title.contains("Front Door") })
        #expect(!suggestions.contains { $0.title.contains("Unknown Device") })
    }
}
