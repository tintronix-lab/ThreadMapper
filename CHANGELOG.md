# Changelog

## 1.3.0 (2026-07-23)

### Added

**Apple Watch Companion** *(watchOS 10+)*
- **Watch app** — new `ThreadMapperWatch` target; shows a Gauge grade ring, device count, offline count, and a relative "last updated" timestamp
- **Live sync** via `WCSession.updateApplicationContext` — `WatchConnectivityManager` (iPhone side) sends grade, score, device count, offline count, and border-router-offline flag on every health change; `WatchConnectivityStore` (Watch side) applies updates and replays the last known context on activation
- **Haptic alert** — `WKInterfaceDevice.play(.notification)` fires when a border router transitions from reachable to offline
- **Watch face complications** — new `ThreadMapperWatchWidget` extension with three WidgetKit families:
  - `accessoryCircular` — Gauge arc tinted by grade color; offline count badge when > 0
  - `accessoryInline` — "Thread A · 8 devices" (or offline count if non-zero)
  - `accessoryRectangular` — grade letter, score/100, device count, and offline count
- Complications read `WidgetSnapshot` from the shared App Group (`group.com.tintronixlab.ThreadMapper`) — zero additional battery or network overhead

---

## 1.2.0 (2026-07-23)

### Added

**Dashboard**
- **Per-Room Health Grid** — grade cards (A–F) for every HomeKit room at a glance; tap a room card to filter the device list to that room
- **Topology Change Digest** — on cold launch after a gap of more than 1 hour, a sheet summarises devices that joined, left, or changed role since the last session; iOS 26 Pro users get an AI-written plain-English narration of the changes
- **Diagnostic PDF Export** — "Export Diagnostic PDF" in the Dashboard toolbar generates a 3-page PDF (cover + grade summary, device inventory, recommendations) via `UIGraphicsPDFRenderer`

**Mesh Tools**
- **Topology Time-Lapse Rewind** — records up to 720 mesh snapshots (50-minute dedup) in a ring buffer (`TopologyTimeLapseStore`); accessible from Mesh → Tools as a full-screen scrubber with play/pause and a timeline slider; persisted across launches as JSON

**Border Router Health Monitor**
- **Router Saturation Monitor** — `RouterSaturationSection` shows per-router child-device load with a progress bar; triggers an overload warning at 80% capacity; accessible inside the existing BR Health Monitor view

**Settings → Tools**
- **HomeKit Scene Triggers** — choose a health-grade threshold (C / D / F) and a HomeKit scene to run automatically when the network drops to or below that grade; `HomeKitSceneTriggerStore` persists the toggle, grade, and selected scene via `@AppStorage`

**Devices**
- **Battery Radio Efficiency Score** — shown in the battery section of Device Detail for Sleepy End Devices; estimates transmit efficiency as a ratio of battery percentage to signal quality

**Notifications**
- **Background Health Watchdog** — `BGProcessingTask` (`com.threadmapper.healthwatch`) runs a grade-drop check while the app is suspended and fires a local "Network health degraded" notification when the grade letter drops; registered in Info.plist under both `UIBackgroundModes` and `BGTaskSchedulerPermittedIdentifiers`

### Fixed
- **HomeKitSceneTriggerView white screen** — `@State private var store = HomeKitSceneTriggerStore.shared` triggered an iOS 26 actor-isolation crash when SwiftUI evaluated the NavigationLink destination off the main actor; replaced with a computed-property accessor and `@Bindable` inside `body`/`@ViewBuilder` sections
- **Network Assistant localization** — suggested questions and error messages were stored as plain `String` literals, bypassing SwiftUI's locale resolution; replaced with `String(localized:)` so Swedish and future translations apply at runtime

---

## 1.1.0 (2026-07-19)

### Added

