# ThreadMapper

**Thread mesh network monitor for iOS 17+** — visualizes HomeKit Thread devices, measures response quality, surveys coverage room-by-room, and alerts you when devices go offline. On iOS 26+ with Apple Intelligence, it adds on-device AI diagnostics and a conversational network assistant.

---

## Free vs Pro

ThreadMapper's core monitoring is free. **ThreadMapper Pro** (a one-time purchase — no subscription) unlocks advanced diagnostics, AI features, and power-user tools.

| | Free | Pro |
|---|:---:|:---:|
| Network health grade + score | ✓ | ✓ |
| Device list + signal sparklines | ✓ | ✓ |
| Mesh graph visualization | ✓ | ✓ |
| Activity feed (7 days) | ✓ | ✓ |
| Offline + topology notifications | ✓ | ✓ |
| Live Activity & Dynamic Island | ✓ | ✓ |
| Home-screen widget | ✓ | ✓ |
| Apple Watch app | ✓ | ✓ |
| Apple Watch guided-survey remote | ✓ | ✓ |
| Troubleshooter | ✓ | ✓ |
| Channel Scanner | ✓ | ✓ |
| Border Router Health Monitor | ✓ | ✓ |
| Survey + heatmap | ✓ | ✓ |
| Device notes | ✓ | ✓ |
| Device Uptime Leaderboard | ✓ | ✓ |
| Notification quiet hours | ✓ | ✓ |
| 30-Day history timeline | — | ✓ |
| Resilience Simulator | — | ✓ |
| Topology Time-Lapse Rewind | — | ✓ |
| Diagnostic PDF Export | — | ✓ |
| Weekly Network Report | — | ✓ |
| Health Streaks | — | ✓ |
| HomeKit Scene Triggers | — | ✓ |
| Router Saturation Monitor | — | ✓ |
| Watch face complications | — | ✓ |
| Smart Home Advisor | — | ✓ |
| AI Insights *(iOS 26+)* | — | ✓ |
| Network Assistant *(iOS 26+)* | — | ✓ |
| Predictive failure prevention *(iOS 26+)* | — | ✓ |
| Maintenance Calendar *(iOS 26+)* | — | ✓ |
| Self-Healing Insights *(iOS 26+)* | — | ✓ |
| Commissioning Coach *(iOS 26+)* | — | ✓ |
| NL Device Queries *(iOS 26+)* | — | ✓ |
| Alert Urgency Scoring *(iOS 26+)* | — | ✓ |
| Weekly Health Coach *(iOS 26+)* | — | ✓ |
| Anomaly Pattern Recognition *(iOS 26+)* | — | ✓ |
| AI Troubleshooter *(iOS 26+)* | — | ✓ |
| Network Storyteller *(iOS 26+)* | — | ✓ |

---

## Features

### Dashboard
- **Network health grade** (A–F, 0–100 score) computed from device count, offline/weak ratios, and border-router presence
- **24-hour health history** chart (Charts framework)
- **Per-room health grid** — grade cards (A–F) for every HomeKit room; tap a card to filter the device list to that room
- **Room coverage** summary with per-room signal grades
- **Issue + tip cards** — critical issues flagged in red, recommendations in amber
- **Placement suggestions** — rooms with poor average signal flagged for router addition
- **30-minute signal trend** sparkline across all devices
- **Topology change banner** — shows devices that joined or left the mesh in the last 5 minutes
- **Topology Change Digest** *(Pro)* — on cold launch after a gap of more than 1 hour, a sheet summarises topology changes since the last session; AI-narrated for Pro + iOS 26 users
- **Diagnostic PDF Export** *(Pro)* — 3-page PDF (grade summary, device inventory, recommendations) generated on-device via `UIGraphicsPDFRenderer`; accessible from the Dashboard toolbar
- **Weekly report** *(Pro)* — auto-generated weekly summary card with grade distribution, stability score, streak tracking, and shareable plain-text export
- **Health streaks** *(Pro)* — tracks consecutive Grade A days and longest streak

### Devices
- Per-device **signal sparkline** with live/avg/min/max stats and quality distribution bar
- **Device health grade** (A–F) from rolling signal history
- **Role badges** — Border Router, Router, End Device, Sleepy End Device
- **Battery level** with low-battery warning and **radio efficiency score** (transmit efficiency estimate for Sleepy End Devices)
- **Mesh path view** — visual hop-by-hop path from the device to the internet
- **Survey history** and CSV export per device
- **Device notes** — persistent, debounced (one write per pause, not per keystroke)
- **Troubleshooter** — guided step-by-step fix flow for offline and weak-signal devices, role-aware steps
- **Device filter** — filter device list by role, room, or signal quality
- **Device Uptime Leaderboard** — ranked 30-day online-percentage chart; identifies the most and least reliable devices at a glance
- **Device reliability score** — 30-day offline event count and online streak (days since last offline event)

