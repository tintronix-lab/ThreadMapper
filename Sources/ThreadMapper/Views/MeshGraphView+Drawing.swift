import SwiftUI

// MARK: - Drawing
extension MeshGraphView {

    func drawRoomZones(ctx: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0, !roomBounds.isEmpty else { return }

        // Pre-count non-gateway devices per room once instead of O(n) per room per frame.
        var roomDeviceCount: [String: Int] = [:]
        for node in nodes where node.kind != .gateway {
            let key = node.room ?? "Unassigned"
            roomDeviceCount[key, default: 0] += 1
        }

        for (room, cellRect) in roomBounds {
            // Transform layout-space room rectangle into screen space.
            let tl = screenPos(cellRect.origin, in: size)
            let br = screenPos(CGPoint(x: cellRect.maxX, y: cellRect.maxY), in: size)
            let screenRect = CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
            guard screenRect.width > 4, screenRect.height > 4 else { continue }

            let zoneColor = roomZoneColor(for: room)
            let path = Path(roundedRect: screenRect, cornerRadius: 12, style: .continuous)

            ctx.fill(path, with: .color(zoneColor.opacity(0.10)))
            ctx.stroke(path, with: .color(zoneColor.opacity(0.50)), lineWidth: 1)

            let deviceCount = roomDeviceCount[room] ?? 0
            let label = ctx.resolve(
                (Text("\(room)  ·  ") + Text("^[\(deviceCount) device](inflect: true)"))
                    .font(.system(size: canvasRoomLabel, weight: .semibold))
                    .foregroundStyle(zoneColor)
            )
            ctx.draw(label, at: CGPoint(x: screenRect.midX, y: screenRect.minY + 13))
        }
    }

    private func roomZoneColor(for room: String) -> Color {
        let bucket = abs(room.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % 12
        let hue = Double(bucket) / 12.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.72)
    }

    func drawLinks(ctx: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let highlight = highlightedNodeIDs
        let hasSelection = !highlight.isEmpty
        let nodeMap = nodesByID

        for link in links {
            guard let srcLayout = layout[link.sourceID],
                  let dstLayout = layout[link.targetID] else { continue }
            let sourcePos = screenPos(srcLayout, in: size)
            let targetPos = screenPos(dstLayout, in: size)
            let onPath = highlight.contains(link.sourceID) && highlight.contains(link.targetID)

            // Cross-room mesh links arc as quadratic beziers to avoid piercing room cards.
            // Backbone links (gateway → border router) stay straight — they already travel
            // above the card grid and straight lines read clearly.
            let srcRoom = nodeMap[link.sourceID]?.room
            let dstRoom = nodeMap[link.targetID]?.room
            let isCrossRoom = link.kind == .mesh && srcRoom != dstRoom

            var path = Path()
            if isCrossRoom {
                let mid = CGPoint(x: (sourcePos.x + targetPos.x) / 2,
                                  y: (sourcePos.y + targetPos.y) / 2)
                let dx = targetPos.x - sourcePos.x
                let dy = targetPos.y - sourcePos.y
                let len = max(sqrt(dx * dx + dy * dy), 1)
                // Arc height: 35% of chord length, capped so very long links stay readable.
                let arcHeight = min(len * 0.35, 72)
                // Perpendicular unit vector (90° CCW rotation of the chord direction).
                let perpX = -dy / len
                let perpY =  dx / len
                // Choose the side that faces away from the canvas centre so the curve
                // arcs outward and doesn't cut further through adjacent room cards.
                let cx = size.width / 2, cy = size.height / 2
                let dot = perpX * (mid.x - cx) + perpY * (mid.y - cy)
                let sign: CGFloat = dot >= 0 ? 1 : -1
                let ctrl = CGPoint(x: mid.x + perpX * arcHeight * sign,
                                   y: mid.y + perpY * arcHeight * sign)
                path.move(to: sourcePos)
                path.addQuadCurve(to: targetPos, control: ctrl)
            } else {
                path.move(to: sourcePos)
                path.addLine(to: targetPos)
            }

            let base = link.kind == .backbone ? Color.secondary : linkColor(for: link)
            let linkStroke = hasSelection ? (onPath ? Color.accentColor : base.opacity(0.18)) : base
            let width = onPath ? 2.0 : max(0.8, CGFloat(link.linkQuality) * 0.5)
            let dash: [CGFloat] = link.kind == .backbone ? [3, 2] : []

            ctx.stroke(path, with: .color(linkStroke),
                       style: .init(lineWidth: width, lineCap: .round, dash: dash))
        }
    }

