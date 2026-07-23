@testable import ThreadMapper
import XCTest

@MainActor
final class DeviceNotesStoreTests: XCTestCase {

    func testUnknownDeviceReturnsEmptyNote() {
        let store = DeviceNotesStore.makeTestInstance()
        XCTAssertEqual(store.note(for: "abc"), "")
    }

    func testSetNoteTrimsAndStores() {
        let store = DeviceNotesStore.makeTestInstance()
        store.setNote("  needs relocation  ", for: "dev-1")
        XCTAssertEqual(store.note(for: "dev-1"), "needs relocation")
        XCTAssertEqual(store.notes.count, 1)
    }

    func testSetNoteOverwritesExisting() {
        let store = DeviceNotesStore.makeTestInstance()
        store.setNote("first", for: "dev-1")
        store.setNote("second", for: "dev-1")
        XCTAssertEqual(store.note(for: "dev-1"), "second")
        XCTAssertEqual(store.notes.count, 1)
    }

    func testWhitespaceOnlyNoteRemovesEntry() {
        let store = DeviceNotesStore.makeTestInstance()
        store.setNote("something", for: "dev-1")
        store.setNote("   \n ", for: "dev-1")   // clears
        XCTAssertEqual(store.note(for: "dev-1"), "")
        XCTAssertTrue(store.notes.isEmpty)
    }

    func testRestoreReadsPersistedNotes() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_notes.json")
        let data = try JSONEncoder().encode(["dev-1": "kitchen hub", "dev-2": "flaky"])
        try data.write(to: url)

        let store = DeviceNotesStore(storeURL: url)
        XCTAssertEqual(store.note(for: "dev-1"), "kitchen hub")
        XCTAssertEqual(store.note(for: "dev-2"), "flaky")
        XCTAssertEqual(store.notes.count, 2)
    }
}
