import SwiftUI

// MARK: - Data model

private struct ManualTopic: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let icon: String
    let body: [ManualBlock]
}

private struct ManualChapter: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let topics: [ManualTopic]
}

private enum ManualBlock {
    case paragraph(LocalizedStringKey)
    case bullets([LocalizedStringKey])
    case tip(LocalizedStringKey)
    case warning(LocalizedStringKey)
}

// MARK: - Content

private extension ManualChapter {
    // swiftlint:disable function_body_length
    nonisolated(unsafe) static let all: [ManualChapter] = [

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
            .init(title: "iPad Layout", icon: "ipad.landscape", body: [
                .paragraph("On iPad, ThreadMapper uses a sidebar-and-detail layout. The sidebar on the left lists all main sections; tapping any item opens it in the detail pane on the right."),
                .paragraph("In portrait orientation the app switches to a tab-bar layout identical to iPhone. Rotate to landscape to restore the split view."),
                .tip("The sidebar can be hidden or revealed by tapping the sidebar button in the navigation bar."),
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
                .tip("Tap the ring to open the full Health History chart."),
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
            .init(title: "Anomaly Detection Banner", icon: "exclamationmark.triangle.fill", body: [
                .paragraph("When ThreadMapper detects one or more devices with a declining or critical signal trajectory, a yellow or red banner appears directly below the health ring. The banner names the affected devices and links to their detail sheets."),
                .paragraph("Trajectories are computed by comparing each device's recent signal readings against a rolling 24-hour baseline. A device is marked declining if its recent average is meaningfully below baseline, and critical if it falls below the worst observed baseline reading."),
                .tip("Tap a device name in the banner to jump directly to its detail sheet and see the full signal sparkline."),
            ]),
            .init(title: "Share Network Health Card", icon: "rectangle.and.hand.point.up.left", body: [
                .paragraph("Tap the ··· menu in the Dashboard toolbar and choose Share Health Card to generate a shareable image of your network's current state. The card shows grade letter and score, device counts, a colour-coded score bar, and ThreadMapper branding."),
                .paragraph("A preview sheet appears first; tap the Share button to send the image via the iOS share sheet."),
            ]),
            .init(title: "Pull to Refresh", icon: "arrow.clockwise", body: [
                .paragraph("Pull down anywhere on the Dashboard to force an immediate HomeKit scan and health recalculation. The widget timeline is also refreshed automatically after a foreground pull."),
            ]),
            .init(title: "Network Diagnostics", icon: "stethoscope", body: [
                .paragraph("Tap the ··· menu in the Dashboard toolbar and choose Network Diagnostics to open a full diagnostic report. The report runs automatically when the sheet opens and covers recommendations, border router comparison, room coverage, mesh depth, channel analysis, and single points of failure."),
                .tip("Tap Share Diagnostic Report at the bottom to export a plain-text report."),
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
            .init(title: "List Mode and Search", icon: "list.bullet.rectangle", body: [
                .paragraph("Tap the list/graph toggle button in the Mesh toolbar to switch between the force-directed graph and a flat device list. In list mode a search bar appears at the top — type any part of a device name to filter live. Tap the X button to clear the filter."),
                .tip("List mode is useful when your mesh has many devices and you want to quickly locate one by name."),
            ]),
            .init(title: "Hop-Count Indicators", icon: "arrow.up.right.circle", body: [
                .paragraph("Each node in the mesh graph displays a small hop-count badge showing how many Thread hops separate it from the nearest border router:"),
                .bullets([
                    "White / no badge — border router itself",
                    "Green — 1–2 hops",
                    "Orange — 3 hops",
                    "Red — 4+ hops",
                ]),
            ]),
            .init(title: "Anomaly Trajectory Arrows", icon: "arrow.down.right.circle", body: [
                .paragraph("Devices flagged by the Anomaly Detection Engine show a coloured arrow overlay on their node:"),
                .bullets([
                    "→ (grey) — stable: signal within normal range",
                    "↘ (orange) — declining: signal trending downward",
                    "↓ (red) — critical: signal at or below worst recorded baseline",
                ]),
            ]),
            .init(title: "Tools Menu", icon: "slider.horizontal.3", body: [
                .paragraph("Tap the Tools button in the Mesh toolbar to open a menu with advanced analysis tools:"),
                .bullets([
                    "Resilience Simulator — model the impact of losing any router or border router",
                    "Channel Interference Scanner — spectrum bar chart showing Wi-Fi overlap risk per Thread channel",
                    "Border Router Health Monitor — per-BR status cards with RSSI sparklines",
                    "Export Map — save or share the current mesh graph as an image (map mode only)",
                ]),
            ]),
            .init(title: "Border Router Indicator", icon: "house.and.flag", body: [
                .paragraph("Border Router devices are shown with a small flag badge. These devices bridge Thread to your Wi-Fi router and are the most critical nodes — if all Border Routers go offline the entire mesh loses internet access."),
                .warning("If your map shows no Border Router badge on any device, HomeKit may not have reported one yet. Wait a few seconds and pull to refresh."),
            ]),
            .init(title: "Export Mesh Map", icon: "square.and.arrow.up", body: [
                .paragraph("In map mode, open the Tools menu and choose Export Map. ThreadMapper renders the entire canvas at 2× resolution and opens a preview sheet. Tap the Share button to export via the iOS share sheet."),
                .tip("Export Map is only available in graph mode, not list mode."),
            ]),
        ]),

        .init(title: "Device List & Details", topics: [
            .init(title: "Device List", icon: "list.bullet", body: [
                .paragraph("The Devices tab lists every Thread device HomeKit knows about, sorted by room then name. Each row shows signal strength badge, online/offline status dot, room assignment, device type icon, and anomaly trajectory arrow if applicable."),
                .tip("Use the filter bar at the top to narrow by room, role (router / end device), or signal quality."),
            ]),
            .init(title: "Device Detail", icon: "info.circle", body: [
                .paragraph("Tap any device to open its detail sheet. Sections include:"),
                .bullets([
                    "Signal — live RSSI, link quality, and 24-hour sparkline",
                    "Network — Thread role, room, channel, and parent device",
                    "Mesh Path to Internet — the full hop chain from this device to the border router",
                    "Thread Neighbors (OTBR) — live neighbor table from your OpenThread Border Router",
                    "Firmware — current version and update history",
                    "Protocol Compatibility — which standards this device supports",
                    "Device — manufacturer, model, HomeKit accessory ID",
                    "Battery — remaining charge, estimated days remaining, and charging state",
                    "Reliability Score — 30-day offline frequency and online streak",
                    "AI Device Summary — on-device AI assessment (iOS 26, Apple Intelligence required)",
                    "Ask AI — open a device-focused chat session with the Network Assistant",
                    "Border Router Info — channel, PAN ID, and network name (border routers only)",
                    "Vendor Notes — model-specific tips and known quirks",
                    "Device History — offline count, first seen, and last event",
                    "Notes — free-text field, saved automatically",
                ]),
            ]),
            .init(title: "Mesh Path to Internet", icon: "arrow.up.forward.circle", body: [
                .paragraph("The Mesh Path section traces the routing chain from the selected device up through its parent nodes to the border router. Each hop is shown with the device name and its Thread role."),
                .bullets([
                    "Green — 1–2 hops: excellent path length",
                    "Orange — 3 hops: acceptable but worth monitoring",
                    "Red — 4+ hops: latency risk; consider adding a router between the device and the border router",
                ]),
                .tip("Devices marked as unreachable show a dashed path — this means ThreadMapper cannot trace a complete route, usually because the device is offline."),
            ]),
            .init(title: "Thread Neighbors (OTBR)", icon: "network", body: [
                .paragraph("If you have an OpenThread Border Router configured in Settings, the Thread Neighbors section appears with live data from the OTBR REST API. For each neighbor you'll see RLOC16, Role (Child or Router), Average RSSI, and Link Margin."),
                .tip("An \"OTBR\" green badge in the section header confirms the data is live rather than estimated from HomeKit."),
            ]),
            .init(title: "Firmware Version", icon: "arrow.up.circle", body: [
                .paragraph("The Firmware section shows the current firmware version string reported by the device. ThreadMapper reads this from the OTBR dataset when available, and falls back to the HomeKit firmware characteristic."),
                .paragraph("Tap \"Firmware History\" to open a timeline of every version change ThreadMapper has observed for this device."),
                .tip("If the firmware field shows \"Unknown\", the device hasn't reported a version string — this is normal for some manufacturers."),
            ]),
            .init(title: "Device Protocol Compatibility", icon: "checkmark.seal", body: [
                .paragraph("The Protocol Compatibility section lists which smart-home standards the device supports: Thread, Matter, HomeKit, and optionally Zigbee or Z-Wave for mixed-protocol hubs."),
                .paragraph("This information helps you understand whether a device will work with other ecosystems if you switch platforms."),
            ]),
            .init(title: "Battery Life Estimator", icon: "battery.75", body: [
                .paragraph("For Sleepy End Devices (battery-powered devices that poll infrequently), the Battery section includes a days-remaining estimate alongside the raw percentage."),
                .bullets([
                    "Green — more than 14 days remaining",
                    "Orange — 7–14 days remaining",
                    "Red — fewer than 7 days remaining",
                ]),
                .tip("The estimate is an approximation. Actual battery life varies significantly by device activity, temperature, and HomeKit polling frequency."),
            ]),
            .init(title: "Device Reliability Score", icon: "chart.bar.fill", body: [
                .paragraph("The Reliability section summarises how consistently this device has stayed online over the last 30 days:"),
                .bullets([
                    "Excellent — zero offline events in 30 days",
                    "Good — 1–2 offline events",
                    "Fair — 3–5 offline events",
                    "Needs Attention — 6 or more offline events",
                ]),
                .paragraph("You'll also see the raw offline event count and the online streak — consecutive days since the last offline event."),
            ]),
            .init(title: "AI Device Health Summary", icon: "sparkles", body: [
                .paragraph("On iOS 26 with Apple Intelligence enabled, an \"AI Device Summary\" section appears near the top of each Device Detail sheet. It contains a 2-sentence plain-English assessment generated on-device, covering current signal health relative to the device's own baseline, any anomaly trajectory, and battery context where relevant."),
                .paragraph("The summary is generated fresh each time you open the device detail and is never stored or sent off-device."),
            ]),
            .init(title: "Ask AI About This Device", icon: "bubble.left.and.bubble.right", body: [
                .paragraph("Tap \"Ask AI About This Device\" to open a Network Assistant chat session pre-focused on the selected device. The session is seeded with current RSSI, signal trajectory, battery level, offline event count, and Thread role. The assistant asks an opening question based on the device's current state."),
                .tip("Requires iOS 26 and Apple Intelligence. The feature is hidden on unsupported devices."),
            ]),
            .init(title: "Vendor Notes", icon: "building.2", body: [
                .paragraph("ThreadMapper includes built-in tips for popular Thread device brands. When you open a device detail for a recognised manufacturer, a Vendor Notes card appears with model-specific guidance."),
                .paragraph("Supported brands include Apple (HomePod), Eve, Nanoleaf, IKEA, Philips Hue, Aqara, Bosch, and Samsung SmartThings."),
            ]),
            .init(title: "Device Notes", icon: "note.text", body: [
                .paragraph("Notes are saved automatically as you type (with a short debounce). They are stored locally on device and are not shared with HomeKit or any cloud service."),
                .tip("Use notes to record things like installation date, cable run length, or anything that helps you understand why a device is where it is."),
            ]),
            .init(title: "Device History (Detail)", icon: "clock.arrow.circlepath", body: [
                .paragraph("At the bottom of each device detail sheet, the Device History section shows: First Seen (when ThreadMapper first recorded the device), Offline Events (colour-coded count), and Last Event (most recent activity log entry with a relative timestamp)."),
            ]),
        ]),

        .init(title: "Activity Feed", topics: [
            .init(title: "What's Logged", icon: "list.triangle", body: [
                .paragraph("The Activity tab is a timestamped log of network events. ThreadMapper records device joined/left, topology changes, grade changes, background refresh completions, and new device detections. Events are capped at 500 entries."),
            ]),
            .init(title: "AI Activity Digest", icon: "sparkles", body: [
                .paragraph("When the activity feed contains 3 or more events, a purple AI Digest card appears at the top. It summarises the 10 most recent events in 2 plain-English sentences. The digest refreshes automatically when the event count changes."),
                .tip("Requires iOS 26 and Apple Intelligence. The card is hidden on unsupported devices."),
            ]),
            .init(title: "Clearing the Feed", icon: "trash", body: [
                .paragraph("Go to Settings → Data → Clear Activity Feed to erase all logged events. This only affects the in-app log — it does not change anything in HomeKit."),
            ]),
            .init(title: "Exporting Activity", icon: "square.and.arrow.up", body: [
                .paragraph("Tap the share icon in the Activity toolbar to export the full activity log as a plain-text file via the iOS share sheet."),
            ]),
            .init(title: "Network Timeline", icon: "chart.xyaxis.line", body: [
                .paragraph("Tap the chart icon in the Activity toolbar to open the Network Timeline — a combined view that overlays activity events on top of the health score history chart. Use the 6H / 24H / 7D selector to zoom in or out."),
                .tip("The score annotation on each event row shows the interpolated health score at that instant — useful for seeing whether a single event caused a grade drop."),
            ]),
            .init(title: "Device History", icon: "chart.bar.doc.horizontal", body: [
                .paragraph("Tap the chart icon to also access Device History — an aggregated view of every device that has appeared in the activity log over the past 7 days, showing stability grade, live status, first seen date, offline count, and last event."),
            ]),
        ]),

        .init(title: "Network Diagnostics", topics: [
            .init(title: "Opening Diagnostics", icon: "stethoscope", body: [
                .paragraph("Network Diagnostics is reached from the Dashboard — tap the ··· menu in the top-right toolbar and choose Network Diagnostics. The analysis runs automatically each time the sheet opens."),
            ]),
            .init(title: "Recommendations", icon: "checklist", body: [
                .paragraph("The top section lists actionable recommendations sorted by severity: Critical (red), High (orange), and Medium (yellow). If no issues are found, a green \"Network looks healthy\" card is shown instead."),
            ]),
            .init(title: "Border Router Comparison", icon: "arrow.left.arrow.right", body: [
                .paragraph("When two or more border routers are present, a comparison table appears showing direct children, total subtree, and channel for each border router."),
                .tip("Uneven subtree sizes can indicate that one border router is doing all the routing work."),
            ]),
            .init(title: "Room Coverage", icon: "house.and.flag", body: [
                .paragraph("Room Coverage grades each HomeKit room from A to F based on signal quality:"),
                .bullets([
                    "A — average RSSI better than −65 dBm: excellent",
                    "B — average RSSI −65 to −75 dBm: good",
                    "C — average RSSI −75 to −85 dBm: fair",
                    "D / F — very weak signal or majority of devices offline",
                ]),
            ]),
            .init(title: "Mesh Depth", icon: "point.3.connected.trianglepath.dotted", body: [
                .paragraph("Mesh Depth lists every device grouped by hop count: 1–2 hops (ideal), 3 hops (acceptable), 4+ hops (increasing risk; commands can time out)."),
                .tip("To reduce hop count, place a Thread router roughly halfway between the deep device and its current parent."),
            ]),
            .init(title: "Thread Channel Analysis", icon: "waveform.badge.exclamationmark", body: [
                .paragraph("Thread 802.15.4 operates in the 2.4 GHz band on channels 11–26, overlapping with 2.4 GHz Wi-Fi. The channel analysis rates each channel your network uses: High risk (red), Medium risk (orange), Low risk (green)."),
                .warning("Not all border routers allow manual channel selection. Apple HomePod and Google Nest border routers manage the channel automatically."),
            ]),
            .init(title: "Single Points of Failure", icon: "exclamationmark.circle.fill", body: [
                .paragraph("A Single Point of Failure is a non-border-router routing device that is the only Thread router in its room and has at least one end device whose traffic passes through it. If it goes offline, those end devices lose their path."),
                .tip("The easiest fix is to add a second mains-powered Thread device to the same room."),
            ]),
            .init(title: "Topology Baseline Comparison", icon: "arrow.left.arrow.right.square", body: [
                .paragraph("Tap \"Save Baseline\" to snapshot the current topology. On subsequent runs, ThreadMapper compares the live topology to the baseline and highlights devices that joined, left, changed their parent node, or changed hop count."),
                .tip("Save a baseline immediately after a successful network setup so you have a known-good reference."),
            ]),
            .init(title: "Signal Degradation Tracking", icon: "waveform.path.badge.minus", body: [
                .paragraph("The Signal Degradation section flags devices whose average RSSI has declined significantly compared to their own 7-day history, showing current vs. average RSSI and suggested remediation."),
            ]),
            .init(title: "OTBR Dataset Inspector", icon: "doc.text.magnifyingglass", body: [
                .paragraph("When an OTBR URL is configured, the Dataset Inspector shows the raw Active Operational Dataset fields: Network Name, Channel, PAN ID, Extended PAN ID, Mesh Local Prefix, Key Rotation interval, and OTBR Role."),
                .tip("The Extended PAN ID is the definitive identifier for a Thread network. Use it when troubleshooting commissioning failures."),
            ]),
            .init(title: "Diagnostic Run History", icon: "clock.badge.checkmark", body: [
                .paragraph("ThreadMapper logs every time you open the diagnostics sheet with the top-level result (Healthy / Issues Found / Critical). Tap \"Run History\" to see a timeline of past runs and spot when a problem first appeared or was resolved."),
            ]),
            .init(title: "Mesh Quality Scorecard", icon: "checkmark.rectangle.stack", body: [
                .paragraph("The Mesh Quality Scorecard condenses the full diagnostic report into a single A–F grade per dimension: Reachability, Signal Quality, Redundancy, Depth, and Channel Health. An overall composite grade is shown at the top."),
            ]),
            .init(title: "Thread Network Identity", icon: "network", body: [
                .paragraph("When an OTBR URL is configured, Network Diagnostics fetches the full Active Operational Dataset and shows Network Name, Channel, PAN ID, Extended PAN ID, Mesh Local Prefix, Key Rotation, OTBR Role, and RLOC16."),
            ]),
            .init(title: "Commissioning Readiness", icon: "checkmark.shield", body: [
                .paragraph("Tap the ··· menu and choose Commissioning Readiness. Six automated checks run before you add a new Thread device: Border Router Present, Border Router Redundancy, Mesh Reachability, Routing Capacity, Thread Channel, and Mesh Depth."),
                .tip("Run this check before adding each new Thread device to catch issues before they cause a commissioning failure."),
            ]),
            .init(title: "Sharing the Report", icon: "square.and.arrow.up", body: [
                .paragraph("Tap Share Diagnostic Report at the bottom of the Network Diagnostics sheet to export a plain-text summary including all recommendations, room grades, hop-count table, and channel assignments."),
            ]),
        ]),

        .init(title: "Signal Survey", topics: [
            .init(title: "Overview", icon: "map", body: [
                .paragraph("The Signal Survey feature lets you walk through your home and record RSSI readings at different physical locations. The results appear as a heat map overlay, making dead zones immediately obvious."),
                .tip("For best results, walk slowly and pause briefly in each spot before moving on."),
            ]),
            .init(title: "Starting a Walk Survey", icon: "figure.walk", body: [
                .paragraph("Tap the Survey tab → Start Survey. Choose a room label, then tap Begin. The app samples RSSI from nearby Thread devices every few seconds and tags each sample with GPS coordinates."),
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
                .paragraph("Open a saved survey → tap the share icon to export a CSV file with all sample points: timestamp, latitude, longitude, and RSSI."),
            ]),
        ]),

        .init(title: "AI Features", topics: [
            .init(title: "Overview", icon: "sparkles", body: [
                .paragraph("ThreadMapper's AI features use Apple's on-device FoundationModels framework (iOS 26+) with Apple Intelligence. All analysis happens entirely on your device — no data is sent to any server."),
                .paragraph("AI features require: iOS 26, an Apple Intelligence-capable device (iPhone 16 or later), and Apple Intelligence enabled in Settings → Apple Intelligence & Siri."),
                .tip("All AI features degrade gracefully — if Apple Intelligence is unavailable, the UI shows a clear explanation rather than an error."),
            ]),
            .init(title: "AI Insights", icon: "brain", body: [
                .paragraph("The AI Insights tab runs several on-device analyses in parallel: Mesh Summary (plain-English overview), Predictive Analysis (forward-looking risk assessment), Optimization Plan (ranked action cards with impact level), Root Cause Analysis (when 2+ devices degrade simultaneously), and Mesh Expansion Advisor (up to 2 placement suggestions)."),
            ]),
            .init(title: "Network Assistant Chat", icon: "bubble.left.and.bubble.right.fill", body: [
                .paragraph("Tap \"Network Assistant\" in AI Insights to open a conversational chat interface pre-loaded with live context about your mesh. Responses stream in token by token with a blinking cursor. Suggested question chips appear below the input bar."),
                .tip("The assistant remembers conversation context within a session. Open a new session to start fresh."),
            ]),
            .init(title: "Root Cause Analysis", icon: "arrow.triangle.branch", body: [
                .paragraph("When 2 or more devices are simultaneously declining or critical, a Root Cause card appears in AI Insights showing the hypothesised shared cause, list of affected devices, confidence level, and recommended fix."),
            ]),
            .init(title: "Mesh Expansion Advisor", icon: "plus.circle.fill", body: [
                .paragraph("The Mesh Expansion Advisor suggests up to 2 specific placement improvements, each with: suggested location, recommended device type, reason this location needs a device, and expected benefit."),
            ]),
            .init(title: "AI Weekly Digest", icon: "calendar", body: [
                .paragraph("When Weekly Reports are enabled in Settings, ThreadMapper sends a Sunday morning notification with an AI-written one-sentence summary of the past week's network health. Falls back to a generic summary if Apple Intelligence is unavailable."),
            ]),
            .init(title: "AI Activity Digest", icon: "text.bubble", body: [
                .paragraph("A purple sparkles card at the top of the Activity Feed summarises the 10 most recent events in 2 sentences. See the Activity Feed chapter for full details."),
            ]),
            .init(title: "Proactive AI Insights Push", icon: "bell.badge.fill", body: [
                .paragraph("When critical anomalies appear on your network, ThreadMapper can send a proactive push notification with an AI-written headline. Enable this in Settings → Notifications → Proactive AI Insights. Requires iOS 26 and Apple Intelligence."),
            ]),
        ]),

        .init(title: "Advanced Tools", topics: [
            .init(title: "Smart Home Advisor", icon: "wand.and.stars", body: [
                .paragraph("The Smart Home Advisor (accessible from AI Insights or Settings → Tools) analyses your Thread topology and activity history to generate three categories of suggestions:"),
                .bullets([
                    "Placement Suggestions — recommends adding or moving devices to improve mesh coverage",
                    "Automation Suggestions — proposes HomeKit automations based on your device mix and usage patterns",
                    "Scene Recommendations — suggests logical scenes for rooms with multiple controllable devices",
                ]),
            ]),
            .init(title: "Resilience Simulator", icon: "shield.lefthalf.filled", body: [
                .paragraph("The Resilience Simulator (Mesh → Tools) models the impact of losing any border router or routing node. Results are grouped by severity: Critical (red), High (orange), Low (green). Tap any node card to see the exact devices that would be affected."),
                .tip("Use this before decommissioning a device to understand the knock-on effect on your mesh."),
            ]),
            .init(title: "Channel Interference Scanner", icon: "waveform.badge.wifi", body: [
                .paragraph("The Channel Interference Scanner (Mesh → Tools) displays a spectrum bar chart for Thread channels 11–26. Each bar is coloured by Wi-Fi overlap risk (red/orange/green). Wi-Fi band zones are shaded on the background. Active Thread channels are marked with an in-use indicator. The recommended channel is marked with a ★."),
            ]),
            .init(title: "Border Router Health Monitor", icon: "antenna.radiowaves.left.and.right.slash", body: [
                .paragraph("The Border Router Health Monitor (Mesh → Tools) shows a status card for each border router: online/offline badge, RSSI sparkline, last-seen timestamp, \"Only BR\" warning (if it's the sole border router), and critical offline warning."),
                .warning("If you have only one border router and it shows a critical offline warning, your entire Thread mesh has lost its connection to Wi-Fi and the internet."),
            ]),
            .init(title: "New Device Alert", icon: "bell.and.waves.left.and.right", body: [
                .paragraph("When enabled in Settings → Notifications → New Device Alerts, ThreadMapper sends a \"New Thread Device Detected\" push notification whenever a device joins your network that hasn't been seen before."),
                .tip("Useful for detecting unauthorised commissioning or confirming that a newly purchased device has successfully joined."),
            ]),
        ]),

        .init(title: "Notifications", topics: [
            .init(title: "Alert Types", icon: "bell.badge", body: [
                .paragraph("ThreadMapper can send several categories of push notification:"),
                .bullets([
                    "Offline device alert — fires when a device has been unreachable longer than the configured grace period",
                    "Device back online — fires when the last offline device recovers",
                    "Grade change — fires when your mesh health grade letter improves or degrades",
                    "New device detected — fires when an unknown device joins your Thread network",
                    "Proactive AI insights — fires when critical anomalies are detected (iOS 26, Apple Intelligence required)",
                ]),
                .paragraph("Enable or disable each type individually in Settings → Notifications."),
            ]),
            .init(title: "Positive Notifications", icon: "checkmark.circle.fill", body: [
                .paragraph("ThreadMapper sends notifications for good news too:"),
                .bullets([
                    "Grade improved — fires when your health grade letter moves up (e.g. C → B)",
                    "All devices online — fires when the last previously-offline device comes back online",
                ]),
                .tip("Positive notifications are suppressed during Quiet Hours like all other alerts."),
            ]),
            .init(title: "Offline Grace Period", icon: "timer", body: [
                .paragraph("Devices can briefly drop off HomeKit's radar for innocent reasons (firmware update, power cycle). The grace period delays the offline alert to avoid false alarms:"),
                .bullets([
                    "30 seconds — fastest alerts, more false positives",
                    "1 minute (default) — balanced",
                    "2 or 5 minutes — fewer alerts, slower notification",
                ]),
            ]),
            .init(title: "Quiet Hours", icon: "moon.fill", body: [
                .paragraph("Enable Quiet Hours in Settings to suppress all notifications during a nightly window. Set a start time and end time; the window can cross midnight (e.g. 10 PM – 7 AM). Notifications that would have fired during quiet hours are silently discarded."),
            ]),
        ]),

        .init(title: "Widget & System Integration", topics: [
            .init(title: "Adding the Widget", icon: "rectangle.3.group", body: [
                .paragraph("ThreadMapper provides a medium Home Screen widget. Long-press your Home Screen → tap the + button → search for \"ThreadMapper\" → choose the medium size → tap Add Widget."),
            ]),
            .init(title: "What the Widget Shows", icon: "rectangle.and.text.magnifyingglass", body: [
                .paragraph("The widget displays a snapshot taken during the last background refresh: current health grade and score, online/total device count, and a timestamp."),
                .tip("iOS controls how often background refreshes occur. The widget updates at most every 15 minutes under normal conditions."),
            ]),
            .init(title: "Interactive Widget Refresh", icon: "arrow.clockwise.circle", body: [
                .paragraph("The medium widget includes a circular refresh button (↻) in the \"Updated\" row. Tapping it opens ThreadMapper and triggers an immediate foreground refresh, then reloads the widget timeline."),
            ]),
            .init(title: "Lock Screen Widget", icon: "lock.rectangle", body: [
                .paragraph("ThreadMapper also provides a Lock Screen (accessory inline) widget that shows your current health grade letter and score in a compact single-line format. Add it via Customise Lock Screen."),
            ]),
            .init(title: "Live Activities", icon: "dot.radiowaves.left.and.right", body: [
                .paragraph("When a device goes offline beyond the grace period, ThreadMapper starts a Live Activity showing the grade and offline count in the Dynamic Island, and a health summary on the Lock Screen. The Live Activity ends automatically 10 seconds after all devices come back online."),
            ]),
            .init(title: "Control Center", icon: "switch.2", body: [
                .paragraph("ThreadMapper adds a \"Thread Network\" button to Control Center (iOS 18+). Tapping it opens ThreadMapper directly. Add it via Settings → Control Center → Thread Network."),
            ]),
            .init(title: "Siri Shortcuts", icon: "mic", body: [
                .paragraph("ThreadMapper registers Siri App Shortcuts available immediately after install: \"Check my Thread network\" (reads out your grade and device count) and \"Show offline devices\" (opens the app focused on offline devices)."),
            ]),
        ]),

        .init(title: "Pro Features", topics: [
            .init(title: "What's Included in Pro", icon: "star.fill", body: [
                .paragraph("ThreadMapper Pro unlocks:"),
                .bullets([
                    "30-Day Health History — chart and trend analysis beyond the free 24-hour window",
                    "Mesh Resilience Score — shows which single device failure would partition your mesh",
                    "Health Streaks — tracks consecutive Grade A days",
                    "Weekly Reports — AI-narrated plain-English summaries delivered every Sunday",
                    "Siri Shortcuts — check your network without opening the app",
                ]),
            ]),
            .init(title: "Purchasing Pro", icon: "creditcard", body: [
                .paragraph("Tap the Pro badge anywhere in the app. Two subscription options are available: Monthly (billed each month, cancel any time) and Annual (billed once per year, typically ~40% less). Payment is charged to your Apple ID. Manage or cancel in iOS Settings → Apple ID → Subscriptions."),
            ]),
            .init(title: "Restoring Purchases", icon: "arrow.clockwise", body: [
                .paragraph("If you reinstall the app or switch to a new iPhone, tap Restore Purchases on the paywall screen. Your subscription is tied to your Apple ID and will be restored automatically at no charge."),
            ]),
        ]),

        .init(title: "Settings Reference", topics: [
            .init(title: "Border Router (Advanced)", icon: "server.rack", body: [
                .paragraph("If you run an OpenThread Border Router, enter its REST API URL here (e.g. http://192.168.1.50:8081). Apple HomePod and Google Nest border routers do not expose this API — leave the field blank if you use only those."),
                .tip("Tap Test Connection after entering the URL to verify ThreadMapper can reach the OTBR before saving."),
            ]),
            .init(title: "New Device Alerts", icon: "bell.badge.plus", body: [
                .paragraph("Toggle \"New Device Alerts\" in Settings → Notifications to enable or disable push notifications when an unknown device joins your Thread network."),
            ]),
            .init(title: "Proactive AI Insights", icon: "sparkle", body: [
                .paragraph("Toggle \"Proactive AI Insights\" in Settings → Notifications to enable AI-generated push notifications when critical anomalies are detected. Requires iOS 26 and Apple Intelligence."),
            ]),
            .init(title: "Weekly Report", icon: "calendar.badge.clock", body: [
                .paragraph("Enable Weekly Reports in Settings to receive a Sunday morning notification summarising the past week's network health. The headline is AI-written on iOS 26+ and falls back to a generic summary on older devices."),
            ]),
            .init(title: "Demo Mode", icon: "play.rectangle", body: [
                .paragraph("Demo Mode replaces real HomeKit discovery with a simulated Thread network of 8 devices. Restart the app after toggling Demo Mode for the change to take effect."),
            ]),
            .init(title: "Data Management", icon: "internaldrive", body: [
                .paragraph("Settings → Data contains destructive-clear actions for three local stores: Signal History, Health Score History, and Activity Feed."),
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
                .paragraph("A device shown as offline means HomeKit reported it unreachable. Common causes: power outage or device unplugged; firmware update in progress (usually resolves in 1–2 minutes); Thread mesh partitioned — check that a border router is online; device too far from nearest Thread router."),
            ]),
            .init(title: "AI Features Not Showing", icon: "brain.slash", body: [
                .paragraph("If AI Insights or other AI sections are missing:"),
                .bullets([
                    "Check that your device is an iPhone 16 or later",
                    "Ensure you are running iOS 26 or later",
                    "Go to Settings → Apple Intelligence & Siri and confirm Apple Intelligence is enabled",
                    "If the model is still downloading, wait a few minutes and return to AI Insights",
                ]),
            ]),
            .init(title: "Widget Not Updating", icon: "rectangle.badge.xmark", body: [
                .paragraph("If the widget shows a very stale timestamp: open ThreadMapper (triggers a foreground refresh and reloads the widget timeline); check that Background App Refresh is enabled in iOS Settings → General → Background App Refresh; disable Low Power Mode if active."),
            ]),
            .init(title: "Survey Samples All Grey", icon: "location.slash", body: [
                .paragraph("Grey dots mean no Thread device signal was detectable at that location. Expected if you are too far from any Thread device, the device is a Sleepy End Device that polls infrequently, or the room has significant RF shielding (concrete, metal framing)."),
            ]),
            .init(title: "Resetting Everything", icon: "arrow.counterclockwise", body: [
                .paragraph("To start fresh: clear all three stores in Settings → Data, then delete and reinstall the app. Your HomeKit home, devices, and Apple ID subscription are unaffected."),
            ]),
        ]),

    ] // swiftlint:enable function_body_length
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
        case .paragraph(let key):
            Text(key)
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, key in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(key)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .tip(let key):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .frame(width: 20)
                Text(key)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.yellow.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        case .warning(let key):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 20)
                Text(key)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.orange.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
