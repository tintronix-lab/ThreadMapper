import Testing
import Foundation
@testable import ThreadMapper

@Suite("DeviceStatsStore")
@MainActor
struct DeviceStatsStoreTests {

    private func makeStore() -> DeviceStatsStore { .makeTestInstance() }

    // MARK: Basic recording

    @Test("record stores a reading retrievable via stats(for:)")
    func recordStoresReading() {
        let store = makeStore()
        let id = UUID()
        store.record(deviceID: id, rssi: -65)
        let stats = store.stats(for: id)
        #expect(stats != nil)
        #expect(stats?.latestRSSI == -65)
        #expect(stats?.readingCount == 1)
    }

    @Test("stats returns nil for unknown device")
    func statsNilForUnknown() {
        #expect(makeStore().stats(for: UUID()) == nil)
    }

    @Test("multiple readings accumulate min/max/avg correctly")
    func multipleReadings() {
        let store = makeStore()
        let id = UUID()
        store.record(deviceID: id, rssi: -60)
        store.record(deviceID: id, rssi: -70)
        store.record(deviceID: id, rssi: -80)
        let stats = store.stats(for: id)
        #expect(stats?.readingCount == 3)
        #expect(stats?.minRSSI == -80)
        #expect(stats?.maxRSSI == -60)
        #expect(stats?.avgRSSI == -70)
    }

    @Test("latestRSSI reflects the most recently recorded value")
    func latestRSSI() {
        let store = makeStore()
        let id = UUID()
        store.record(deviceID: id, rssi: -60)
        store.record(deviceID: id, rssi: -85)
        #expect(store.stats(for: id)?.latestRSSI == -85)
    }

    // MARK: Clear

    @Test("clear(for:) removes all readings for a single device")
    func clearRemovesDevice() {
        let store = makeStore()
        let id = UUID()
        store.record(deviceID: id, rssi: -65)
        store.clear(for: id)
        #expect(store.stats(for: id) == nil)
    }

    @Test("clear(for:) does not affect other devices")
    func clearDoesNotAffectOthers() {
        let store = makeStore()
        let id1 = UUID(), id2 = UUID()
        store.record(deviceID: id1, rssi: -65)
        store.record(deviceID: id2, rssi: -70)
        store.clear(for: id1)
        #expect(store.stats(for: id1) == nil)
        #expect(store.stats(for: id2) != nil)
    }

    @Test("clearAll removes all devices")
    func clearAllRemovesAll() {
        let store = makeStore()
        let id1 = UUID(), id2 = UUID()
        store.record(deviceID: id1, rssi: -65)
        store.record(deviceID: id2, rssi: -70)
        store.clearAll()
        #expect(store.stats(for: id1) == nil)
        #expect(store.stats(for: id2) == nil)
    }

    // MARK: Device isolation

    @Test("different devices have independent histories")
    func deviceIsolation() {
        let store = makeStore()
        let id1 = UUID(), id2 = UUID()
        store.record(deviceID: id1, rssi: -55)
        store.record(deviceID: id2, rssi: -85)
        #expect(store.stats(for: id1)?.latestRSSI == -55)
        #expect(store.stats(for: id2)?.latestRSSI == -85)
    }

    // MARK: Trend buckets

    @Test("networkTrendBuckets returns buckets in ascending timestamp order")
    func trendBucketsOrdered() {
        let store = makeStore()
        let id = UUID()
        for _ in 0..<10 { store.record(deviceID: id, rssi: -65) }
        let buckets = store.networkTrendBuckets()
        let timestamps = buckets.map(\.timestamp)
        #expect(timestamps == timestamps.sorted())
    }

    @Test("networkTrendBuckets returns empty when no readings exist")
    func trendBucketsEmpty() {
        #expect(makeStore().networkTrendBuckets().isEmpty)
    }

    // MARK: DeviceStats computed properties

    @Test("healthGrade is A for excellent average RSSI")
    func healthGradeA() {
        let store = makeStore()
        let id = UUID()
        for _ in 0..<5 { store.record(deviceID: id, rssi: -48) }
        #expect(store.stats(for: id)?.healthGrade == "A")
    }

    @Test("healthGrade is F for very weak average RSSI")
    func healthGradeF() {
        let store = makeStore()
        let id = UUID()
        for _ in 0..<5 { store.record(deviceID: id, rssi: -92) }
        #expect(store.stats(for: id)?.healthGrade == "F")
    }

    @Test("stabilityPct is 100 when all readings are Good or better")
    func stabilityPct100() {
        let store = makeStore()
        let id = UUID()
        for _ in 0..<5 { store.record(deviceID: id, rssi: -60) }
        #expect(store.stats(for: id)?.stabilityPct == 100)
    }

    @Test("stabilityPct is 0 when all readings are below -65")
    func stabilityPct0() {
        let store = makeStore()
        let id = UUID()
        for _ in 0..<5 { store.record(deviceID: id, rssi: -85) }
        #expect(store.stats(for: id)?.stabilityPct == 0)
    }

    @Test("qualityBuckets fractions sum to approximately 1.0")
    func qualityBucketsFractionSum() {
        let store = makeStore()
        let id = UUID()
        store.record(deviceID: id, rssi: -48)
        store.record(deviceID: id, rssi: -62)
        store.record(deviceID: id, rssi: -75)
        store.record(deviceID: id, rssi: -88)
        let sum = store.stats(for: id)?.qualityBuckets.reduce(0) { $0 + $1.fraction } ?? 0
        #expect(abs(sum - 1.0) < 0.001)
    }
}
