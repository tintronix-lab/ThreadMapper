@testable import ThreadMapper
import XCTest

@MainActor
final class AchievementStoreTests: XCTestCase {

    private func unlocked(_ store: AchievementStore, _ id: String) -> Bool {
        store.achievements.first { $0.id == id }?.isUnlocked ?? false
    }

    func testUnlockMarksAchievementAndFlagsRecent() {
        let store = AchievementStore.makeTestInstance()
        XCTAssertEqual(store.unlockedCount, 0)
        store.unlock("firstGradeA")
        XCTAssertTrue(unlocked(store, "firstGradeA"))
        XCTAssertEqual(store.recentlyUnlocked?.id, "firstGradeA")
        XCTAssertEqual(store.unlockedCount, 1)
    }

    func testUnlockIsIdempotent() {
        let store = AchievementStore.makeTestInstance()
        store.unlock("streak3")
        let firstDate = store.achievements.first { $0.id == "streak3" }?.unlockedAt
        store.clearRecentlyUnlocked()
        store.unlock("streak3")   // already unlocked
        XCTAssertNil(store.recentlyUnlocked)   // not re-flagged
        XCTAssertEqual(store.achievements.first { $0.id == "streak3" }?.unlockedAt, firstDate)
        XCTAssertEqual(store.unlockedCount, 1)
    }

    func testUnknownIdIsNoOp() {
        let store = AchievementStore.makeTestInstance()
        store.unlock("does-not-exist")
        XCTAssertEqual(store.unlockedCount, 0)
        XCTAssertNil(store.recentlyUnlocked)
    }

    func testRestoreMergesUnlocksOntoFullCatalog() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_ach.json")
        let store = AchievementStore(storeURL: url)
        store.unlock("firstSurvey")
        store.unlock("resilienceA")
        await PersistedStore.flush()   // writes land on a background actor

        // A fresh store over the same file restores those unlocks; others stay
        // locked, and the full catalog is preserved (merge doesn't drop entries).
        let reloaded = AchievementStore(storeURL: url)
        XCTAssertTrue(unlocked(reloaded, "firstSurvey"))
        XCTAssertTrue(unlocked(reloaded, "resilienceA"))
        XCTAssertFalse(unlocked(reloaded, "streak7"))
        XCTAssertEqual(reloaded.unlockedCount, 2)
        XCTAssertEqual(reloaded.achievements.count, AchievementStore.catalog.count)
    }
}
