import SwiftUI

// MARK: - Layout & Transform
extension MeshGraphView {

    private func layoutMembershipHash(nodes: [MeshNode], size: CGSize) -> Int {
        var hasher = Hasher()
        for node in nodes.sorted(by: { $0.id < $1.id }) {
            hasher.combine(node.id)
            hasher.combine(node.room)
            hasher.combine(node.kind.rawValue)
        }
        hasher.combine(Int(size.width))
        hasher.combine(Int(size.height))
        return hasher.finalize()
    }

    func applyLayout(size: CGSize) {
        guard !nodes.isEmpty, size.width > 80, size.height > 80 else { return }
        let newHash = layoutMembershipHash(nodes: nodes, size: size)
        guard newHash != layoutHash else { return }
        layoutHash = newHash
        let (newLayout, newRoomBounds) = GraphLayout.byRoom(nodes: nodes, size: size)
        layout     = newLayout
        roomBounds = newRoomBounds
        selectedNodeID = nil
        fitToView(size: size)
    }

    func fitToView(size: CGSize) {
        guard !layout.isEmpty,
              let minX = layout.values.map(\.x).min(),
              let maxX = layout.values.map(\.x).max(),
              let minY = layout.values.map(\.y).min(),
              let maxY = layout.values.map(\.y).max() else { return }

        let graphWidth  = max(maxX - minX, 1)
        let graphHeight = max(maxY - minY, 1)
        let padding: CGFloat = 36
        let scaleX = (size.width  - padding * 2) / graphWidth
        let scaleY = (size.height - padding * 2) / graphHeight
        // Cap at 1.5 so small networks don't over-zoom; floor at 0.35 so large ones still fit.
        let newScale = max(0.35, min(scaleX, scaleY, 1.5))

        scale     = newScale
        baseScale = newScale

        let cx = size.width / 2, cy = size.height / 2
        let gcx = (minX + maxX) / 2, gcy = (minY + maxY) / 2
        pan = CGSize(
            width: -(gcx - cx) * newScale,
            height: -(gcy - cy) * newScale
        )
        lastPan = pan
    }

    func nodeRadius(_ kind: MeshNodeKind) -> CGFloat {
        switch kind {
        case .gateway:      return 15
        case .borderRouter: return 13
        case .router:       return 11
        case .endDevice:    return 9
        }
    }

    /// Layout-space → screen/canvas space.
    func screenPos(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let cx = size.width / 2, cy = size.height / 2
        return CGPoint(
            x: cx + (p.x - cx) * scale + pan.width,
            y: cy + (p.y - cy) * scale + pan.height
        )
    }

    /// Screen/canvas space → layout space (inverse of screenPos).
    private func toLayout(_ screen: CGPoint, in size: CGSize) -> CGPoint {
        let cx = size.width / 2, cy = size.height / 2
        return CGPoint(
            x: cx + (screen.x - pan.width - cx) / scale,
            y: cy + (screen.y - pan.height - cy) / scale
        )
    }

    func handleTap(at location: CGPoint, in size: CGSize) {
        let lp = toLayout(location, in: size)
        // Hit radius in layout space: generous contact area so small nodes are tappable.
        let extraTap: CGFloat = max(12, 28 / scale)
        if let hit = nodes.first(where: { node in
            guard let pos = layout[node.id] else { return false }
            let dx = lp.x - pos.x, dy = lp.y - pos.y
            return sqrt(dx * dx + dy * dy) <= nodeRadius(node.kind) + extraTap
        }) {
            withAnimation(.easeInOut(duration: 0.15)) { selectedNodeID = hit.id }
            UISelectionFeedbackGenerator().selectionChanged()
            onSelectNode(hit)
            // onSelectDevice is not called here — use the HUD "Details →" button instead,
            // so tapping a node shows info first without immediately navigating away.
        } else {
            withAnimation(.easeInOut(duration: 0.15)) { selectedNodeID = nil }
        }
    }
}
