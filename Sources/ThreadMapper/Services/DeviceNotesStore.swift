import Foundation
import Observation

@Observable
final class DeviceNotesStore {
    static let shared = DeviceNotesStore()

    private(set) var notes: [String: String] = [:]

    @ObservationIgnored
    private let storeURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("device_notes.json")
    }()

    private init() { restore() }

    func note(for deviceID: String) -> String { notes[deviceID] ?? "" }

    func setNote(_ text: String, for deviceID: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notes.removeValue(forKey: deviceID)
        } else {
            notes[deviceID] = trimmed
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private func restore() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        notes = decoded
    }
}
