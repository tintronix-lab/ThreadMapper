import Testing
import Foundation
@testable import ThreadMapper

// MARK: - Helpers

private func makeDevice(
    name: String = "Device",
    isBorderRouter: Bool = false,
    isRouter: Bool = false,
    rssi: Int? = -65,
    batteryPercentage: Int? = nil,
    channel: Int? = nil,
    room: String? = "Living Room"
) -> ThreadDevice {
    ThreadDevice(
        name: name, manufacturer: "Test", productName: name, deviceType: "Sensor",
        uniqueIdentifier: UUID(), isBorderRouter: isBorderRouter, isRouter: isRouter,
        isSleepyEndDevice: !isRouter && !isBorderRouter,
        channel: channel, rssi: rssi, batteryPercentage: batteryPercentage, room: room
    )
}

// MARK: - Tests

@Suite("NetworkHealthScore")
struct NetworkHealthScoreTests {

    // MARK: Empty

    @Test("Empty device list → score 0, grade F")
    func emptyDevices() {
        let result = NetworkHealthScore.compute(devices: [])
        #expect(result.score == 0)
        #expect(result.grade == "F")
        #expect(result.issues.contains { $0.message.contains("No Thread devices") })
    }

    // MARK: Grade thresholds

    @Test("Score 100 → grade A")
    func gradeA() {
        // Two border routers, all devices healthy → score 100
        let devices = [
            makeDevice(name: "BR1", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60),
            makeDevice(name: "D1", rssi: -62),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score >= 90)
        #expect(result.grade == "A")
    }

    @Test("Score 75–89 → grade B")
    func gradeB() {
        // Single border router → -15 penalty → 85
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "D1", rssi: -62),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score >= 75 && result.score < 90)
        #expect(result.grade == "B")
    }

    @Test("Score below 40 → grade F")
    func gradeF() {
        // No border router (-40) + 2 offline (-24) → 36
        let devices = [
            makeDevice(name: "D1", rssi: -100),
            makeDevice(name: "D2", rssi: -100),
            makeDevice(name: "D3", rssi: -65),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.grade == "F")
    }

    // MARK: Border router penalties

    @Test("No border router → -40 penalty and critical issue")
    func noBorderRouter() {
        let devices = [makeDevice(name: "D1", rssi: -65)]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score == 60)
        #expect(result.issues.contains { $0.message.contains("No border router") && $0.isCritical })
    }

    @Test("Single border router → -15 penalty, non-critical issue")
    func singleBorderRouter() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "D1", rssi: -62),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score == 85)
        let issue = result.issues.first { $0.message.contains("Single border router") }
        #expect(issue != nil)
        #expect(issue?.isCritical == false)
    }

    @Test("Two border routers → no redundancy penalty")
    func twoBorderRouters() {
        let devices = [
            makeDevice(name: "BR1", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score == 100)
        #expect(result.issues.isEmpty)
    }

    // MARK: Offline penalties

    @Test("One offline device → -12 penalty and critical issue")
    func oneOffline() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60),
            makeDevice(name: "D1", rssi: -100),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score == 88)
        #expect(result.issues.contains { $0.message.contains("offline") && $0.isCritical })
    }

    @Test("Offline penalty is capped at 30 points")
    func offlineCap() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60),
        ] + (0..<5).map { makeDevice(name: "D\($0)", rssi: -100) }
        let result = NetworkHealthScore.compute(devices: devices)
        // 100 - 30 (cap) - other penalties
        #expect(result.score >= 70)
    }

    // MARK: Weak signal penalties

    @Test("One weak device → score penalty")
    func oneWeakDevice() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60),
            makeDevice(name: "Weak", rssi: -85),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score == 93)
    }

    @Test("Weak device issue is non-critical when count ≤ 2")
    func weakDeviceNonCritical() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60),
            makeDevice(name: "W1", rssi: -85),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        let issue = result.issues.first { $0.message.contains("weak signal") }
        #expect(issue?.isCritical == false)
    }

    @Test("3+ weak devices → critical issue")
    func manyWeakDevicesCritical() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60),
            makeDevice(name: "W1", rssi: -83),
            makeDevice(name: "W2", rssi: -85),
            makeDevice(name: "W3", rssi: -88),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        let issue = result.issues.first { $0.message.contains("weak signal") }
        #expect(issue?.isCritical == true)
    }

    // MARK: Low battery

    @Test("Low battery device → -5 penalty and tip")
    func lowBattery() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60),
            makeDevice(name: "Sensor", rssi: -65, batteryPercentage: 10),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score == 95)
        #expect(result.issues.contains { $0.message.contains("battery") })
    }

    // MARK: Channel interference

    @Test("Thread channel overlapping WiFi 2.4 GHz → -5 penalty")
    func channelInterference() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55, channel: 11),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60, channel: 11),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score == 95)
        #expect(result.issues.contains { $0.message.contains("WiFi") })
    }

    @Test("Thread channel 15 → no interference penalty")
    func noChannelInterference() {
        let devices = [
            makeDevice(name: "BR", isBorderRouter: true, isRouter: true, rssi: -55, channel: 15),
            makeDevice(name: "BR2", isBorderRouter: true, isRouter: true, rssi: -60, channel: 15),
        ]
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score == 100)
    }

    // MARK: Score floor

    @Test("Score never goes below 0")
    func scoreFloor() {
        let devices = (0..<10).map { makeDevice(name: "D\($0)", rssi: -100) }
        let result = NetworkHealthScore.compute(devices: devices)
        #expect(result.score >= 0)
    }
}