**Network Diagnostics (new engine + full view)**
- `NetworkDiagnosticsEngine` — background analysis pass producing a structured `Report` (issues, tips, scores, partition detection)
- **Mesh path view** in Device Detail — hop-by-hop path from the selected device to the internet
- **Thread channel analysis** — per-channel spectrum with Wi-Fi 2.4 GHz interference risk ratings (high / medium / low) for channels 11–26
- **Failure Impact Analysis** — shows which devices would be orphaned if a selected border router or router went offline
- **Signal Degradation view** — surface devices with deteriorating rolling-average signal over the last 24 h
- **Topology Baseline Comparison** — snapshot the current topology and diff against a saved baseline to catch silent drift
- **Network Partition Detection** — flags mesh segments unreachable from any border router
- **Room Signal History sparklines** in the diagnostics view per room
- **Diagnostic Run History** — scored trend chart of past diagnostic passes
- **Mesh Quality Scorecard** — four-dimension fitness breakdown (coverage, resilience, balance, border-router health)
- **OTBR Thread Dataset Inspector** — decode and display the active Thread dataset from an OpenThread Border Router
- **Commissioning Readiness Check** — verifies prerequisites before adding a new device (BR present, channel stable, partition-free)
- **Expandable fix instructions** on each diagnostic recommendation
- **Network Timeline** — full-screen health-score chart with activity-event markers
- **Share Diagnostic Report** — plain-text export of the current diagnostic pass

**Device Detail enhancements**
- **Commissioning timeline** — Matter commissioning history per device
- **Live OTBR neighbor table** — real-time neighbor data pulled from Border Router when configured
- **Vendor notes** — pre-populated notes for known device models (via `KnownDeviceRegistry`)
- **Hop-count depth indicator** in the mesh list view

**New tools (accessible from the Tools menu / diagnostics hub)**
- **Border Router Health Monitor** — per-BR card with signal history, uptime, and single-point-of-failure warning
- **Channel Scanner** — interactive spectrum view of all Thread channels with device counts and interference risk
- **Resilience Simulator** — tap any border router or router to see which devices it protects and how severe a failure would be (critical / moderate / low)
- **Smart Home Advisor** — placement suggestions, automation ideas, and scene recommendations derived from the current topology

**AI Insights** *(iOS 26+ · Apple Intelligence)*
- On-device mesh health summary, predictive device-risk analysis, optimization plan, root-cause hypothesis, and mesh expansion plan via `FoundationModels`
- Graceful unavailability states for Apple Intelligence disabled, device ineligible, or model downloading

**Network Assistant** *(iOS 26+ · Apple Intelligence)*
- Conversational chat interface with streaming on-device responses
- Suggested-question chips; device-scoped mode launchable from Device Detail

**Live Activity / Dynamic Island**
- Starts automatically when a device goes offline; shows device name, offline count, grade, and score on the Lock Screen and in the Dynamic Island
- User-dismissable; suppresses re-creation until full recovery

**Platform & navigation**
- **iPad NavigationSplitView** — sidebar layout on regular horizontal size class; landscape orientation supported
- **User Manual** linked from Settings → About
- **Firmware tracking** — records firmware versions over time with a per-device history view; HAP characteristic fallback for devices that don't advertise firmware via Matter
- **Deep link scheme** (`threadmapper://`) — dashboard, mesh, activity, device/<uuid>, dismiss-live-activity

**Localization**
- Swedish added as a supported language

### Fixed
- Firmware section was always visible even when no firmware data was available; now hidden until at least one entry is present
- HAP characteristic read fell through to an empty string instead of the fallback value when the characteristic was present but unreadable
- Weak-device substring matching false positives carried forward from 0.2.0 (e.g. "Hub" matching "Hub 2") — corrected in channel and diagnostic queries

### Internals
- `PersistedStore` base class centralises debounced JSON persistence across all stores; eliminates duplicated load/save boilerplate
- `AnomalyDetector` service flags unusual signal-degradation patterns and posts them as `ActivityEvent`s
- `LiveActivityManager` encapsulates all ActivityKit lifecycle; guarded by `#available(iOS 16.2, *)`
- `ResilienceSimulator` and `SmartHomeAdvisor` are pure value-type services with no external dependencies
- Production-hardening pass: strict-concurrency clean on all new files, `@MainActor` propagated through diagnostics engine, deduplication of repeated store reads on the poll loop

---

## 1.0.0 (2026-07-13) — Initial App Store Release

