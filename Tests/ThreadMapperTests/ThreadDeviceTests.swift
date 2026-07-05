import Testing
import Foundation
@testable import ThreadMapper

private func makeDevice(rssi: Int? = nil) -> ThreadDevice {
    ThreadDevice(
        name: "Sensor", manufacturer: "Eve", productName: "Door", deviceType: "Sensor",
        uniqueIdentifier: UUID(), isBorderRouter: false, isRouter: false, isSleepyEndDevice: true,
        rssi: rssi
    )
}

@Suite("ThreadDevice helpers")
struct ThreadDeviceTests {

    // MARK: isOffline

    @Test("isOffline is true when rssi is -100")
    func isOfflineWhenSentinel() {
        let device = makeDevice(rssi: -100)
        #expect(device.isOffline == true)
    }

    @Test("isOffline is false when rssi is -65")
    func isNotOfflineWhenGoodSignal() {
        let device = makeDevice(rssi: -65)
        #expect(device.isOffline == false)
    }

    @Test("isOffline is false when rssi is nil")
    func isNotOfflineWhenNil() {
        let device = makeDevice(rssi: nil)
        #expect(device.isOffline == false)
    }

    // MARK: isWeak

    @Test("isWeak is true when rssi < -80")
    func isWeakWhenPoorSignal() {
        #expect(makeDevice(rssi: -81).isWeak == true)
        #expect(makeDevice(rssi: -85).isWeak == true)
        #expect(makeDevice(rssi: -92).isWeak == true)
    }

    @Test("isWeak is false when rssi >= -80")
    func isNotWeakWhenFairSignal() {
        #expect(makeDevice(rssi: -80).isWeak == false)
        #expect(makeDevice(rssi: -65).isWeak == false)
        #expect(makeDevice(rssi: -55).isWeak == false)
    }

    @Test("isWeak is false when device is offline")
    func isNotWeakWhenOffline() {
        #expect(makeDevice(rssi: -100).isWeak == false)
    }

    @Test("isWeak is false when rssi is nil")
    func isNotWeakWhenNil() {
        #expect(makeDevice(rssi: nil).isWeak == false)
    }

    // MARK: reachability

    @Test("reachability is nil when rssi is nil")
    func reachabilityNilWhenNoMeasurement() {
        #expect(makeDevice(rssi: nil).reachability == nil)
    }

    @Test("reachability is .offline when rssi is -100")
    func reachabilityOfflineWhenSentinel() {
        #expect(makeDevice(rssi: -100).reachability == .offline)
    }

    @Test("reachability is .quality when rssi is measured")
    func reachabilityQualityWhenMeasured() {
        let device = makeDevice(rssi: -65)
        if case .quality(let q) = device.reachability {
            #expect(q == -65)
        } else {
            Issue.record("Expected .quality(-65), got \(String(describing: device.reachability))")
        }
    }

    // MARK: metadataSignature

    @Test("metadataSignature changes on name change")
    func signatureChangesOnRename() {
        let uuid = UUID()
        let d1 = ThreadDevice(
            name: "Sensor A", manufacturer: "Eve", productName: "Door", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true
        )
        let d2 = ThreadDevice(
            name: "Sensor B", manufacturer: "Eve", productName: "Door", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true
        )
        #expect(d1.metadataSignature != d2.metadataSignature)
    }

    @Test("metadataSignature changes on room change")
    func signatureChangesOnRoomMove() {
        let uuid = UUID()
        let d1 = ThreadDevice(
            name: "Sensor", manufacturer: "Eve", productName: "Door", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true,
            room: "Kitchen"
        )
        let d2 = ThreadDevice(
            name: "Sensor", manufacturer: "Eve", productName: "Door", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true,
            room: "Bedroom"
        )
        #expect(d1.metadataSignature != d2.metadataSignature)
    }

    @Test("metadataSignature is stable when nothing changes")
    func signatureStableWithNoChanges() {
        let uuid = UUID()
        let d = ThreadDevice(
            name: "Sensor", manufacturer: "Eve", productName: "Door", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true,
            room: "Kitchen"
        )
        #expect(d.metadataSignature == d.metadataSignature)
    }

    @Test("metadataSignature changes on battery change")
    func signatureChangesOnBatteryChange() {
        let uuid = UUID()
        let d1 = ThreadDevice(
            name: "Sensor", manufacturer: "Eve", productName: "Door", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true,
            batteryPercentage: 80
        )
        let d2 = ThreadDevice(
            name: "Sensor", manufacturer: "Eve", productName: "Door", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true,
            batteryPercentage: 10
        )
        #expect(d1.metadataSignature != d2.metadataSignature)
    }

    // MARK: Hashable / Equatable (identity only)

    @Test("Two devices with same uniqueIdentifier are equal regardless of name")
    func equalityIsIdentityBased() {
        let uuid = UUID()
        let d1 = ThreadDevice(
            name: "Name A", manufacturer: "A", productName: "A", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true
        )
        let d2 = ThreadDevice(
            name: "Name B", manufacturer: "B", productName: "B", deviceType: "Sensor",
            uniqueIdentifier: uuid, isBorderRouter: false, isRouter: false, isSleepyEndDevice: true
        )
        #expect(d1 == d2)
    }

    @Test("Two devices with different uniqueIdentifiers are not equal")
    func differentUUIDsNotEqual() {
        let d1 = makeDevice()
        let d2 = makeDevice()
        #expect(d1 != d2)
    }
}
