import Foundation
import Observation

@MainActor
@Observable
final class DeviceNotesStore {
    static let shared = DeviceNotesStore()

    private(set) var notes: [String: String] = [:]

    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var persistTask: Task<Void, Never>?

    /// `storeURL` is injectable so tests can use a throwaway file; the shared
    /// instance persists to Documents.
    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("device_notes.json")
        restore()
    }

    /// Creates a fresh isolated store backed by a temp file. For tests only.
    static func makeTestInstance() -> DeviceNotesStore {
        DeviceNotesStore(storeURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)_device_notes.json"))
    }

    func note(for deviceID: String) -> String { notes[deviceID] ?? "" }

    func setNote(_ text: String, for deviceID: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes.removeValue(forKey: deviceID)
        } else {
            notes[deviceID] = trimmed
        }
        // Debounced — setNote fires on every keystroke of the notes field.
        schedulePersist()
    }

    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: storeURL, options: [.atomic, .completeFileProtection])
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        notes = decoded
    }
}
