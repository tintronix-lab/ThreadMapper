import SwiftUI

extension DeviceDetailView {
    // MARK: - Thread Neighbor Table (real OTBR data when available)

    @ViewBuilder
    var threadNeighborSection: some View {
        if let diag = meshViewModel.latestDiagnostics[device.id], !diag.neighbors.isEmpty {
            Section {
                ForEach(diag.neighbors.indices, id: \.self) { i in
                    let neighbor = diag.neighbors[i]
                    HStack(spacing: 12) {
                        Image(systemName: neighbor.isChild ? "arrow.down.circle" : "arrow.up.arrow.down.circle")
                            .foregroundStyle(neighbor.isChild ? .blue : .purple)
                            .imageScale(.small)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "0x%04X", neighbor.rloc16))
                                .font(.caption.monospaced())
                            Text(neighbor.isChild ? "Child device" : "Router neighbor")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Link quality indicator
                        VStack(alignment: .trailing, spacing: 2) {
                            if let rssi = neighbor.averageRSSI {
                                Text("\(rssi) dBm")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(rssi.rssiColor)
                            }
                            if let margin = neighbor.linkMarginDB {
                                Text("\(margin) dB margin")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                HStack {
                    Text("Live Thread Neighbors")
                    Spacer()
                    Label("OTBR", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("Real neighbor data from your OpenThread Border Router. RLOC16 is each node's Thread routing address. Children route through this device; router neighbors are peers on the mesh backbone.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Mesh Path



    var topologyFingerprint: Int {
        var hasher = Hasher()
        for d in meshViewModel.devices {
            hasher.combine(d.id)
            hasher.combine(d.name)
            hasher.combine(d.isBorderRouter)
            hasher.combine(d.isRouter)
            hasher.combine(d.rssi)
            hasher.combine(d.room)
            hasher.combine(d.channel)
        }
        return hasher.finalize()
    }

    func computeMeshPath() -> [HopEntry] {
        let (nodes, _) = MeshTopologyBuilder.buildGraph(from: meshViewModel.devices)
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        var path: [MeshNode] = []
        var current: UUID? = device.id
        var visited = Set<UUID>()

        while let id = current, !visited.contains(id), path.count < 12 {
            visited.insert(id)
            if let node = nodeByID[id] {
                path.append(node)
                current = node.parentID
            } else {
                break
            }
        }
        // Include the gateway if the last node's parentID resolves
        if let lastParentID = path.last?.parentID, let gateway = nodeByID[lastParentID] {
            path.append(gateway)
        }

        return path.reversed().map {
            HopEntry(name: $0.name, kind: $0.kind, isCurrentDevice: $0.id == device.id)
        }
    }

    @ViewBuilder
    var meshPathSection: some View {
        let path = meshPath   // cached @State, refreshed by .task(id: topologyFingerprint)
        if path.count >= 2 {
            Section {
                // Hop count row (long-press to explain with AI)
                let hopCount = path.count - 1  // gateway excluded from "hops"
                HStack(spacing: 10) {
                    Image(systemName: hopCount <= 2 ? "checkmark.circle.fill" : hopCount == 3 ? "exclamationmark.circle" : "exclamationmark.triangle.fill")
                        .foregroundStyle(hopCount <= 2 ? .green : hopCount == 3 ? .orange : .red)
                    Text("^[\(hopCount) hop](inflect: true) from border router")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onLongPressGesture {
                    let quality = hopCount <= 2 ? "good" : hopCount == 3 ? "acceptable" : "high — may cause delays"
                    let context = "Device: \(device.name)\(device.room.map { " in \($0)" } ?? ""). Hop count: \(hopCount) hop\(hopCount == 1 ? "" : "s") to the border router (internet hub). Typical quality: 1–2 hops is ideal, 3 is acceptable, 4+ is \(quality). Each hop adds latency and a potential point of failure."
                    setExplainContext(
                        metricName: "Hop Count",
                        displayValue: "^[\(hopCount) hop](inflect: true)",
                        aiPromptContext: context
                    )
                }

                // Visual hop chain
                ForEach(path.indices, id: \.self) { i in
                    let hop = path[i]
                    VStack(alignment: .leading, spacing: 0) {
                        if i > 0 {
                            HStack {
                                Spacer().frame(width: 10)
                                Image(systemName: "chevron.up")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary.opacity(0.5))
                                Spacer()
                            }
                        }
                        HStack(spacing: 10) {
                            Image(systemName: nodeKindIcon(hop.kind))
                                .foregroundStyle(hop.isCurrentDevice ? Color.accentColor : hop.kind == .gateway ? .blue : .secondary)
                                .frame(width: 22)
                            Text(hop.name)
                                .font(hop.isCurrentDevice ? .subheadline.weight(.semibold) : .subheadline)
                                .foregroundStyle(hop.isCurrentDevice ? .primary : .secondary)
                            Spacer()
                            Text(hop.kind.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } header: {
                Text("Mesh Path to Internet")
            } footer: {
                Text("Inferred routing path from this device to your border router. Fewer hops means lower latency and better reliability.")
                    .font(.caption)
            }
        }
    }

    func nodeKindIcon(_ kind: MeshNodeKind) -> String {
        switch kind {
        case .gateway:      return "globe"
        case .borderRouter: return "antenna.radiowaves.left.and.right"
        case .router:       return "point.3.connected.trianglepath.dotted"
        case .endDevice:    return "circle.dotted"
        }
    }
}
