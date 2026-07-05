import Testing
import Foundation
@testable import ThreadMapper

/// Tests for the Reachability enum and all ThreadDevice computed properties
/// that depend on it: isOffline, isWeak, reachability.
@Suite("Reachability enum")
struct ReachabilityTests {

    // MARK: Equatable

    @Test(".offline equals .offline")
    func offlineEquality() {
        #expect(Reachability.offline == Reachability.offline)
    }

    @Test(".quality equals .quality with same value")
    func qualityEquality() {
        #expect(Reachability.quality(-65) == Reachability.quality(-65))
    }

    @Test(".quality does not equal .offline")
    func qualityNotEqualsOffline() {
        #expect(Reachability.quality(-65) != Reachability.offline)
    }

    @Test(".quality with different values are not equal")
    func differentQualitiesNotEqual() {
        #expect(Reachability.quality(-65) != Reachability.quality(-80))
    }

    // MARK: ThreadDevice.reachability mapping

    @Test("rssi nil → reachability nil")
    func nilRSSI() {
        let d = device(rssi: nil)
        #expect(d.reachability == nil)
    }

    @Test("rssi -100 → .offline")
    func offlineSentinel() {
        #expect(device(rssi: -100).reachability == .offline)
    }

    @Test("rssi -92 → .quality(-92)")
    func readFailedMapsToQuality() {
        if case .quality(let q) = device(rssi: -92).reachability {
            #expect(q == -92)
        } else {
            Issue.record("Expected .quality(-92)")
        }
    }

    @Test("rssi -55 → .quality(-55)")
    func excellentMapsToQuality() {
        if case .quality(let q) = device(rssi: -55).reachability {
            #expect(q == -55)
        } else {
            Issue.record("Expected .quality(-55)")
        }
    }

    // MARK: isOffline / isWeak boundary tests

    @Test("boundary: rssi -79 is not weak")
    func notWeakAt79() {
        #expect(device(rssi: -79).isWeak == false)
    }

    @Test("boundary: rssi -80 is not weak (> not >=)")
    func notWeakAt80() {
        #expect(device(rssi: -80).isWeak == false)
    }

    @Test("boundary: rssi -81 is weak")
    func weakAt81() {
        #expect(device(rssi: -81).isWeak == true)
    }

    // MARK: Consistency between isOffline and reachability

    @Test("isOffline and reachability == .offline are consistent")
    func isOfflineConsistency() {
        let offline = device(rssi: -100)
        let online = device(rssi: -65)
        #expect(offline.isOffline == (offline.reachability == .offline))
        #expect(online.isOffline == (online.reachability == .offline))
    }

    // MARK: Helpers

    private func device(rssi: Int?) -> ThreadDevice {
        ThreadDevice(
            name: "Test", manufacturer: "M", productName: "P", deviceType: "Sensor",
            uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: false,
            isSleepyEndDevice: true, rssi: rssi
        )
    }
}
