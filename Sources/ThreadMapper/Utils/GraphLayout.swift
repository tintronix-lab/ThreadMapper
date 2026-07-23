import Foundation

struct GraphLayout {

    /// Layered top-down layout keyed on `MeshNode.tier`: gateway at top, then
    /// border routers, mesh routers, and leaf devices in rows. Within a row,
    /// nodes are ordered by their parent's x so children sit under their parent —
    /// which is what makes multi-hop paths legible.
    static func hierarchical(nodes: [MeshNode], size: CGSize) -> [UUID: CGPoint] {
        guard !nodes.isEmpty, size.width > 1, size.height > 1 else { return [:] }
        let w = size.width, h = size.height
        let marginX = min(24, w * 0.06)
        let marginTop = min(36, h * 0.08)
        let marginBottom = min(24, h * 0.06)

        let tiers = Set(nodes.map(\.tier)).sorted()
        var tierY: [Int: CGFloat] = [:]
        for (i, t) in tiers.enumerated() {
            let frac = tiers.count == 1 ? 0.5 : CGFloat(i) / CGFloat(tiers.count - 1)
            tierY[t] = marginTop + frac * (h - marginTop - marginBottom)
        }

        var positions: [UUID: CGPoint] = [:]
        for t in tiers {
            let ordered = nodes.filter { $0.tier == t }.sorted { a, b in
                // Primary: room alphabetically — same-room nodes cluster horizontally.
                // Nil room (unassigned) sorts last so it doesn't break zone boundaries.
                let aRoom = a.room ?? "\u{FFFF}"
                let bRoom = b.room ?? "\u{FFFF}"
                if aRoom != bRoom { return aRoom < bRoom }
                // Secondary: parent x-position keeps children under their parent.
                let ax = a.parentID.flatMap { positions[$0]?.x } ?? w / 2
                let bx = b.parentID.flatMap { positions[$0]?.x } ?? w / 2
                if ax != bx { return ax < bx }
                return a.name < b.name
            }
            let n = ordered.count
            let y = tierY[t] ?? h / 2
            for (i, node) in ordered.enumerated() {
                let x: CGFloat = n == 1
                    ? w / 2
                    : marginX + CGFloat(i) / CGFloat(n - 1) * (w - 2 * marginX)
                positions[node.id] = CGPoint(x: x, y: y)
            }
        }
        return positions
    }

    /// Lays nodes out as room cards — each room gets an explicit, non-overlapping
    /// rectangle sized to hold all its devices. The gateway sits above the grid.
    /// Returns node positions AND the bounding CGRect for each room (both in
    /// layout/canvas space so the Canvas can transform them with pan + scale).
    static func byRoom(nodes: [MeshNode], size: CGSize) -> ([UUID: CGPoint], [String: CGRect]) {
        guard !nodes.isEmpty, size.width > 80, size.height > 80 else { return ([:], [:]) }
        let w = size.width, h = size.height

        let outerPad: CGFloat = 14   // canvas edge margin
        let cellGap: CGFloat = 10   // gap between room cards
        let headerH: CGFloat = 24   // room-name label bar height
        let innerPad: CGFloat = 10   // padding inside each card around the node grid

        var positions: [UUID: CGPoint] = [:]
        var roomBounds: [String: CGRect] = [:]

        // Gateway floats at top-centre, above the room grid
        let gatewayNodes = nodes.filter { $0.kind == .gateway }
        let gwAreaH: CGFloat = gatewayNodes.isEmpty ? 0 : 50
        for gw in gatewayNodes {
            positions[gw.id] = CGPoint(x: w / 2, y: outerPad + gwAreaH / 2)
        }

        // Group non-gateway nodes by room (nil room → "Unassigned", sorted last)
        let nonGateway = nodes.filter { $0.kind != .gateway }
        let grouped = Dictionary(grouping: nonGateway) { $0.room ?? "Unassigned" }
        let rooms = grouped.sorted { a, b in
            switch (a.key == "Unassigned", b.key == "Unassigned") {
            case (true, _): return false
            case (_, true): return true
            default:        return a.key < b.key
            }
        }

        let roomCount = rooms.count
        guard roomCount > 0 else { return (positions, roomBounds) }

        // Choose column count — never more than 3
        let cols     = roomCount == 1 ? 1 : roomCount <= 4 ? 2 : 3
        let gridRows = Int(ceil(Double(roomCount) / Double(cols)))

        let gridY0 = outerPad + gwAreaH + (gwAreaH > 0 ? cellGap : 0)
        let gridW  = w - outerPad * 2
        let gridH  = h - gridY0 - outerPad
        let cellW  = (gridW - cellGap * CGFloat(cols     - 1)) / CGFloat(cols)
        let cellH  = (gridH - cellGap * CGFloat(gridRows - 1)) / CGFloat(gridRows)

        for (idx, (room, roomNodes)) in rooms.enumerated() {
            let col   = idx % cols
            let row   = idx / cols
            let cellX = outerPad + CGFloat(col) * (cellW + cellGap)
            let cellY = gridY0   + CGFloat(row) * (cellH + cellGap)

            roomBounds[room] = CGRect(x: cellX, y: cellY, width: cellW, height: cellH)

            // Sort within room: border routers first, then relays, then end devices
            let sorted = roomNodes.sorted { roomRoleOrder($0.kind) < roomRoleOrder($1.kind) }
            let count  = sorted.count

            let availW = cellW - innerPad * 2
            let availH = cellH - headerH - innerPad * 2

            // Expand column count so all nodes fit in ≤ desiredMaxRows rows
            let idealSpacing: CGFloat = 34
            let rawCols        = max(1, Int(availW / idealSpacing))
            let desiredMaxRows = max(1, Int(availH / idealSpacing))
            let nodeColumns    = min(count,
                                    max(rawCols, Int(ceil(Double(count) / Double(desiredMaxRows)))))
            let spacingX = availW / CGFloat(nodeColumns)
            let nodeRows = Int(ceil(Double(count) / Double(nodeColumns)))
            let spacingY = nodeRows > 1 ? availH / CGFloat(nodeRows) : availH

            for (i, node) in sorted.enumerated() {
                let nr = i / nodeColumns
                let nc = i % nodeColumns
                // Centre the last (possibly partial) row
                let nodesInRow = (nr == nodeRows - 1) ? count - nr * nodeColumns : nodeColumns
                let rowInset   = (availW - CGFloat(nodesInRow) * spacingX) / 2
                let x = cellX + innerPad + rowInset + CGFloat(nc) * spacingX + spacingX / 2
                let y = cellY + headerH  + innerPad + CGFloat(nr) * spacingY  + spacingY  / 2
                positions[node.id] = CGPoint(x: x, y: y)
            }
        }

        return (positions, roomBounds)
    }

    private static func roomRoleOrder(_ kind: MeshNodeKind) -> Int {
        switch kind {
        case .gateway: return 0; case .borderRouter: return 1
        case .router:  return 2; case .endDevice:    return 3
        }
    }

}
