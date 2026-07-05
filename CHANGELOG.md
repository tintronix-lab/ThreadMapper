# Changelog

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