### Mesh Graph
- **Hierarchical room-based layout** visualizing logical device topology
- Room zone cards group devices by HomeKit room
- Cross-room links rendered as arcs; backbone links as dashed straight lines
- Filter by room or Thread channel
- Tap a node to open device detail; selected node highlights its route to the internet
- **Map export** *(Pro)* — share a full-resolution PNG of the current mesh graph

### Network Diagnostics Tools
- **Border Router Health Monitor** — per-BR card with uptime, signal, and single-point-of-failure warning when only one BR is present
- **Router Saturation Monitor** *(Pro)* — per-router child-device load with progress bars and an overload warning at 80% capacity
- **Channel Scanner** — Thread channel spectrum view (channels 11–26 / 2.4 GHz) showing devices per channel with Wi-Fi interference risk ratings (high/medium/low)
- **Resilience Simulator** *(Pro)* — select any border router or router and simulate its failure; shows severity (critical / moderate / low) and which devices would be orphaned; AI impact narration for Pro + iOS 26 users
- **Anomaly Detector** — background service that flags unusual signal degradation patterns and surfaces them as activity events
- **Topology Time-Lapse Rewind** *(Pro)* — up to 720 mesh snapshots recorded in a ring buffer (50-minute dedup); playback with a timeline scrubber from Mesh → Tools

### AI Insights *(Pro · iOS 26+ · Apple Intelligence required)*
- **Mesh health summary** — plain-English headline + explanation + single top action, generated on-device
- **Predictive analysis** — up to three at-risk device alerts with 24-hour stability outlook
- **Predictive failure prevention** — OLS linear trend projects hours-to-failure per device; triangle warning in Device Detail
- **Optimization plan** — ordered list of actionable improvements for the current topology
- **Root cause hypothesis** — when issues are detected, explains likely cause and suggested fix
- **Mesh expansion plan** — recommends where to add routers or border routers based on coverage gaps
- **Self-Healing Insights** — auto-generated maintenance recommendations based on recurring patterns in device history
- **Maintenance Calendar** — AI-generated task list grouped by Today / This week / This month
- **Alert Urgency Scoring** *(AI-D2)* — every offline alert is scored 1–10 on-device; low-urgency blips are suppressed, high-urgency failures fire with an AI-written context subtitle
- **Weekly Health Coach** *(AI-D5)* — personalised 1–3 action coaching plan shown at the top of the Weekly Report; each action has title, rationale, expected grade gain, and effort level
- **Anomaly Pattern Recognition** *(AI-D4)* — names the specific failure pattern for degrading devices (e.g. "Gradual Hardware Fade") with evidence points, distinguishing feature, and targeted fix; shown in Device Detail
- **AI Troubleshooter** *(AI-D7)* — device-specific step-by-step guide generated from actual history, anomaly data, and cross-session memory; appears above the static steps in Troubleshooter
- **Network Storyteller** *(AI-D10)* — 30-day narrative in four parts (opening, key events, current chapter, outlook) shown in Network Timeline
- Graceful fallback UI when Apple Intelligence is disabled, device is ineligible, or model is downloading

### Network Assistant *(Pro · iOS 26+ · Apple Intelligence required)*
- **Conversational chat interface** — ask free-form questions about your mesh in plain English
- **Streaming responses** — answers appear word-by-word as the on-device model generates them
- **Suggested questions** — quick-tap prompts to get started
- **Device-focused mode** — launched from Device Detail to ask questions scoped to a specific device
- **Natural language device queries** — search Mesh list in plain English ("show me battery-powered devices in the bedroom with weak signal")
- **Contextual metric explanation** — long-press any signal stat or hop count to get a plain-English explanation
- Full mesh context (devices, signal history, activity log, diagnostic report) injected into every session

### Smart Home Advisor *(Pro)*
- **Placement suggestions** — room-by-room recommendations for adding Thread routers based on signal data
- **Automation suggestions** — Thread-aware automation ideas derived from the current device topology
- **Scene recommendations** — suggested HomeKit scenes based on device roles and coverage patterns

