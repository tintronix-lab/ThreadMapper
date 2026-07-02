import Foundation

struct WeakDevice: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
