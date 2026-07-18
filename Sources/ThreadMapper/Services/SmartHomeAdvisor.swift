import SwiftUI

/// Pure analysis engine that generates smart-home placement, automation, and scene
/// suggestions from the current device graph and diagnostic report.
struct SmartHomeAdvisor {

    // MARK: - Output types

    enum SuggestionPriority {
        case high, medium, low

        var color: Color {
            switch self { case .high: .red; case .medium: .orange; case .low: .blue }
        }
        var label: LocalizedStringResource {
            switch self { case .high: "High Impact"; case .medium: "Helpful"; case .low: "Nice to Have" }
        }
    }

    struct PlacementSuggestion: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let impact: String
        let priority: SuggestionPriority
        let icon: String
        let room: String?
    }

    struct AutomationSuggestion: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let steps: [String]
        let icon: String
        let triggerDevice: String?
        let benefit: String
    }

    struct SceneRecommendation: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String
        let devices: [String]
        let rooms: [String]
        let triggerSuggestion: String
    }

    // MARK: - Placement Suggestions

    func placementSuggestions(
        devices: [ThreadDevice],
        report: NetworkDiagnosticsEngine.Report?
    ) -> [PlacementSuggestion] {
        var results: [PlacementSuggestion] = []

        let borderRouters = devices.filter { $0.isBorderRouter }
        let routers = devices.filter { $0.isRoutingCapable && !$0.isBorderRouter }
        let roomCoverage = report?.roomCoverage ?? []
        let deviceHops = report?.deviceHops ?? []

        // No border router
        if borderRouters.isEmpty {
            results.append(PlacementSuggestion(
                title: "Add a Thread Border Router",
                detail: "No Thread border router detected. A HomePod mini or Apple TV 4K (4th gen) acts as the gateway between your Thread mesh and your Wi-Fi/internet. Without one, Thread devices cannot communicate outside the local mesh.",
                impact: "Critical — Thread mesh has no internet connectivity",
                priority: .high,
                icon: "antenna.radiowaves.left.and.right.slash",
                room: nil
            ))
        } else if borderRouters.count == 1 {
            // Single border router — single point of failure
            let br = borderRouters[0]
            results.append(PlacementSuggestion(
                title: "Add a Second Border Router",
                detail: "You have only one border router (\(br.name)). If it goes offline, your entire Thread mesh loses internet access. A second HomePod mini or Apple TV in a different room provides failover.",
                impact: "Eliminates single point of failure for the whole mesh",
                priority: .high,
                icon: "arrow.triangle.2.circlepath",
                room: br.room
            ))
        }

        // Rooms with poor coverage and no router
        let poorRooms = roomCoverage.filter { $0.gradeRank <= 1 && !$0.hasRouter }
        for room in poorRooms.prefix(3) {
            results.append(PlacementSuggestion(
                title: "Add a Router in \(room.room)",
                detail: "\(room.room) has grade \(room.grade) coverage with \(room.totalDevices) device(s) and no Thread router. A mains-powered Eve, Nanoleaf, or IKEA Thread device in this room would act as a relay, extending coverage to nearby devices.",
                impact: "Improves coverage from \(room.grade) toward A",
                priority: .high,
                icon: "plus.circle.fill",
                room: room.room
            ))
        }

        // Devices with too many hops
        let deepDevices = deviceHops.filter { $0.hopCount >= 4 && $0.hopCount < 99 }
        for hopInfo in deepDevices.prefix(2) {
            let deviceRoom = hopInfo.device.room ?? "its room"
            results.append(PlacementSuggestion(
                title: "Shorten path for \(hopInfo.device.name)",
                detail: "\(hopInfo.device.name) is \(hopInfo.hopCount) hops from the border router. Each hop adds latency and potential failure points. Place a Thread router (mains-powered plug or light) between this device and the nearest border router.",
                impact: "Reduces latency and improves reliability for this device",
                priority: .medium,
                icon: "point.3.connected.trianglepath.dotted",
                room: deviceRoom
            ))
        }

        // No dedicated routers at all
        if routers.isEmpty && !borderRouters.isEmpty && devices.count > 5 {
            results.append(PlacementSuggestion(
                title: "Add a Dedicated Mesh Router",
                detail: "Your mesh has \(devices.count) devices but no dedicated Thread routers — all traffic routes directly to border routers. A mains-powered Thread device (Eve Energy, Nanoleaf panel, IKEA plug) placed centrally acts as a relay and dramatically improves mesh resilience.",
                impact: "Reduces direct hop distance for most end devices",
                priority: .medium,
                icon: "network",
                room: nil
            ))
        }

        // Rooms with coverage gaps (D or F grade rooms that have a router but still bad)
        let gappyRooms = roomCoverage.filter { $0.gradeRank <= 1 && $0.hasRouter }
        for room in gappyRooms.prefix(2) {
            results.append(PlacementSuggestion(
                title: "Reposition router in \(room.room)",
                detail: "\(room.room) has a router (\(room.routerNames.first ?? "device")) but still grades \(room.grade). Metal appliances, thick walls, or distance may be absorbing signal. Try moving the router to a more central location or elevated shelf.",
                impact: "Better signal distribution within the room",
                priority: .medium,
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                room: room.room
            ))
        }

        // Isolated devices (unreachable hops)
        let isolated = deviceHops.filter { $0.hopCount == 99 }
        for hopInfo in isolated.prefix(2) {
            results.append(PlacementSuggestion(
                title: "Reconnect \(hopInfo.device.name)",
                detail: "\(hopInfo.device.name) appears isolated — no inferred path to a border router. Move it closer to the mesh or add a router between it and the nearest Thread device.",
                impact: "Restores this device to the mesh",
                priority: .high,
                icon: "wifi.slash",
                room: hopInfo.device.room
            ))
        }

        return results
    }

    // MARK: - Automation Suggestions

    func automationSuggestions(
        devices: [ThreadDevice],
        offlineEvents: [ActivityEvent]
    ) -> [AutomationSuggestion] {
        var results: [AutomationSuggestion] = []

        let onlineDevices = devices.filter { !$0.isOffline }
        let borderRouters = devices.filter { $0.isBorderRouter }

        // Reliable trigger devices — online, mains-powered (no battery), router-capable
        let reliableTriggers = onlineDevices.filter { $0.isRoutingCapable && $0.batteryPercentage == nil }

        // Offline alert automations for frequently-dropped devices
        let offlineByDevice: [UUID: [ActivityEvent]] = offlineEvents
            .filter { $0.kind == .deviceOffline }
            .reduce(into: [:]) { dict, event in
                guard let did = event.deviceID else { return }
                dict[did, default: []].append(event)
            }
        let troubledDevices = offlineByDevice
            .filter { $0.value.count >= 3 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(2)

        for (deviceID, events) in troubledDevices {
            let name = devices.first { $0.id == deviceID }?.name ?? "Unknown Device"
            results.append(AutomationSuggestion(
                title: "Alert when \(name) goes offline",
                description: "\(name) has gone offline \(events.count) times recently. Create a HomeKit automation to notify you immediately when it loses connection so you can act before it affects other automations.",
                steps: [
                    "Open the Home app → Automations → tap + → An Accessory is Controlled",
                    "Select \(name) as the trigger device",
                    "Set trigger condition to 'becomes unreachable'",
                    "Add action: send a notification to your iPhone",
                    "Name it '\(name) offline alert' and save"
                ],
                icon: "bell.badge.fill",
                triggerDevice: name,
                benefit: "Get notified within seconds of this device dropping off"
            ))
        }

        // Avoid using offline/weak devices as triggers
        let weakTriggerDevices = onlineDevices.filter {
            let rssi = $0.rssi ?? -65
            return rssi.isWeakRSSI && $0.isBorderRouter == false
        }
        if let weak = weakTriggerDevices.first, let reliable = reliableTriggers.first(where: { $0.room == weak.room || $0.room != nil }) {
            results.append(AutomationSuggestion(
                title: "Use \(reliable.name) as your primary trigger",
                description: "\(weak.name) has a weak signal and may miss triggers. \(reliable.name) in the same area has a stronger, more reliable connection — use it as the trigger device for time-sensitive automations instead.",
                steps: [
                    "Open Home app → Automations → find automations triggered by \(weak.name)",
                    "Tap each automation → edit the trigger",
                    "Replace \(weak.name) with \(reliable.name) as the trigger",
                    "Test by activating the automation manually"
                ],
                icon: "arrow.triangle.swap",
                triggerDevice: reliable.name,
                benefit: "More reliable automation triggering, fewer missed events"
            ))
        }

        // Suggest border router failover awareness
        if borderRouters.count >= 2 {
            results.append(AutomationSuggestion(
                title: "Create a mesh health check shortcut",
                description: "You have \(borderRouters.count) border routers. Create a Siri Shortcut that opens ThreadMapper when you notice smart home latency — this gives you an instant mesh health snapshot without manual diagnosis.",
                steps: [
                    "Open Shortcuts app → tap + → search 'Open App'",
                    "Select ThreadMapper as the app to open",
                    "Add a Siri phrase like 'Check my mesh'",
                    "Optionally add a 'Check Thread Network' intent from ThreadMapper"
                ],
                icon: "mic.fill",
                triggerDevice: nil,
                benefit: "Instant network health check with a voice command"
            ))
        }

        // Suggest presence-based routing if motion sensors exist
        let motionSensors = onlineDevices.filter { $0.deviceType.lowercased().contains("motion") || $0.productName.lowercased().contains("motion") }
        if let sensor = motionSensors.first {
            results.append(AutomationSuggestion(
                title: "Room-based device wake with \(sensor.name)",
                description: "Use \(sensor.name) as a presence trigger to wake other Thread devices in the same room when motion is detected. This keeps battery-powered devices in sleep mode until needed, extending their life.",
                steps: [
                    "Open Home app → Automations → + → An Accessory is Controlled",
                    "Select \(sensor.name) → trigger on 'Motion Detected'",
                    "Add actions for devices in \(sensor.room ?? "the same room")",
                    "Set a 5-minute auto-off when no further motion"
                ],
                icon: "figure.walk",
                triggerDevice: sensor.name,
                benefit: "Conserves battery on nearby sleepy end devices"
            ))
        }

        // Suggest time-based mesh maintenance window
        results.append(AutomationSuggestion(
            title: "Schedule a nightly mesh health check",
            description: "Run a ThreadMapper diagnostic at 3 AM using Shortcuts + automation so you have a fresh baseline each morning without interrupting your day.",
            steps: [
                "Open Shortcuts → tap + → add 'Open App' action (ThreadMapper)",
                "Tap the shortcut → Add to Automation → Time of Day",
                "Set to 3:00 AM, every day",
                "ThreadMapper will refresh device states in the background"
            ],
            icon: "moon.stars.fill",
            triggerDevice: nil,
            benefit: "Always have fresh mesh data when you wake up"
        ))

        return results
    }

    // MARK: - Scene Recommendations

    func sceneRecommendations(devices: [ThreadDevice]) -> [SceneRecommendation] {
        var results: [SceneRecommendation] = []

        let onlineDevices = devices.filter { !$0.isOffline }
        let rooms = Set(onlineDevices.compactMap { $0.room }).sorted()
        let reliableDevices = onlineDevices.filter { $0.isRoutingCapable || ($0.rssi ?? -65) > -70 }

        // Good Night scene
        let bedroomDevices = onlineDevices.filter { ($0.room ?? "").lowercased().contains("bedroom") || ($0.room ?? "").lowercased().contains("bed") }
        let motionSensors = onlineDevices.filter { $0.productName.lowercased().contains("motion") || $0.deviceType.lowercased().contains("motion") }
        let goodNightDevices = (bedroomDevices + motionSensors).prefix(4).map { $0.name }
        if !goodNightDevices.isEmpty {
            results.append(SceneRecommendation(
                name: "Good Night",
                description: "Arm motion sensors, turn off non-bedroom devices, and reduce Thread polling load while you sleep.",
                icon: "moon.fill",
                devices: Array(goodNightDevices),
                rooms: ["Bedroom"],
                triggerSuggestion: "Trigger via: tap on iPhone, Siri 'Good Night', or a bedside Eve button"
            ))
        }

        // Morning scene
        let livingDevices = onlineDevices.filter {
            let r = ($0.room ?? "").lowercased()
            return r.contains("living") || r.contains("kitchen") || r.contains("hall")
        }
        if !livingDevices.isEmpty {
            results.append(SceneRecommendation(
                name: "Good Morning",
                description: "Activate your main living area devices at full power and set sensors to active mode for a full-coverage start to the day.",
                icon: "sunrise.fill",
                devices: livingDevices.prefix(4).map { $0.name },
                rooms: Array(Set(livingDevices.compactMap { $0.room })),
                triggerSuggestion: "Trigger via: first motion detected in the morning, or a scheduled 7 AM automation"
            ))
        }

        // Away scene using reliable Thread devices as guards
        let awayGuards = reliableDevices.prefix(4).map { $0.name }
        if !awayGuards.isEmpty {
            results.append(SceneRecommendation(
                name: "Away Mode",
                description: "Maximize Thread sensor coverage to your most reliable devices while you're out — conserving battery on sleepy end devices and keeping your most robust nodes active for security.",
                icon: "lock.shield.fill",
                devices: Array(awayGuards),
                rooms: Array(rooms.prefix(3)),
                triggerSuggestion: "Trigger via: when last person leaves home (use iPhone location automation)"
            ))
        }

        // Mesh stress-reduction scene for parties / heavy Wi-Fi use
        if devices.count >= 6 {
            let stableDevices = reliableDevices.filter { !$0.isOffline }.prefix(3).map { $0.name }
            results.append(SceneRecommendation(
                name: "Low Interference",
                description: "Reduce Thread traffic by activating only essential devices. Useful during heavy Wi-Fi activity (video calls, streaming) when 2.4 GHz congestion may affect your mesh.",
                icon: "wifi.exclamationmark",
                devices: Array(stableDevices),
                rooms: Array(rooms.prefix(2)),
                triggerSuggestion: "Trigger via: Siri shortcut or manually before video calls"
            ))
        }

        // Room-specific scenes
        for room in rooms.prefix(3) {
            let roomDevices = onlineDevices.filter { $0.room == room }
            guard roomDevices.count >= 2 else { continue }
            results.append(SceneRecommendation(
                name: "\(room) Scene",
                description: "A room-specific scene for \(room) grouping all \(roomDevices.count) Thread devices. Useful for quick control of everything in this room.",
                icon: "house.fill",
                devices: roomDevices.map { $0.name },
                rooms: [room],
                triggerSuggestion: "Trigger via: NFC tag placed in \(room), or an Eve button"
            ))
        }

        return results
    }
}
