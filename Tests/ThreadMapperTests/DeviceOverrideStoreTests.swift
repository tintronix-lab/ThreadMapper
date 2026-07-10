import XCTest
@testable import ThreadMapper

final class DeviceOverrideStoreTests: XCTestCase {

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    func testToggleNonThread() {
        let store = DeviceOverrideStore(defaults: isolatedDefaults())
        let id = UUID()
        XCTAssertFalse(store.isNonThread(id))
        store.setNonThread(id, true)
        XCTAssertTrue(store.isNonThread(id))
        store.setNonThread(id, false)
        XCTAssertFalse(store.isNonThread(id))
    }

    func testPersistenceRoundTrip() {
        let defaults = isolatedDefaults()
        let id = UUID()
        DeviceOverrideStore(defaults: defaults).setNonThread(id, true)
        // A fresh store reading the same defaults sees the persisted exclusion.
        XCTAssertTrue(DeviceOverrideStore(defaults: defaults).isNonThread(id))
    }
}
