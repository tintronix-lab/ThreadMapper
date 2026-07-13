# Changelog

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
