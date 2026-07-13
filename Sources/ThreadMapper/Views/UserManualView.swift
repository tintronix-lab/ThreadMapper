import SwiftUI

// MARK: - Data model

private struct ManualTopic: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let body: [ManualBlock]
}

private struct ManualChapter: Identifiable {
    let id = UUID()
    let title: String
    let topics: [ManualTopic]
}

private enum ManualBlock {
    case paragraph(String)
    case bullets([String])
    case tip(String)
    case warning(String)
}

// MARK: - Content

private extension ManualChapter {
    static let all: [ManualChapter] = [
        .init(title: "Getting Started", topics: [
            .init(title: "What is Thread?", icon: "antenna.radiowaves.left.and.right", body: [
                .paragraph("Thread is a low-power, IP-based mesh networking protocol designed for smart-home devices. Unlike Wi-Fi or Bluetooth, every Thread device acts as a router — traffic hops from device to device until it reaches a Border Router that bridges your Thread network to your home Wi-Fi."),
                .paragraph("ThreadMapper reads your HomeKit Thread network and visualises every device, link, and health metric so you can see exactly how your mesh is performing."),
                .tip("No Thread devices yet? Enable Demo Mode in Settings → Tools to explore the app with a simulated network."),
            ]),
            .init(title: "Granting Permissions", icon: "checkmark.shield", body: [
                .paragraph("ThreadMapper requires two permissions to work:"),
                .bullets([
                    "HomeKit — reads device names, rooms, reachability, and Thread credentials. Grant access when iOS prompts you, or go to Settings → Privacy & Security → HomeKit.",
                    "Location (for Signal Survey only) — used to tag survey samples with GPS coordinates. The app requests this only when you start a walk survey.",
                ]),
                .tip("Notifications are optional. Enable them in Settings → Notifications if you want alerts when a device goes offline or the topology changes."),
            ]),
            .init(title: "First-Time Setup", icon: "list.bullet.clipboard", body: [
                .paragraph("Open Settings → Tools → Setup Checklist for a guided walkthrough of the recommended first-time configuration steps:"),
                .bullets([
                    "HomeKit permission granted",
                    "At least one Thread device discovered",
                    "Notification preferences set",
                    "Optional: Border Router URL configured",
                ]),
                .paragraph("The checklist marks each item complete automatically as you finish it."),
            ]),
        ]),

        .init(title: "Dashboard", topics: [
            .init(title: "Network Health Grade", icon: "chart.pie.fill", body: [
                .paragraph("The large ring at the top of the Dashboard shows your current network health grade (A–F) and a 0–100 score. The score is a weighted average of four signals:"),
                .bullets([
                    "Reachability — percentage of known devices currently online",
                    "Link quality — average RSSI across all active mesh links",
                    "Redundancy — whether the mesh has alternate paths if a device fails",
                    "Stability — how often devices have gone offline in the last hour",
                ]),
                .tip("Tap the ring to open the full Health History chart (Pro)."),
            ]),
            .init(title: "Quick-Stats Cards", icon: "square.grid.2x2", body: [
                .paragraph("Below the grade ring, four cards show at a glance:"),
                .bullets([
                    "Devices — total known vs. online right now",
                    "Border Routers — how many backbone bridges are active",
                    "Avg RSSI — mean received signal strength across all links (dBm)",
                    "Offline — devices unreachable longer than your grace-period setting",
                ]),
            ]),
            .init(title: "Health History Chart", icon: "waveform.path.ecg", body: [
                .paragraph("The sparkline chart below the cards plots your health score for the last 24 hours (free) or 30 days (Pro). A stable flat line near 100 is ideal; dips indicate when devices went offline or link quality dropped."),
                .tip("Scroll the chart left to pan back in time (Pro tier only)."),
            ]),
            .init(title: "Confetti Animation", icon: "party.popper", body: [
                .paragraph("When your network grade improves — for example moving from B to A — a brief confetti burst plays. The animation is suppressed automatically if Reduce Motion is enabled in iOS Accessibility settings."),
            ]),
        ]),

        .init(title: "Mesh Map", topics: [
            .init(title: "Reading the Graph", icon: "point.3.connected.trianglepath.dotted", body: [
                .paragraph("The Mesh Map tab shows a force-directed graph of your Thread network. Each circle (node) is a device; lines (edges) between nodes represent active Thread links."),
                .bullets([
                    "Node colour — matches the device's HomeKit room colour, or grey if unassigned",
                    "Node border — green: online, red: offline, yellow: degraded signal",
                    "Edge thickness — thicker lines indicate stronger link quality",
                    "Edge colour — green: strong (RSSI > –70 dBm), yellow: fair, red: weak (< –85 dBm)",
                ]),
            ]),
            .init(title: "Interacting with the Map", icon: "hand.tap", body: [
                .paragraph("Use standard iOS gestures on the map canvas:"),
                .bullets([
                    "Tap a node — opens the device detail sheet",
                    "Drag a node — reposition it; the physics simulation resumes when you release",
                    "Pinch — zoom in or out",
                    "Two-finger drag — pan the viewport",
                ]),
                .tip("Tap an empty area of the canvas to deselect any selected node."),
            ]),
            .init(title: "Border Router Indicator", icon: "house.and.flag", body: [
                .paragraph("Border Router devices are shown with a small flag badge. These devices bridge Thread to your Wi-Fi router and are the most critical nodes — if all Border Routers go offline the entire mesh loses internet access."),
                .warning("If your map shows no Border Router badge on any device, HomeKit may not have reported one yet. Wait a few seconds and pull to refresh."),
            ]),
        ]),

        .init(title: "Device List & Details", topics: [
            .init(title: "Device List", icon: "list.bullet", body: [
                .paragraph("The Devices tab lists every Thread device HomeKit knows about, sorted by room then name. Each row shows:"),
                .bullets([
                    "Signal strength badge (colour-coded)",
                    "Online / offline status dot",
                    "Room assignment",
                    "Device type icon",
                ]),
                .tip("Use the filter bar at the top to narrow by room, role (router / end device), or signal quality."),
            ]),
            .init(title: "Device Detail", icon: "info.circle", body: [
                .paragraph("Tap any device to open its detail sheet. You'll find:"),
                .bullets([
                    "Live RSSI and link-quality reading",
                    "Uptime / last-seen timestamp",
                    "Thread role (Router, REED, End Device, Sleepy End Device)",
                    "HomeKit room assignment",
                    "Signal history sparkline (last 24 hours)",
                    "Notes field — free-text notes that persist across sessions",
                    "Custom display name — override the HomeKit name just within ThreadMapper",
                ]),
            ]),
            .init(title: "Device Notes", icon: "note.text", body: [
                .paragraph("Notes are saved automatically as you type (with a short debounce). They are stored locally on device and are not shared with HomeKit or any cloud service."),
                .tip("Use notes to record things like installation date, cable run length, or anything that helps you understand why a device is where it is."),
            ]),
        ]),

        .init(title: "Activity Feed", topics: [
            .init(title: "What's Logged", icon: "list.triangle", body: [
                .paragraph("The Activity tab is a timestamped log of network events. ThreadMapper records:"),
                .bullets([
                    "Device joined / left the network",
                    "Network topology changes (new link formed or broken)",
                    "Grade changes (improvement or degradation)",
                    "Background refresh completions",
                ]),
                .paragraph("Events are capped at 500 entries. Older events are pruned automatically."),
            ]),
            .init(title: "Clearing the Feed", icon: "trash", body: [
                .paragraph("Go to Settings → Data → Clear Activity Feed to erase all logged events. This only affects the in-app log — it does not change anything in HomeKit."),
            ]),
        ]),

        .init(title: "Signal Survey", topics: [
            .init(title: "Overview", icon: "map", body: [
                .paragraph("The Signal Survey feature lets you walk through your home and record RSSI readings at different physical locations. The results appear as a heat map overlay, making dead zones immediately obvious."),
                .tip("For best results, walk slowly and pause briefly in each spot before moving on."),
            ]),
            .init(title: "Starting a Walk Survey", icon: "figure.walk", body: [
                .paragraph("Tap the Survey tab → Start Survey. Choose a room label, then tap Begin. The app begins sampling RSSI from nearby Thread devices every few seconds and tagging each sample with your GPS coordinates."),
                .bullets([
                    "Grant Location access when prompted (required for GPS tagging)",
                    "Samples without a GPS fix are discarded — stay outdoors or near a window if signal is weak",
                    "Tap Finish when you've covered the area",
                ]),
                .warning("GPS accuracy indoors is typically 3–10 m. Survey results are useful for identifying large dead zones, not for precise sub-meter placement."),
            ]),
            .init(title: "Reading the Heat Map", icon: "thermometer.medium", body: [
                .paragraph("After finishing, the survey appears on a map. Sample dots are coloured by RSSI:"),
                .bullets([
                    "Green — strong signal (> –70 dBm)",
                    "Yellow — fair signal (–70 to –85 dBm)",
                    "Red — weak signal (< –85 dBm)",
                    "Grey — no Thread device in range",
                ]),
                .tip("Place Thread routers in areas where the heat map shows red or grey to fill coverage gaps."),
            ]),
            .init(title: "Exporting Surveys", icon: "square.and.arrow.up", body: [
                .paragraph("Open a saved survey → tap the share icon to export a CSV file containing all sample points with timestamp, latitude, longitude, and RSSI. You can open this in Numbers, Excel, or any mapping tool."),
            ]),
        ]),

        .init(title: "Notifications", topics: [
            .init(title: "Alert Types", icon: "bell.badge", body: [
                .paragraph("ThreadMapper can send two categories of push notification:"),
                .bullets([
                    "Offline device alert — fires when a device has been unreachable longer than the configured grace period",
                    "Topology change alert — fires when a device joins or leaves the network, or when the mesh routing changes significantly",
                ]),
                .paragraph("Enable or disable each type in Settings → Notifications."),
            ]),
            .init(title: "Offline Grace Period", icon: "timer", body: [
                .paragraph("Devices can briefly drop off HomeKit's radar for innocent reasons (firmware update, power cycle). The grace period delays the offline alert to avoid false alarms."),
                .bullets([
                    "30 seconds — fastest alerts, more false positives",
                    "1 minute (default) — balanced",
                    "2 or 5 minutes — fewer alerts, slower notification",
                ]),
            ]),
            .init(title: "Quiet Hours", icon: "moon.fill", body: [
                .paragraph("Enable Quiet Hours in Settings to suppress all notifications during a nightly window. Set a start time and end time; the window can cross midnight (e.g. 10 PM – 7 AM). Notifications that would have fired during quiet hours are silently discarded — they do not queue up and deliver when quiet hours end."),
            ]),
        ]),

        .init(title: "Widget", topics: [
            .init(title: "Adding the Widget", icon: "rectangle.3.group", body: [
                .paragraph("ThreadMapper provides a medium Home Screen widget. To add it:"),
                .bullets([
                    "Long-press your Home Screen → tap the + button",
                    "Search for \"ThreadMapper\"",
                    "Choose the medium widget size and tap Add Widget",
                ]),
            ]),
            .init(title: "What the Widget Shows", icon: "rectangle.and.text.magnifyingglass", body: [
                .paragraph("The widget displays a snapshot of your network taken during the last background refresh:"),
                .bullets([
                    "Current health grade and score",
                    "Online / total device count",
                    "Timestamp — \"Updated just now\" (< 1 min) or a relative time",
                ]),
                .tip("iOS controls how often background refreshes occur. The widget updates at most every 15 minutes under normal conditions; actual frequency depends on device usage patterns."),
            ]),
        ]),

        .init(title: "Pro Features", topics: [
            .init(title: "What's Included in Pro", icon: "star.fill", body: [
                .paragraph("ThreadMapper Pro unlocks a set of advanced features for power users:"),
                .bullets([
                    "30-Day Health History — chart and trend analysis beyond the free 24-hour window",
                    "Mesh Resilience Score — shows which single device failure would partition your mesh",
                    "Health Streaks — tracks consecutive Grade A days",
                    "Weekly Reports — plain-English summaries delivered every Sunday",
                    "Siri Shortcuts — \"Check my Thread network\" and \"Show offline devices\" without opening the app",
                ]),
            ]),
            .init(title: "Purchasing Pro", icon: "creditcard", body: [
                .paragraph("Tap the Pro badge anywhere in the app, or go to Settings (future release). Two subscription options are available:"),
                .bullets([
                    "Monthly — billed each month, cancel any time",
                    "Annual — billed once per year, typically ~40% less than monthly",
                ]),
                .paragraph("Payment is charged to your Apple ID. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the period. Manage or cancel in iOS Settings → Apple ID → Subscriptions."),
            ]),
            .init(title: "Restoring Purchases", icon: "arrow.clockwise", body: [
                .paragraph("If you reinstall the app or switch to a new iPhone, tap Restore Purchases on the paywall screen. Your subscription is tied to your Apple ID and will be restored automatically at no charge."),
            ]),
        ]),

        .init(title: "Settings Reference", topics: [
            .init(title: "Border Router (Advanced)", icon: "server.rack", body: [
                .paragraph("If you run an OpenThread Border Router (e.g. Home Assistant with an OTBR add-on), enter its REST API URL here (e.g. http://192.168.1.50:8081). ThreadMapper will read:"),
                .bullets([
                    "Thread channel and PAN ID",
                    "Actual link-quality metrics from the OTBR dataset",
                ]),
                .paragraph("Apple HomePod and Google Nest border routers do not expose this API — leave the field blank if you use only those."),
                .tip("Tap Test Connection after entering the URL to verify ThreadMapper can reach the OTBR before saving."),
            ]),
            .init(title: "Demo Mode", icon: "play.rectangle", body: [
                .paragraph("Demo Mode replaces real HomeKit discovery with a simulated Thread network of 8 devices. It is useful for exploring the app before you own Thread hardware, or for testing settings without affecting a live network. Restart the app after toggling Demo Mode for the change to take effect."),
            ]),
            .init(title: "Data Management", icon: "internaldrive", body: [
                .paragraph("Settings → Data contains destructive-clear actions for three local stores:"),
                .bullets([
                    "Signal History — per-device RSSI time-series (used in device detail sparklines)",
                    "Health Score History — the dashboard chart data",
                    "Activity Feed — the event log",
                ]),
                .warning("These actions are permanent and cannot be undone. All cleared data is deleted from the device and does not affect HomeKit or iCloud."),
            ]),
        ]),

        .init(title: "Troubleshooting", topics: [
            .init(title: "No Devices Showing", icon: "questionmark.circle", body: [
                .paragraph("If the device list and mesh map are empty:"),
                .bullets([
                    "Confirm HomeKit permission is granted — iOS Settings → Privacy & Security → HomeKit → ThreadMapper",
                    "Open the Home app and verify your Thread devices appear there first",
                    "Wait 10–15 seconds; initial HomeKit discovery can be slow",
                    "Try enabling Demo Mode to confirm the app itself is working",
                ]),
                .warning("ThreadMapper reads HomeKit exclusively. If HomeKit doesn't know about a device, ThreadMapper cannot see it either."),
            ]),
            .init(title: "Devices Show as Offline", icon: "wifi.slash", body: [
                .paragraph("A device shown as offline means HomeKit reported it unreachable. Common causes:"),
                .bullets([
                    "Power outage or device unplugged",
                    "Device firmware update in progress (usually resolves in 1–2 minutes)",
                    "Thread mesh is partitioned — check that a Border Router is online",
                    "Device too far from nearest Thread router; consider adding a device in between",
                ]),
            ]),
            .init(title: "Widget Not Updating", icon: "rectangle.badge.xmark", body: [
                .paragraph("iOS controls widget refresh timing and may defer background work under Low Power Mode or high CPU load. If the widget shows a very stale timestamp:"),
                .bullets([
                    "Open ThreadMapper — this triggers a foreground refresh and reloads the widget timeline",
                    "Check that Background App Refresh is enabled — iOS Settings → General → Background App Refresh → ThreadMapper",
                    "Disable Low Power Mode if active",
                ]),
            ]),
            .init(title: "Survey Samples All Grey", icon: "location.slash", body: [
                .paragraph("Grey dots mean no Thread device signal was detectable at that location. This is expected if:"),
                .bullets([
                    "You are too far from any Thread device",
                    "The device is a Sleepy End Device that polls infrequently",
                    "The room has significant RF shielding (concrete, metal framing)",
                ]),
                .tip("Move a Thread router closer to the area and re-run the survey to confirm coverage improves."),
            ]),
            .init(title: "Resetting Everything", icon: "arrow.counterclockwise", body: [
                .paragraph("To start fresh: clear all three stores in Settings → Data, then delete and reinstall the app. This removes all local data. Your HomeKit home, devices, and Apple ID subscription are unaffected."),
            ]),
        ]),
    ]
}

// MARK: - Views

struct UserManualView: View {
    var body: some View {
        List {
            ForEach(ManualChapter.all) { chapter in
                Section(chapter.title) {
                    ForEach(chapter.topics) { topic in
                        NavigationLink {
                            ManualTopicView(topic: topic)
                        } label: {
                            Label(topic.title, systemImage: topic.icon)
                        }
                    }
                }
            }
        }
        .navigationTitle("User Manual")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct ManualTopicView: View {
    let topic: ManualTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label(topic.title, systemImage: topic.icon)
                    .font(.title2.bold())
                    .padding(.bottom, 4)

                ForEach(Array(topic.body.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .padding(20)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func blockView(_ block: ManualBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .tip(let text):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .frame(width: 20)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.yellow.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        case .warning(let text):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.orange.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