    func drawNodes(ctx: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let highlight = highlightedNodeIDs
        let hasSelection = !highlight.isEmpty
        let devMap = devicesByID
        for node in nodes {
            guard let layoutP = layout[node.id] else { continue }
            let pos = screenPos(layoutP, in: size)
            let device = node.deviceID.flatMap { devMap[$0] }
            let isSelected = node.id == selectedNodeID
            let dimmed = hasSelection && !highlight.contains(node.id)
            let radius = nodeRadius(node.kind) + (isSelected ? 2 : 0)
            let fill = color(for: node, device: device).opacity(dimmed ? 0.3 : 1)

            switch node.kind {
            case .gateway:
                let rect = CGRect(x: pos.x - radius, y: pos.y - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 5),
                         with: .color(Color(UIColor.systemGray)))
                let icon = ctx.resolve(Text("\(Image(systemName: "wifi"))")
                    .foregroundStyle(.white)
                    .font(.system(size: radius)))
                ctx.draw(icon, at: pos)

            case .borderRouter:
                ctx.fill(circle(pos, radius), with: .color(fill))
                ctx.stroke(circle(pos, radius - 3),
                           with: .color(.white.opacity(dimmed ? 0.3 : 0.85)), lineWidth: 1.5)

            case .router:
                ctx.fill(circle(pos, radius), with: .color(fill.opacity(dimmed ? 0.15 : 0.25)))
                ctx.stroke(circle(pos, radius), with: .color(fill), lineWidth: 2)

            case .endDevice:
                if node.isBattery {
                    ctx.fill(circle(pos, max(2, radius - 2)), with: .color(fill))
                    ctx.stroke(circle(pos, radius),
                               with: .color(.green.opacity(dimmed ? 0.3 : 0.85)), lineWidth: 1.5)
                } else {
                    ctx.fill(circle(pos, radius), with: .color(fill))
                }
            }

            if isSelected {
                ctx.stroke(circle(pos, radius + 3), with: .color(.accentColor), lineWidth: 1.5)
            }

            if let rssi = device?.rssi, rssi.isWeakRSSI, !dimmed {
                ctx.stroke(circle(pos, radius + 3),
                           with: .color(.red.opacity(0.55)), lineWidth: 1)
            }

            // Border routers and routers always show their name — they're the landmarks that
            // make the map readable. End-device labels appear when zoomed past 0.7×.
            let showLabel = scale >= 0.7
                || isSelected
                || (hasSelection && highlight.contains(node.id))
                || node.kind == .borderRouter
                || node.kind == .router
            if showLabel {
                let maxChars: Int
                if isSelected { maxChars = 18 } else if scale >= 2.5 { maxChars = 16 } else if scale >= 1.8 { maxChars = 11 } else { maxChars = 7  }

                let displayName = node.name.count > maxChars
                    ? String(node.name.prefix(maxChars - 1)) + "…"
                    : node.name

                let labelSize = isSelected ? canvasNodeLabel + 2 : (scale >= 2.0 ? canvasNodeLabel + 1 : canvasNodeLabel)
                let label = ctx.resolve(Text(displayName)
                    .foregroundStyle(Color(UIColor.label).opacity(dimmed ? 0.35 : 1))
                    .font(.system(size: labelSize, weight: isSelected ? .semibold : .regular)))
                ctx.draw(label, at: CGPoint(x: pos.x, y: pos.y - radius - 6))
            }
        }
    }

    private func circle(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    func color(for node: MeshNode, device: ThreadDevice?) -> Color {
        switch node.kind {
        case .gateway:      return Color(UIColor.systemGray)
        case .borderRouter: return .blue
        case .router:
            guard let device else { return .indigo }
            return device.rssi?.rssiColor ?? .indigo
        case .endDevice:
            guard let device else { return .teal }
            return device.rssi?.rssiColor ?? .teal
        }
    }

    private func linkColor(for link: MeshLink) -> Color {
        switch link.linkQuality {
        case 4:  return .green
        case 3:  return .mint
        case 2:  return .orange
        default: return .red
        }
    }

    func accessibilityValue(for node: MeshNode, device: ThreadDevice?) -> String {
        var parts: [String] = [node.kind.rawValue]
        if let room = node.room { parts.append(room) }
        if let rssi = device?.rssi {
            parts.append(String(localized: rssi.rssiQualityLabel) + " signal")
        } else if device?.isOffline == true {
            parts.append("offline")
        }
        if let ch = node.channel { parts.append("Channel \(ch)") }
        return parts.joined(separator: ", ")
    }

    func accessibilityHint(for node: MeshNode) -> String {
        switch node.kind {
        case .gateway:      return "Internet uplink — not a physical device"
        case .borderRouter: return "Connects Thread mesh to the internet. Double-tap to view details."
        case .router:       return "Relays traffic for nearby devices. Double-tap to view details."
        case .endDevice:    return "End device. Double-tap to view details."
        }
    }
}