### Survey
- **Guided room-by-room survey** — walk each room, capture response-quality samples tagged to the room; controllable from Apple Watch (Start / Done / Skip)
- **Free-walk survey** — continuous sampling with GPS for outdoor or large-space mapping
- **Heatmap overlay** — color-coded signal strength across surveyed points
- Survey sessions stored with room tag; viewable per-device in Device Detail
- CSV export of survey data
- Location permission requested at survey start, not app launch

### Activity Feed
- Chronological log of device offline/online events, topology changes, health score shifts ≥ 15 points, and anomaly detections
- **AI Activity Digest** *(Pro · iOS 26+)* — 2-sentence AI summary of recent events at the top of the feed
- Events persist for 7 days (max 500), grouped by day
- Clear-all action in toolbar

### Live Activity & Dynamic Island
- **Offline alert Live Activity** — starts automatically when a device goes offline; shows device name, offline count, grade, and score on the Lock Screen and in the Dynamic Island
- User-dismissable via the Dynamic Island; suppresses re-creation until all devices recover
- Ends automatically when all devices come back online

### Notifications & Monitoring
- **Offline device push notifications** with configurable grace period (30 s – 5 min)
- **Topology change notifications** when devices join or leave the mesh
- **Badge count** = number of confirmed offline devices; cleared on recovery
- **Background Health Watchdog** — `BGProcessingTask` runs a grade-drop check while the app is suspended and fires a local notification when the grade letter falls
- **Background refresh** task keeps the widget current when the app is closed
- Poll loop pauses while the app is backgrounded; resumes immediately on foreground

### Widget
- Home-screen widget showing grade, score, device count, offline count, and per-room summary
- Widget reloads throttled (content-diffed, 60 s minimum interval) to stay within WidgetKit budget

### Apple Watch Companion *(watchOS 10+)*
- **Watch app** — a custom grade ring (grade + score), a colour-coded status line, and full-width Devices / Offline tiles, all fitting on a single screen (no scrolling); ships its own hub-and-spokes app icon
- **Guided Survey remote** — control the room-by-room survey from your wrist: **Start / Done / Skip** the current room with live progress and a recording timer, synced with the phone in real time. Remote-control model — the phone's Guided Survey screen stays open (it owns the sampling)
- **Live sync** via WatchConnectivity `updateApplicationContext` — the Watch receives the latest health snapshot every time it changes on the phone, even when the Watch is not currently reachable
- **Haptic alert** — notification haptic fires on the watch when a border router transitions to offline
- **Watch face complications** *(Pro)* — three WidgetKit complication families:
  - `accessoryCircular` — grade letter + progress arc in a Gauge; shows offline count when > 0
  - `accessoryInline` — "Thread A · 8 devices" (or offline count if any)
  - `accessoryRectangular` — grade letter, score/100, device count, and offline count

### Settings
- Toggle offline and topology notifications
- Configurable offline grace period
- **OpenThread Border Router URL** — point ThreadMapper at a local OT-BR HTTP API for richer diagnostics
- **HomeKit Scene Triggers** *(Pro)* — run a HomeKit scene automatically when network health drops to a chosen grade threshold (C / D / F)
- Clear signal history, health score history, and activity feed independently
- Setup Checklist accessible from Settings → Tools

### iPad Support
- **NavigationSplitView** sidebar layout on iPad (regular horizontal size class)
- Same tab destinations as iPhone; sidebar selection drives the detail column

### Deep Links
- `threadmapper://dashboard` — jump to Dashboard
- `threadmapper://mesh` — jump to Mesh Graph
- `threadmapper://activity` — jump to Activity Feed
- `threadmapper://device/<uuid>` — open a specific device's detail sheet
- `threadmapper://dismiss-live-activity` — end the current Live Activity (used by Live Activity button)

---

## Architecture