### Fixed
- **Background refresh never fired** — `UIBackgroundModes: fetch` was missing from Info.plist; BGAppRefreshTask is now scheduled by the OS as intended
- **Widget timestamp duplication** — "Updated 2 minutes ago ago" (`Text.DateStyle.relative` already appends directional context; removed the extra literal)
- **Widget "0 seconds ago"** — sub-60-second snapshots now show "Updated just now"
- **Paywall infinite spinner** — product load failure left a permanent `ProgressView`; now shows "Couldn't load products / Try Again"
- **Silent purchase errors** — IAP failures (network, payment declined) were swallowed via `try?`; surfaced via alert
- **HealthHistoryStore UUID crash** — `Entry.id` was a computed `Date` property causing `List` identity conflicts on iOS 17; migrated to stable `UUID` with backwards-compatible JSON decoder
- **Onboarding Skip button** hidden behind `#if DEBUG` in release builds; removed the guard
- **Device join/leave false positives** — topology diffing now keys on `uniqueIdentifier` (UUID) instead of device name; renames no longer appear as leave+join events
- **Aggregate recompute on every tick** — aggregates and widget snapshot are now only recomputed when topology or RSSI actually changed (was O(n) every second)

### Added
- **Confetti animation** on network grade improvement — 60-particle `Canvas` animation at 60 fps; respects `accessibilityReduceMotion`
- **Spotlight indexing** — Thread devices are indexed via `CoreSpotlight` whenever the device graph changes; searchable from Spotlight with room, role, and type keywords
- **Siri Shortcuts** — "Check my Thread network" and "Show offline devices" App Intents readable without opening the app

### Accessibility
- `GradeRingView` now has a combined VoiceOver label ("Network health grade A, score 85 out of 100") instead of two disconnected strings
- Confetti animation hidden from VoiceOver (`accessibilityHidden`)
- Dynamic Type: 25 hardcoded font sizes replaced with scaled text styles across 5 files

### Test coverage
- 70 tests across 14 suites: `ActivityStore`, `AchievementStore`, `DeviceNotesStore`, `DeviceOverrideStore`, `DeviceStats`, `GraphLayout`, `HealthHistory`, `HealthStreak`, `MeshTopology`, `MeshViewModel`, `NotificationService`, `SignalExtrapolator`, `SurveyHeatmap`, `ThreadDiagnostics`, `WeeklyReportStore`

### Internals
- Swift strict-concurrency warnings fully resolved; `StrictConcurrency` enforced in `Package.swift`
- `@MainActor` on `MeshViewModel`; `@unchecked Sendable` on `ThreadDevice`, discovery services, and diagnostics providers
- `DiscoveryService` and `DiagnosticsProvider` protocols now `: Sendable`

## 0.2.0 (2026-07-05)

Technical-lead review pass (see REVIEW.md for the full report and roadmap).

### Fixed
- Widget timelines reloaded every second, exhausting the WidgetKit budget — snapshot writes are now content-diffed with a 60 s reload floor
- Saved-survey list and counts didn't refresh on save/delete (`savedPoints` was excluded from observation)
- Device renames, room moves, and battery changes never propagated to the UI (equality was identity-only; poll loop now diffs metadata signatures)
- Survey samples without a GPS fix were silently tagged with Apple Park coordinates; sessions with no fix at all are now discarded instead of fabricated
- CSV export files were written to disk on every SwiftUI render
- Weak-device lookups used substring matching ("Hub" matched "Hub 2")
- Signing team typo in project.yml broke generated-project code signing
- Survey map used a different RSSI color scale than the rest of the app
- Device notes were persisted on every keystroke (now debounced)
- Location permission was requested at app launch; now requested when a survey starts

### Added
- `room` on survey points — guided surveys tag sessions with the surveyed room
- Setup Checklist reachable from Settings
- Shared TMStyle (grade colors, room icons) for app + widget
- Poll loop pauses while the app is backgrounded
- "Estimated" labeling for latency-derived signal values
- Working GitHub Actions CI (xcodegen + xcodebuild test on iOS simulator)

### Corrections
- 0.1.0 notes claimed SwiftData persistence and a CI workflow; persistence is JSON-file-based and CI lands in this release

## 0.1.0 (2026-07-02)
- Initial skeleton: models, services, views
- SwiftData persistence
- Force-directed mesh layout
- HomeKit discovery stub + HMHomeManager integration
- Tests for topology + layout + signals
- CI workflow + dev scripts
