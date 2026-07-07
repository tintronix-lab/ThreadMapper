import Testing
import Foundation
@testable import ThreadMapper

@Suite("WidgetSnapshot")
struct WidgetSnapshotTests {

    private func makeSnapshot(
        grade: String = "A",
        score: Int = 95,
        summary: String = "OK",
        deviceCount: Int = 8,
        offlineCount: Int = 0,
        weakCount: Int = 0,
        offlineDeviceNames: [String] = [],
        rooms: [WidgetSnapshot.RoomSnapshot] = []
    ) -> WidgetSnapshot {
        WidgetSnapshot(grade: grade, score: score, summary: summary, deviceCount: deviceCount,
                       offlineCount: offlineCount, weakCount: weakCount,
                       offlineDeviceNames: offlineDeviceNames,
                       updatedAt: Date(), rooms: rooms)
    }

    // MARK: Codable round-trip

    @Test("WidgetSnapshot encodes and decodes via JSON")
    func codableRoundTrip() throws {
        let snapshot = makeSnapshot(grade: "B", score: 80)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.grade == "B")
        #expect(decoded.score == 80)
    }

    @Test("RoomSnapshot encodes and decodes via JSON")
    func roomSnapshotRoundTrip() throws {
        let room = WidgetSnapshot.RoomSnapshot(name: "Kitchen", deviceCount: 3,
                                               offlineCount: 1, weakCount: 1)
        let snapshot = makeSnapshot(rooms: [room])
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.rooms.count == 1)
        #expect(decoded.rooms[0].name == "Kitchen")
        #expect(decoded.rooms[0].offlineCount == 1)
    }

    // MARK: contentHash

    @Test("contentHash is stable for identical snapshots")
    func contentHashStable() {
        let s1 = makeSnapshot(grade: "A", score: 95)
        let s2 = makeSnapshot(grade: "A", score: 95)
        #expect(s1.contentHash == s2.contentHash)
    }

    @Test("contentHash changes when grade changes")
    func contentHashChangesOnGrade() {
        let s1 = makeSnapshot(grade: "A", score: 95)
        let s2 = makeSnapshot(grade: "B", score: 95)
        #expect(s1.contentHash != s2.contentHash)
    }

    @Test("contentHash changes when score changes")
    func contentHashChangesOnScore() {
        let s1 = makeSnapshot(grade: "A", score: 95)
        let s2 = makeSnapshot(grade: "A", score: 80)
        #expect(s1.contentHash != s2.contentHash)
    }

    @Test("contentHash changes when offlineCount changes")
    func contentHashChangesOnOfflineCount() {
        let s1 = makeSnapshot(offlineCount: 0)
        let s2 = makeSnapshot(offlineCount: 1)
        #expect(s1.contentHash != s2.contentHash)
    }

    @Test("contentHash changes when deviceCount changes")
    func contentHashChangesOnDeviceCount() {
        let s1 = makeSnapshot(deviceCount: 8)
        let s2 = makeSnapshot(deviceCount: 10)
        #expect(s1.contentHash != s2.contentHash)
    }

    @Test("contentHash is unchanged when only updatedAt changes")
    func contentHashIgnoresUpdatedAt() {
        let base = WidgetSnapshot(grade: "A", score: 95, summary: "OK", deviceCount: 8,
                                  offlineCount: 0, weakCount: 0, offlineDeviceNames: [],
                                  updatedAt: Date(timeIntervalSinceReferenceDate: 0), rooms: [])
        let later = WidgetSnapshot(grade: "A", score: 95, summary: "OK", deviceCount: 8,
                                   offlineCount: 0, weakCount: 0, offlineDeviceNames: [],
                                   updatedAt: Date(timeIntervalSinceReferenceDate: 3600), rooms: [])
        #expect(base.contentHash == later.contentHash)
    }

    @Test("contentHash changes when room snapshot list changes")
    func contentHashChangesOnRooms() {
        let r1 = WidgetSnapshot.RoomSnapshot(name: "Kitchen", deviceCount: 2, offlineCount: 0, weakCount: 0)
        let r2 = WidgetSnapshot.RoomSnapshot(name: "Bedroom", deviceCount: 3, offlineCount: 1, weakCount: 0)
        let s1 = makeSnapshot(rooms: [r1])
        let s2 = makeSnapshot(rooms: [r1, r2])
        #expect(s1.contentHash != s2.contentHash)
    }

    // MARK: Placeholder

    @Test("placeholder has zero device count and grade dash")
    func placeholder() {
        let p = WidgetSnapshot.placeholder
        #expect(p.deviceCount == 0)
        #expect(p.offlineCount == 0)
        #expect(p.grade == "—")
    }
}
