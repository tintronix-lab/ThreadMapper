import Foundation

struct ResilienceSimulator {

    // MARK: - Impact model

    struct Impact: Identifiable {
        var id: UUID { removedNode.id }

        let removedNode: MeshNode
        let affectedNodes: [MeshNode]
        let isLastBorderRouter: Bool
        let totalBorderRouters: Int
        let severity: Severity

        enum Severity: Comparable {
            case none, minor, major, critical

            var label: LocalizedStringResource {
                switch self {
                case .none:     return "Safe"
                case .minor:    return "Minor impact"
                case .major:    return "Major impact"
                case .critical: return "Critical"
                }
            }

            var icon: String {
                switch self {
                case .none:     return "checkmark.shield.fill"
                case .minor:    return "exclamationmark.shield"
                case .major:    return "exclamationmark.shield.fill"
                case .critical: return "xmark.shield.fill"
                }
            }
        }

        var isSinglePointOfFailure: Bool { severity == .critical }

        var affectedDeviceCount: Int {
            affectedNodes.filter { $0.kind == .endDevice }.count
        }
        var affectedRouterCount: Int {
            affectedNodes.filter { $0.kind == .router }.count
        }
        var totalAffectedCount: Int { affectedNodes.count }

        var recommendation: LocalizedStringResource {
            switch severity {
            case .critical:
                return "Add a second border router before removing or moving this device. Without it, all Thread devices will lose internet connectivity."
            case .major:
                if removedNode.kind == .borderRouter {
                    return "At least one other border router is present, but ^[\(totalAffectedCount) downstream device](inflect: true) will lose their mesh path. Reconnect them to another router first."
                }
                return "Move the ^[\(affectedDeviceCount) device](inflect: true) in this subtree closer to a border router or another relay before removing this node."
            case .minor:
                return "Impact is small — ^[\(totalAffectedCount) device](inflect: true) will need to find a new parent node."
            case .none:
                return "This device has no downstream dependents. It can be safely removed without affecting other devices."
            }
        }
    }

    // MARK: - Core simulation

    static func simulate(removing target: MeshNode, allNodes: [MeshNode]) -> Impact {
        var childrenOf: [UUID: [MeshNode]] = [:]
        for node in allNodes {
            if let pid = node.parentID {
                childrenOf[pid, default: []].append(node)
            }
        }

        var affected: [MeshNode] = []
        var queue = childrenOf[target.id] ?? []
        var visited: Set<UUID> = []

        while !queue.isEmpty {
            let node = queue.removeFirst()
            guard !visited.contains(node.id) else { continue }
            visited.insert(node.id)
            affected.append(node)
            for child in childrenOf[node.id] ?? [] where !visited.contains(child.id) {
                queue.append(child)
            }
        }

        let borderRouterCount = allNodes.filter { $0.kind == .borderRouter }.count
        let isLastBR = target.kind == .borderRouter && borderRouterCount == 1

        let severity: Impact.Severity
        if isLastBR {
            severity = .critical
        } else if target.kind == .borderRouter && !affected.isEmpty {
            severity = .major
        } else if affected.count >= 3 {
            severity = .major
        } else if affected.isEmpty {
            severity = .none
        } else {
            severity = .minor
        }

        return Impact(
            removedNode: target,
            affectedNodes: affected,
            isLastBorderRouter: isLastBR,
            totalBorderRouters: borderRouterCount,
            severity: severity
        )
    }

    // MARK: - Bulk analysis

    static func analyzeAll(nodes: [MeshNode]) -> [UUID: Impact] {
        var result: [UUID: Impact] = [:]
        for node in nodes where node.kind == .borderRouter || node.kind == .router {
            result[node.id] = simulate(removing: node, allNodes: nodes)
        }
        return result
    }
}
