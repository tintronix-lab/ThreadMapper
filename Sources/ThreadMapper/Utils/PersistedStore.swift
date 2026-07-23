import Foundation
import os

private let log = Logger(subsystem: "com.tintronixlab.ThreadMapper", category: "PersistedStore")

/// Wraps a store's payload with a schema version so future model changes can
/// migrate instead of silently discarding the user's history.
struct PersistenceEnvelope<Payload: Codable>: Codable {
    let schemaVersion: Int
    let payload: Payload
}

/// Shared load/save path for the JSON-file-backed stores.
///
/// Load order: enveloped decode → legacy bare-payload decode (pre-envelope
/// files round-trip unchanged on first launch after update) → quarantine.
/// A file that decodes as neither is renamed to "<name>.corrupt" — never
/// deleted — so data survives for later recovery or bug reports.
enum PersistedStore {
    static let currentSchemaVersion = 1

    static func load<T: Codable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(PersistenceEnvelope<T>.self, from: data) {
            return envelope.payload
        }
        if let legacy = try? decoder.decode(T.self, from: data) {
            return legacy
        }
        quarantine(url)
        return nil
    }

    /// Chains writes so rapid saves of the same file land in call order;
    /// the stores are all @MainActor, so the chain head lives there too.
    @MainActor private static var chain: Task<Void, Never>?

    /// Encodes on the main actor (payloads are small) and hands the
    /// immutable Data to the background writer, so file I/O never blocks
    /// the main thread.
    @MainActor
    static func save<T: Codable>(_ value: T, to url: URL) {
        let envelope = PersistenceEnvelope(schemaVersion: currentSchemaVersion, payload: value)
        guard let data = try? JSONEncoder().encode(envelope) else {
            log.error("Failed to encode \(String(describing: T.self)) for \(url.lastPathComponent)")
            return
        }
        let previous = chain
        chain = Task {
            await previous?.value
            await PersistenceWriter.shared.write(data, to: url)
        }
    }

    /// Awaiting this guarantees every previously enqueued save has landed
    /// on disk. Used by tests before asserting on-disk state.
    @MainActor
    static func flush() async {
        await chain?.value
    }

    private static func quarantine(_ url: URL) {
        let corruptURL = url.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: corruptURL)
        do {
            try FileManager.default.moveItem(at: url, to: corruptURL)
            log.error("Quarantined undecodable store file to \(corruptURL.lastPathComponent)")
        } catch {
            log.error("Failed to quarantine \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}

/// Serializes all store file writes on a background actor, preserving
/// per-file ordering (actor mailbox order) without main-thread I/O.
actor PersistenceWriter {
    static let shared = PersistenceWriter()

    func write(_ data: Data, to url: URL,
               options: Data.WritingOptions = [.atomic]) {
        do {
            try data.write(to: url, options: options)
        } catch {
            log.error("Failed to write \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