```
Sources/
  ThreadMapper/         # Main app — views, view models, services, models
    Models/             # ThreadDevice, SurveyPoint, ActivityEvent, MeshNode/Link
    ViewModels/         # MeshViewModel (poll loop), SurveyViewModel
    Services/           # MatterDiscoveryService, DeviceStatsStore, ActivityStore,
                        # HealthHistoryStore, DeviceNotesStore, AppGroupStore,
                        # SurveySessionManager, NotificationService,
                        # LiveActivityManager, SmartHomeAdvisor,
                        # AINetworkAnalyzer (FoundationModels; split into
                        #   .swift / +Types / +Prompts / +Topology),
                        # AnomalyDetector, ResilienceSimulator,
                        # KnownDeviceRegistry, WeeklyReportStore,
                        # BorderRouterClient, NetworkDiagnosticsEngine,
                        # GuidedSurveyBridge (Watch survey remote)
    Views/              # DashboardView, MeshGraphView, SurveyWalkView,
                        # DeviceDetailView (+MeshPath), ActivityFeedView,
                        # TroubleshooterView, SettingsView, OnboardingFlow,
                        # AIInsightsView, NetworkAssistantView,
                        # SmartHomeAdvisorView, BRHealthMonitorView,
                        # ChannelScannerView, ResilienceSimulatorView,
                        # WeeklyReportView, AppChecklistView, …
    Utils/              # NetworkHealthScore, MeshTopologyBuilder, GraphLayout,
                        # PersistedStore, SignalStrength extensions
  ThreadMapperApp/      # App entry point, ContentView, BackgroundRefreshHandler
  Shared/               # WidgetSnapshot, TMStyle (grade colors, room icons),
                        # ThreadNetworkActivityAttributes (Live Activity)
  ThreadMapperWidget/   # WidgetKit extension (iOS)
  ThreadMapperWatch/    # Apple Watch app (watchOS 10+) — dashboard +
                        # GuidedSurveyControlView (survey remote), own AppIcon
  ThreadMapperWatchWidget/ # Watch face complications (WidgetKit, watchOS)
```

**Key design decisions:**
- `@Observable` throughout — no Combine
- Device identity is the HomeKit `uniqueIdentifier` everywhere — stats, activity events, notifications, and overrides all key on it; `ThreadDevice.id` (SwiftUI `Identifiable`) is a computed alias of it so the two can never diverge
- Persistence: debounced JSON files via `Codable` (Documents directory), centralized through `PersistedStore`
- AI features use `FoundationModels` (`SystemLanguageModel.default`) — fully on-device, no network calls
- Signal values are **latency-derived response quality estimates**, not radio-measured RSSI — labeled as "estimated" in the UI
- Topology links are **logical estimates** (non-BR devices linked to nearest border router) — not from Thread diagnostics
- Resilience and channel analysis are **computed from cached HomeKit data** — not live radio measurements

---

## Build & Run

**Requirements:** Xcode 26+, iOS 17+ device or simulator, HomeKit-enabled home for real data.  
**AI features** (AI Insights, Network Assistant) additionally require iOS 26+ and an Apple Intelligence-eligible device (iPhone 16 or later).

The Xcode project is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen) and goes stale whenever a source file is added or renamed — regenerate before building.

```bash
brew install xcodegen
xcodegen generate
open ThreadMapper.xcodeproj
```

```bash
# Build for a connected device via xcodebuild
xcrun xcodebuild \
  -project ThreadMapper.xcodeproj \
  -scheme ThreadMapper \
  -destination 'id=<device-udid>' \
  -configuration Debug build
```

> **Use `ThreadMapper.xcodeproj`, not `.swiftpm/xcode/package.xcworkspace`.** The SPM
> workspace exposes only the `ThreadMapper` *library* product — it has no app target,
> so it produces object files rather than an installable `.app`, under a different
> bundle identifier. `swift build` / `swift test` likewise cannot build this package:
> it depends on HomeKit and UIKit, which exist only on iOS. Use `make build` and
> `make test` (both drive an iOS simulator through `xcodebuild`).

---

## Data Honesty

| What you see | What it actually is |
|---|---|
| Signal strength / dBm | Latency-derived quality estimate (HomeKit round-trip time bucketed to a −55…−92 scale) |
| Mesh graph links | Logical estimate — every non-border-router linked to the nearest border router |
| Channel interference risk | Static classification of Thread channels by known Wi-Fi 2.4 GHz overlap — not a live radio scan |
| Resilience simulator impact | Graph-connectivity analysis on cached topology — not a live failure test |
| Parent node | Populated only if HomeKit exposes it (rare) |

Real Thread diagnostics (true RSSI, LQI, actual parent/child links) require the Matter Thread Network Diagnostics cluster, which Apple's HomeKit APIs do not currently expose for third-party apps. Connecting an OpenThread Border Router via its HTTP API (Settings → Border Router URL) provides richer data where available.

---

## Privacy

- HomeKit device inventory and survey location data stored locally in the app's Documents directory
- App Group data shared with the widget contains only aggregate counts (grade, score, device count) — no device names or coordinates
- AI Insights and Network Assistant run entirely on-device via Apple Intelligence; no data leaves the device
- Location used only during surveys; permission requested at survey start
- No analytics, no remote telemetry
