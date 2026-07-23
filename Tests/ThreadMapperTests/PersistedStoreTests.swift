@testable import ThreadMapper
import XCTest

@MainActor
final class PersistedStoreTests: XCTestCase {

    private struct Sample: Codable, Equatable {
        let name: String
        let value: Int
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_persisted.json")
    }

    func testLegacyBarePayloadStillLoads() throws {
        // Pre-envelope files are bare JSON — they must load unchanged
        // on first launch after the update.
        let url = tempURL()
        let legacy = [Sample(name: "a", value: 1), Sample(name: "b", value: 2)]
        try JSONEncoder().encode(legacy).write(to: url)

        let loaded = PersistedStore.load([Sample].self, from: url)
        XCTAssertEqual(loaded, legacy)
    }

    func testEnvelopedRoundTrip() async {
        let url = tempURL()
        let value = [Sample(name: "x", value: 42)]
        PersistedStore.save(value, to: url)
        await PersistedStore.flush()

        XCTAssertEqual(PersistedStore.load([Sample].self, from: url), value)

        // The on-disk form is the versioned envelope, not a bare payload.
        let data = try? Data(contentsOf: url)
        let envelope = try? JSONDecoder().decode(PersistenceEnvelope<[Sample]>.self, from: XCTUnwrap(data))
        XCTAssertEqual(envelope?.schemaVersion, PersistedStore.currentSchemaVersion)
        XCTAssertEqual(envelope?.payload, value)
    }

    func testUndecodableFileIsQuarantinedNotDeleted() throws {
        let url = tempURL()
        try Data("not json at all {{{".utf8).write(to: url)

        XCTAssertNil(PersistedStore.load([Sample].self, from: url))

        let corruptURL = url.appendingPathExtension("corrupt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path),
                      "corrupt file should be preserved for recovery")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "original path should be clear so the store can rebuild")
    }

    func testMissingFileReturnsNil() {
        XCTAssertNil(PersistedStore.load([Sample].self, from: tempURL()))
    }

    func testRapidSavesLandInCallOrder() async {
        let url = tempURL()
        for i in 1...5 {
            PersistedStore.save([Sample(name: "gen", value: i)], to: url)
        }
        await PersistedStore.flush()
        XCTAssertEqual(PersistedStore.load([Sample].self, from: url)?.first?.value, 5)
    }
}
