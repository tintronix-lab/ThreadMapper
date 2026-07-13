# ThreadMapper

**Thread mesh network monitor for iOS 17+** — visualizes HomeKit Thread devices, measures response quality, surveys coverage room-by-room, and alerts you when devices go offline.

---

## Features

### Dashboard
- **Network health grade** (A–F, 0–100 score) computed from device count, offline/weak ratios, and border-router presence
- **24-hour health history** chart (Charts framework)
- **Room coverage** summary with per-room signal grades
- **Issue + tip cards** — critical issues flagged in red, recommendations in amber
- **Placement suggestions** — rooms with poor average signal flagged for router addition
- **30-minute signal trend** sparkline across all devices
- **Topology change banner** — shows devices that joined or left the mesh in the last 5 minutes

### Devices
- Per-device **signal sparkline** with live/avg/min/max stats and quality distribution bar
- **Device health grade** (A–F) from rolling signal history
- **Role badges** — Border Router, Router, End Device, Sleepy End Device
- **Battery level** with low-battery warning
- **Survey history** and CSV export per device
- **Device notes** — persistent, debounced (one write per pause, not per keystroke)
- **Troubleshooter** — guided step-by-step fix flow for offline and weak-signal devices, role-aware steps

### Mesh Graph
- **Hierarchical room-based layout** visualizing logical device topology
- Room zone cards group devices by HomeKit room
- Cross-room links rendered as arcs; backbone links as dashed straight lines
- Filter by room or Thread channel
- Tap a node to open device detail; selected node highlights its route to the internet

### Survey
- **Guided room-by-room survey** — walk each room, capture response-quality samples tagged to the room
- **Free-walk survey** — continuous sampling with GPS for outdoor or large-space mapping
- **Heatmap overlay** — color-coded signal strength across surveyed points
- Survey sessions stored with room tag; viewable per-device in Device Detail
- CSV export of survey data
- Location permission requested at survey start, not app launch

### Activity Feed
- Chronological log of device offline/online events, topology changes, and health score shifts ≥ 15 points
- Events persist for 7 days (max 500), grouped by day
- Clear-all action in toolbar

### Notifications & Monitoring
- **Offline device push notifications** with configurable grace period (30 s – 5 min)
- **Topology change notifications** when devices join or leave the mesh
- **Badge count** = number of confirmed offline devices; cleared on recovery
- **Background refresh** task keeps the widget current when the app is closed
- Poll loop pauses while the app is backgrounded; resumes immediately on foreground

### Widget
- Home-screen widget showing grade, score, device count, offline count, and per-room summary
- Widget reloads throttled (content-diffed, 60 s minimum interval) to stay within WidgetKit budget

### Settings
- Toggle offline and topology notifications
- Configurable offline grace period
- Clear signal history, health score history, and activity feed independently
- Setup Checklist accessible from Settings → Tools

---

## Architecture

```
Sources/
  ThreadMapper/         # Main app — views, view models, services, models
    Models/             # ThreadDevice, SurveyPoint, ActivityEvent, MeshNode/Link
    ViewModels/         # MeshViewModel (poll loop), SurveyViewModel
    Services/           # MatterDiscoveryService, DeviceStatsStore, ActivityStore,
                        # HealthHistoryStore, DeviceNotesStore, AppGroupStore,
                        # SurveySessionManager, NotificationService
    Views/              # DashboardView, MeshGraphView, SurveyWalkView,
                        # DeviceDetailView, ActivityFeedView, TroubleshooterView,
                        # SettingsView, OnboardingFlow, AppChecklistView, …
    Utils/              # NetworkHealthScore, MeshTopologyBuilder, GraphLayout,
                        # SignalStrength extensions
  ThreadMapperApp/      # App entry point, ContentView, BackgroundRefreshHandler
  Shared/               # WidgetSnapshot, TMStyle (grade colors, room icons)
  ThreadMapperWidget/   # WidgetKit extension
```

**Key design decisions:**
- `@Observable` throughout — no Combine
- Persistence: debounced JSON files via `Codable` (Documents directory)
- Signal values are **latency-derived response quality estimates**, not radio-measured RSSI — labeled as "estimated" in the UI
- Topology links are **logical estimates** (non-BR devices linked to nearest border router) — not from Thread diagnostics

---

## Build & Run

**Requirements:** Xcode 26+, iOS 17+ device or simulator, HomeKit-enabled home for real data.

```bash
# Open the SPM workspace in Xcode
open .swiftpm/xcode/package.xcworkspace

# Build for a connected device via xcodebuild
xcrun xcodebuild \
  -workspace .swiftpm/xcode/package.xcworkspace \
  -scheme ThreadMapper \
  -destination 'id=<device-udid>' \
  -configuration Debug build
```

---

## Data Honesty

| What you see | What it actually is |
|---|---|
| Signal strength / dBm | Latency-derived quality estimate (HomeKit round-trip time bucketed to a −55…−92 scale) |
| Mesh graph links | Logical estimate — every non-border-router linked to the nearest border router |
| Parent node | Populated only if HomeKit exposes it (rare) |

Real Thread diagnostics (true RSSI, LQI, actual parent/child links) require the Matter Thread Network Diagnostics cluster, which Apple's HomeKit APIs do not currently expose for third-party apps.

---

## Roadmap

See [REVIEW.md](REVIEW.md) for the full technical-lead review and feature backlog.

---

## Privacy

- HomeKit device inventory and survey location data stored locally in the app's Documents directory
- App Group data shared with the widget contains only aggregate counts (grade, score, device count) — no device names or coordinates
- Location used only during surveys; permission requested at survey start
- No analytics, no remote telemetry
