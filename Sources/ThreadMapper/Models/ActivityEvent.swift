import SwiftUI

struct ActivityEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let kind: Kind
    let deviceID: UUID?
    let deviceName: String?
    let room: String?
    let detail: String

    enum Kind: String, Codable {
        case deviceOffline
        case deviceOnline
        case borderRouterOffline
        case healthDegraded
        case healthImproved
        case topologyJoined
        case topologyLeft

        var icon: String {
            switch self {
            case .deviceOffline:       return "network.slash"
            case .deviceOnline:        return "checkmark.circle.fill"
            case .borderRouterOffline: return "exclamationmark.octagon.fill"
            case .healthDegraded:      return "arrow.down.circle.fill"
            case .healthImproved:      return "arrow.up.circle.fill"
            case .topologyJoined:      return "plus.circle.fill"
            case .topologyLeft:        return "minus.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .deviceOffline, .borderRouterOffline: return .red
            case .healthDegraded:                      return .orange
            case .deviceOnline, .healthImproved, .topologyJoined: return .green
            case .topologyLeft:                        return .secondary
            }
        }

        var label: String {
            switch self {
            case .deviceOffline:       return "Device Offline"
            case .deviceOnline:        return "Device Online"
            case .borderRouterOffline: return "Border Router Offline"
            case .healthDegraded:      return "Health Degraded"
            case .healthImproved:      return "Health Improved"
            case .topologyJoined:      return "Device Joined"
            case .topologyLeft:        return "Device Left"
            }
        }

        var isCritical: Bool {
            self == .deviceOffline || self == .borderRouterOffline
        }
    }
}
