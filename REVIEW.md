# ThreadMapper — Technical Lead Review & Product Roadmap

**Date:** 2026-07-05 · **Scope:** full codebase (~5,600 LOC Swift, iOS 17+) · **Reviewer role:** incoming tech lead / product strategist

---

## Executive Summary

ThreadMapper is a genuinely promising utility: it visualizes and diagnoses Thread/Matter mesh networks — a real pain point with almost no consumer tooling (competitors: Eve app's Thread view, Apple's nothing). The codebase is clean modern SwiftUI (`@Observable`, Swift Charts, WidgetKit, BGTasks) with good instincts: debounced persistence, grace periods for offline alerts, a troubleshooter, widgets.

Three things stand between this and a shippable product:

1. **Data honesty.** The app displays latency-derived estimates as "dBm" RSSI and a star topology as the mesh. Users with real Thread knowledge will notice immediately; this undermines the entire value proposition. Reframe as "Response Quality" and "logical topology" until real data sources exist.
2. **A battery-drain defect**: the 1-second poll loop calls `WidgetCenter.reloadAllTimelines()` every second (fixed in this review — see §8).
3. **GPS-based indoor surveying doesn't work indoors.** ±10–30 m GPS error makes the heatmap noise at room scale. The guided room-by-room survey is the right model — it should become the primary survey, keyed by room, not coordinates.

---

## Phase 1 — Product Understanding

**Problem solved.** Smart-home users with Thread devices (HomePod/Apple TV border routers + Eve/Nanoleaf/etc. accessories) have zero visibility into mesh health. When a sensor drops off, there's no tool that says *why* or *where the coverage hole is*. ThreadMapper answers: how healthy is my mesh, which devices are weak/offline, where are the dead zones, and what should I do about it.

**Target users** (inferred from HomeKit dependency and troubleshooter copy): prosumer Apple-ecosystem smart-home owners, 5–50 devices, comfortable in the Home app but not RF engineers. Secondary: smart-home installers doing site walks (the CSV export hints at this).

**Primary journeys.**
1. *Health check*: open app → Dashboard grade → issues + tips → done in 10 s.
2. *Diagnose a problem device*: Dashboard → device row → detail (signal history, grade) → Troubleshooter steps.
3. *Coverage survey*: Survey tab → walk rooms (guided or free) → heatmap + weak spots → placement suggestions.
4. *Ambient monitoring*: widget on home screen, offline push notifications, activity feed.

**Strengths of the current implementation.**
- Journey coverage is remarkably complete for v0.1: dashboard, graph, survey, activity, widgets, notifications, background refresh, troubleshooter, onboarding.
- Modern stack used correctly in most places: `@Observable`, `Canvas`, Swift Charts, `SpatialTapGesture`, App Group + WidgetKit, BGAppRefreshTask.
- Thoughtful details: offline grace period (configurable), debounced JSON persistence, notification badges cleared on recovery, per-device quality distribution, accessibility labels on device rows.
- The Troubleshooter is the best product thinking in the app — role-specific, step-ranked, honest hints.

**Missing capabilities.** Real Thread topology (no parent/child links — HomeKit doesn't expose them; Thread Network Diagnostics via Matter could), room-based (not GPS-based) surveying as the primary flow, iPad/landscape support, data export beyond CSV, historical trends beyond 24 h, multi-home support, localization, App Store privacy manifest.

**Technical debt (headline items, full list in Phase 2).** Fake link topology presented as real; pseudo-RSSI presented as dBm; device identity keyed by mutable `name` in four stores; three duplicated `roomIcon`/`gradeColor` implementations; two duplicated haversine implementations; `JSONSerialization` hand-rolled persistence beside `Codable` stores; unused code (`RoomFilterView`, `LiveDiscoveryService` protocol, `Extrapolator.roomCoordinate` fake coordinates, `ThreadMapperError`); `AppChecklistView` built but unreachable from any navigation path; CHANGELOG claims SwiftData and CI workflow — neither exists.

**UX/UI weaknesses.** Onboarding copy is developer-facing ("SwiftUI, SwiftData, and HomeKit/Matter") and factually wrong (no SwiftData, no Bluetooth); location permission fires at app launch instead of contextually at survey start; the mesh graph re-randomizes layout on membership changes; portrait-only + `UIRequiresFullScreen` wastes iPad; heavy reliance on 8–10 pt fixed fonts defeats Dynamic Type; survey shows raw lat/lng coordinates to users.

**Performance bottlenecks.** `reloadAllTimelines()` every second (critical, fixed); CSV files written to disk on every SwiftUI render of `DeviceDetailView`/`SurveyWalkView` (fixed); 1 Hz MainActor loop recomputing health + room grouping + snapshot encode even when idle; O(n²)×300 force layout on the main thread.

**Security & privacy concerns.** Precise home coordinates + device inventory in plaintext JSON in Documents (no `.completeFileProtection`); CSV exports leak home coordinates with no user warning; missing `PrivacyInfo.xcprivacy` (App Store rejection risk); device names interpolated into notification IDs and file names unsanitized.

**Scalability limits.** Single-home assumption (`accessoryCache` merges all homes); stores keyed by device name collide across homes and break on rename; polling all characteristics of all accessories every 5 s scales poorly past ~50 devices (HomeKit will throttle); everything is a singleton, so none of it is testable or isolatable.

---

## Phase 2 — Code Review (ranked)

### High

| # | Issue | Location | Detail |
|---|-------|----------|--------|
| H1 | `WidgetCenter.reloadAllTimelines()` called ~every second | `MeshViewModel` loop → `AppGroupStore.writeSnapshot` | WidgetKit budget exhaustion; iOS throttles reloads and penalizes the app; battery drain. **Fixed** (§8): snapshot writes now diffed + 60 s min reload interval. |
| H2 | Metadata changes never propagate | `MeshViewModel` poll: `if latest != self.devices` | `ThreadDevice.==` compares only `uniqueIdentifier`, so renames, room moves, battery changes never trigger `devices = latest`. UI shows stale names/rooms forever until membership changes. |
| H3 | `savedPoints` is `@ObservationIgnored` | `SurveyViewModel` | Deleting rows in `SavedSurveyList`, saving a session, or `savedPointCount` in headers do not refresh the UI. **Fixed** (§8). |
| H4 | Estimated values presented as measured dBm | `MatterDiscoveryService.latencyRSSI`, all views | Latency buckets mapped to fake dBm (−55…−92) and labeled "dBm", "Via HomeKit latency" only appears in one caption. Product-integrity issue; rename to Response Quality score (roadmap S1). |
| H5 | Fake star topology presented as the mesh | `MeshTopologyBuilder` | Every non-BR device linked to the *first* border router with invented link quality; `parentNodeID` never populated. Label the view "logical topology (estimated)" or derive better structure (S2). |
| H6 | Device identity keyed by mutable `name` | `DeviceStatsStore`, `ActivityStore`, notifications, `SurveyViewModel.weakDevices` | Rename in Home app → history orphaned, offline-state tracking resets, notification clear misses. Two same-named devices (multi-home) collide. Key by `uniqueIdentifier`. |
| H7 | Disk writes during SwiftUI render | `DeviceDetailView.surveySection`, `SurveyWalkView.exportActions` | `exportCSV(for:)` writes a temp file on **every render** (~1 Hz while polling). **Fixed** (§8): generated once per appearance. |
| H8 | Substring match on weak-device names | `SurveyViewModel.surveys(for:)`, `focus(for:)`, `exportCSV(for:)` | `weakDevices.contains(deviceID)` is a substring test on a comma-joined string: "Hub" matches "Hub 2". **Fixed** (§8): exact match on split list. |
| H9 | Fabricated location data | `SurveySessionManager.recordSample` | Apple Park coordinates silently injected into real survey data when no fix exists. Poisons heatmap and exports. Drop the sample or mark it location-less instead. |
| H10 | Signing broken in generated project | `project.yml` → `signing.team: QCSX955Y7Pi` | Trailing `i` typo (vs `QCSX955Y7P` used elsewhere). Xcodegen output won't sign. **Fixed** (§8). |
| H11 | Graph hit-testing wrong when zoomed | `MeshGraphView.handleTap` | Tap location isn't divided by `scale` (scaleEffect anchors at center); node taps miss increasingly as zoom departs from 1.0. Pan speed also varies with zoom (offset applied pre-scale). |
| H12 | Mesh graph invisible to VoiceOver | `MeshGraphView` Canvas | No accessibility elements for nodes/links. The core visualization is unusable for assistive tech; needs `accessibilityChildren` or a rotor-navigable overlay. |
| H13 | `swift test`/`make ci` cannot pass as documented | `Package.swift` declares macOS 14 | `import HomeKit` and `UIColor` don't exist on macOS; the documented SPM test loop is broken. CI must run `xcodebuild test` on an iOS simulator; CHANGELOG claims a CI workflow that doesn't exist. |

### Medium

| # | Issue | Detail |
|---|-------|--------|
| M1 | 1 Hz MainActor loop always runs | `MeshViewModel.init` starts an infinite task before onboarding finishes and regardless of scene phase; recomputes health, room groups, snapshot encode every second even backgrounded. Gate on `scenePhase` and lengthen idle cadence. |
| M2 | Magic sentinel `-100 == offline`, `-92 == read-failed` | Encode reachability as an enum (`.offline`, `.estimated(quality)`) instead of overloading Int RSSI. Eliminates `?? -65` / `?? -120` inconsistencies (both defaults appear in different files). |
| M3 | Inconsistent RSSI→color scales | `SignalStrength` (green/mint/orange/red, breaks at −50/−65/−80) vs `SurveyMapView.rssiColor` (green/**yellow**/orange/red, reversed comparisons) vs `DeviceStats.qualityBuckets` (boundary `<= -50` vs `< -50`). Same reading renders different colors on different screens. Partially fixed (§8: SurveyMapView now uses the shared scale). |
| M4 | `roomIcon` ×3, `gradeColor` ×3, haversine ×2 | Duplicated in Dashboard/GuidedSurvey/Widget and SurveyHeatmapPresenter/Extrapolator. Move to `Sources/Shared`. |
| M5 | Location permission at launch | `SurveySessionManager` (created with `SurveyViewModel` in `ContentView`) constructs `LocationTracker`, whose `init` calls `requestWhenInUseAuthorization()`. Request it when a survey starts. |
| M6 | `AppChecklistView` unreachable | Built, polished, never linked from any tab or navigation. **Fixed** (§8): linked from Settings. |
| M7 | Onboarding copy wrong | References SwiftData and Bluetooth; neither is used. **Fixed** (§8). |
| M8 | Guided survey discards room identity | Each room's session saves a `SurveyPoint` with GPS coords but no `room` field — the one piece of reliable indoor position data is thrown away. Add `room: String?` to `SurveyPoint` (S1). |
| M9 | Background task fragility | `ReachabilityChecker` polls `HMHomeManager` ≤8 s; `NotificationService.isAuthorized` loads async so early BG notifications may silently drop; `BGTaskScheduler.submit` failure swallowed by `try?`. |
| M10 | `dedupedSavedPoints()` masks a bug | Dedup by timestamp+coords implies duplicate saves occur somewhere; also `SavedSurveyList` deletes by *deduped* index against the *raw* array → wrong row deleted when dupes exist. |
| M11 | Unsanitized names in file paths & notification IDs | `threadmapper_survey_\(deviceID)_…csv` breaks with "/" in device names; CSV fields not quote-escaped (name with `"` corrupts row). |
| M12 | `NetworkHealthScore.compute` in view body | Recomputed several times per render at 1 Hz; move to the view model, compute once per poll (it's already computed there for the snapshot — reuse it). |
| M13 | Portrait-only, `UIRequiresFullScreen`, no iPad layout | The graph and heatmap are exactly the views that want landscape/iPad. |
| M14 | Missing `PrivacyInfo.xcprivacy` + file protection | Location + home inventory stored/exported without protection or declaration; App Store requires the manifest. |
| M15 | Note persistence per keystroke | `DeviceDetailView.notesSection` `onChange` → `setNote` → synchronous disk write on every character. Debounce like the other stores. |
| M16 | `LiveDiscoveryService` protocol declared, never conformed to | `MatterDiscoveryService` doesn't adopt it; no seam for a mock, which is why the poll loop and views are untestable. |

### Low

- `Extrapolator.roomCoordinate` returns hardcoded fake coordinates for three room names — dead/placeholder logic; `clusterDevices` unused.
- `RoomFilterView` unused (two other room-filter implementations exist inline).
- `ThreadMapperError` defined, thrown nowhere.
- `SurveyViewModel.exportURLForCurrentSessionPerDevice()` exports only the *first* weak device — semantics unclear, unused.
- `HealthHistoryStore.Entry.id = timestamp` — duplicate timestamps (clock adjustments) break `Identifiable`.
- `GuidedSurveyView` chips use `ForEach(id: \.offset)` — fine, but room list mutation mid-survey shifts indices.
- Two app icon asset catalogs (`Sources/ThreadMapper` + repo-root `ThreadMapper/`) — one is stale.
- `verify_*.swift` scripts duplicate test logic already covered by XCTest.
- Widget "Updated X ago" uses `.relative` style which renders "in 0 sec" edge cases; use `Text(date, style: .timer)` conventions carefully.
- `.swiftlint.yml` disables `force_unwrapping`… no — it *opts in*; good. But `empty_count` disabled while `values.min()!` force-unwraps survive in `DeviceStatsStore.stats` (guarded, acceptable).
- Onboarding "Skip" is `#if DEBUG` only — release users must page through all three screens.

**Test coverage:** 4 files / ~110 lines covering pure functions only. No tests for `MeshViewModel` polling, offline transitions, persistence round-trips, `NetworkHealthScore` scoring rules, or `SurveyHeatmapPresenter`. The scoring model — the product's core promise — has zero tests.

---

## Phase 3 — Feature Brainstorm (72 ideas)

**Core diagnostics & data quality**
1. Room-based survey as primary flow (drop GPS indoors) · 2. Matter Thread Network Diagnostics cluster integration (real parent/child topology, real RSSI/LQI where exposed) · 3. Response Quality Score (honest latency-based 0–100 metric replacing fake dBm) · 4. Historical uptime % per device (30-day) · 5. Channel-conflict scanner with actual Wi-Fi scan correlation (via NEHotspotNetwork) · 6. Border-router failover test ("unplug drill" guided check) · 7. Sleepy-device battery forecasting from drain curve · 8. Mesh resilience score (articulation-point analysis: which single device failure partitions the mesh) · 9. Latency percentiles (p50/p95) per device, not just mapped buckets · 10. Network change diff view ("what changed since yesterday").

**AI-powered**
11. Natural-language network assistant ("why is my bedroom sensor flaky?") over local telemetry · 12. Anomaly detection on response-time series (on-device, CreateML) · 13. Placement optimizer: suggest *where* to add a router given room survey data · 14. Auto-generated plain-English weekly health report · 15. Smart troubleshooter that orders steps by learned fix-success rates · 16. Device-name entity resolution across renames · 17. Predictive offline alerts ("Eve Door has degraded 3 days running — likely to drop off").

**Surveys & visualization**
18. Floor-plan canvas: user sketches rooms, drags devices onto it, heatmap renders over the plan · 19. RoomPlan (LiDAR) import to auto-generate the floor plan · 20. AR signal overlay (ARKit ruler-style walk) · 21. Time-lapse playback of mesh health over 24 h · 22. Before/after survey comparison (did adding a router help?) · 23. 3D multi-floor view · 24. Pinch-to-compare two devices' sparklines · 25. Export heatmap as image/PDF report.

**Monitoring & notifications**
26. Live Activity during survey walks · 27. Smart notification digests (one summary, not N pushes) · 28. Quiet hours · 29. Escalation rules (notify only if offline >X and it's a security device) · 30. StandBy mode dashboard · 31. Apple Watch complication + app (glanceable grade) · 32. Critical-device pinning (never suppress alerts for locks) · 33. Webhook/Shortcuts trigger on network events.

**Automation & integrations**
34. App Intents: "Hey Siri, how's my Thread network?" · 35. Shortcuts actions (Get Health Score, Get Offline Devices) → user automations · 36. Home Assistant companion export · 37. HomeKit automation suggestions ("this motion sensor is flaky — add a condition") · 38. Matter multi-admin awareness (show which fabrics devices belong to) · 39. Eve/Nanoleaf deep links to vendor apps for firmware updates · 40. Calendar/log export (ICS of outages) · 41. MQTT/CSV/JSON scheduled exports for tinkerers.

**Collaboration & social**
42. Shared household reports (send monthly PDF to family) · 43. Installer mode: multi-site profiles, client report generation, branded PDF export · 44. Anonymous community benchmarks ("your mesh is healthier than 70% of homes with 20+ devices") · 45. Publicly shareable network scorecard image (privacy-scrubbed) · 46. Support hand-off bundle (diagnostics zip for vendor support tickets).

**Premium / monetization**
47. Free: dashboard + 1 border router + 7-day history. Pro (subscription or one-time): unlimited history, floor plans, installer mode, exports, Watch app · 48. Pro trial triggered contextually (first weak-spot detection) · 49. Family Sharing support · 50. Tip jar alternative for goodwill.

**Gamification & delight**
51. Health streaks ("14 days at Grade A") · 52. Achievement set (First Survey, Dead-Zone Slayer, Full Coverage) · 53. Confetti when grade improves to A after user acts on a tip · 54. Animated mesh "pulse" visualization (packets rippling through links) · 55. Yearly "Network Wrapped" recap · 56. App icon variants unlocked by streaks.

**Productivity & UX**
57. Spotlight indexing of devices (search "kitchen sensor" from home screen) · 58. Universal search inside app (devices, rooms, events) · 59. Bulk device notes/tags (e.g., "flaky batch") · 60. Custom device grouping beyond rooms (zones: upstairs/downstairs) · 61. Snooze a device's alerts · 62. Onboarding sample/demo mode with simulated network (crucial for App Store review + users without Thread devices) · 63. In-app glossary (what is a border router / SED / channel) · 64. Multi-home switcher.

**Accessibility & platform**
65. Full VoiceOver graph navigation (audio graph of mesh) · 66. Dynamic Type audit + large-text layouts · 67. iPad split-view layout (graph left, detail right) · 68. macOS Catalyst/native for installers · 69. Haptic signal-strength feedback during survey walks (Geiger-counter mode — walk and *feel* coverage) · 70. Localization (DE/FR/JP smart-home markets are large).

**Developer/admin tools**
71. Hidden debug menu (simulated devices, forced states, snapshot inspector) · 72. Structured logging with `os.Logger` + in-app log viewer for support.

---

## Phase 4 — Prioritization

**Must Have** — table stakes for a credible v1.0:

| Feature | Value | Complexity | Effort | Depends on | Risks |
|---|---|---|---|---|---|
| 3. Honest Response Quality score | Trust — the product's foundation | Low | 2–3 d | — | Users liked "dBm"; messaging matters |
| 1. Room-based survey primary | Makes surveys actually work indoors | Med | 1 wk | M8 (room on SurveyPoint) | Migration of old GPS points |
| 62. Demo mode | App Review + empty-state users | Low–Med | 3 d | Discovery seam (M16) | Must be clearly labeled |
| H2/H6 fixes: identity + change propagation | Correctness of everything downstream | Med | 3 d | — | Store migration keyed name→UUID |
| 27–29. Notification digests/quiet hours | Stops uninstall-driving spam | Low | 3 d | — | — |
| 66. Dynamic Type + a11y audit | Baseline quality, App Store featuring | Med | 1 wk | — | Fixed-size Canvas labels |
| Privacy manifest + file protection (M14) | App Store requirement | Low | 1 d | — | — |
| CI that actually runs (H13) | Everything else | Low | 1–2 d | xcodegen in CI | Simulator flakiness |

**Should Have** — differentiation:

| Feature | Value | Complexity | Effort | Depends on | Risks |
|---|---|---|---|---|---|
| 18. Floor-plan canvas + heatmap | The "wow" screen; screenshot-driver | High | 3–4 wk | Room survey data | Drawing UX scope creep |
| 2. Matter diagnostics topology | Real mesh links = real product | High | 3–4 wk (research-heavy) | Matter.framework entitlements | Apple API exposure limited; may only work for directly-commissioned fabrics |
| 34–35. App Intents + Shortcuts | Ecosystem stickiness, Siri | Low–Med | 1 wk | Stable health API | — |
| 31. Watch complication | Ambient value, retention | Med | 2 wk | Snapshot pipeline | Another target to maintain |
| 26. Live Activity survey | Modern polish | Low–Med | 3 d | Survey refactor | — |
| 4/21. Uptime history + time-lapse | Diagnosing intermittent issues | Med | 1–2 wk | Store schema (SwiftData migration) | Storage growth |
| 47. Pro tier + paywall | Sustainability | Med | 2 wk | Features above | Price positioning (premium: $19.99/yr or $29.99 lifetime) |
| 8. Resilience score | Unique insight nobody else offers | Low (graph theory on existing data) | 3 d | Real links preferred | Misleading if topology still fake |

**Nice to Have:** 51–56 (gamification: streaks/confetti/Wrapped), 57–58 (Spotlight/search), 60–61 (zones, snooze), 24–25 (compare, PDF export), 69 (haptic Geiger mode — cheap and delightful: 2 d), 39 (vendor deep links), 63 (glossary), 30 (StandBy).

**Future Vision:** 19–20 (RoomPlan + AR overlay — the long-term moat: "the app that shows Thread coverage on a scan of your actual house"), 43 (installer/B2B mode — a second revenue line with different willingness-to-pay), 44 (community benchmarks — network effects), 11–17 (AI layer once telemetry is rich), 68 (macOS for installers), 36 (Home Assistant bridge to escape the HomeKit data ceiling).

---

## Phase 5 — Implementation Roadmap

**Sprint 1 — Truth & Stability (this review starts it).** Fix H1–H10 (perf defect, reactivity, identity keying, fabricated data, signing). Rename dBm → Response Quality across UI. Add `room` to `SurveyPoint`. Rewire onboarding copy + contextual location permission. Ship CI (xcodegen + `xcodebuild test` on simulator) with the existing tests green. *Why first:* every later feature builds on data integrity, device identity, and a working pipeline; shipping features on top of H2/H6 would multiply migration pain.

**Sprint 2 — Survey that Works + Demo Mode.** Room-first guided survey (per-room scores, room history), retire GPS as default (keep as advanced/outdoor option), demo network behind a `DiscoveryService` protocol (also unblocks testing), empty states everywhere, delete-flow correctness (M10). *Why:* survey is the app's most differentiated journey and currently its least trustworthy; demo mode is required for App Review and for the 95% of downloads who open the app before buying Thread gear.

**Sprint 3 — Real Topology & Intelligence.** Matter diagnostics spike (timeboxed 1 wk: determine what Apple actually exposes), resilience score, uptime history, predictive/degradation alerts, notification digests + quiet hours. *Why here:* needs Sprint 1's identity model; research risk is contained by the spike; even if Matter data is thin, resilience + uptime ship on existing data.

**Sprint 4 — Performance & Platform.** Scene-phase-aware polling (pause in background, slow when idle), move force layout off main thread (`Task.detached` + incremental animation), adaptive iPad/landscape layouts, Watch complication + App Intents. *Why:* optimization after behavior is settled; platform breadth right before the marketing push.

**Sprint 5 — Polish & Production.** Accessibility completion (VoiceOver graph, Dynamic Type), floor-plan canvas v1, Live Activity, paywall + Pro tier, privacy manifest + App Store assets, localization scaffolding, structured logging + crash reporting (MetricKit). *Why last:* monetization lands on a product that has earned it; a11y and floor plan are the review-magnet features for launch.

---

## Phase 6 — UX & Design Improvements

**Navigation.** Five tabs is one too many: fold Activity into Dashboard (bell icon with badge → sheet). Promote the Checklist as "Setup" inside Settings (done in §8) and surface it contextually when health < C. Adopt `TabView` + `NavigationSplitView` on iPad: sidebar (Dashboard/Mesh/Survey), detail pane.

**Visual hierarchy & typography.** The Dashboard leads with the grade ring — correct — but issues, tips, trend, history, rooms, placement, devices creates an 8-section scroll with equal visual weight. Collapse to: Hero (grade + top issue + primary action button), Rooms, Devices; move trend/history behind a "Trends" segment. Replace the fixed 7–10 pt fonts with `.caption2`/`.footnote` text styles so Dynamic Type works; the grade ring number should use `.rounded` semantic sizes.

**Color.** Four-tier scale is good; `mint` vs `green` is nearly indistinguishable in bright light and for deuteranopes — switch tiers to green/teal/orange/red, add SF Symbol shape redundancy (checkmark/wave/exclamation) everywhere color carries meaning. One canonical scale (see M3) documented in a DesignTokens file.

**Motion.** The grade ring animates score changes — extend that language: number ticker on score, spring-in for new activity rows, subtle link "pulse" traveling from border router outward on scan complete (the memorable wow moment; Canvas time-based animation, cheap). Respect `accessibilityReduceMotion`.

**Empty & loading states.** Good copy exists; unify into one `ContentUnavailableView`-based component with an illustration and a single primary action ("Open Home App" deep link `com.apple.home://`). During first discovery, show a skeleton dashboard (shimmering grade ring) instead of a spinner row.

**Onboarding.** Replace the segmented-picker oddity with paged `TabView` + page dots; rewrite copy user-first ("See every Thread device", "Find dead zones", "Get alerts when things drop off"); add permission priming screens that explain *why* before triggering HomeKit and notification prompts; end on a "Scan now" CTA that lands on Dashboard already scanning. Ship the demo mode entry here ("No Thread devices yet? Explore a sample home").

**Survey flow.** Kill visible lat/lng coordinates everywhere (users think in rooms, not `37.33461`); guided walk becomes the default CTA ("Survey My Home", per-room 30 s countdown with haptic ticks); free-walk demoted to "Advanced". Heatmap gets room-bucketed bars (Room × score) rather than a pseudo-map of GPS noise. The completion card should show *results* (best room, worst room, one suggestion), not just "saved".

**Wow moments.** (1) Post-survey reveal: rooms animate onto a coverage card sorted by score with a shareable summary. (2) Geiger-counter haptics while walking. (3) "Fixed it" loop: after a troubleshooter success, the grade ring visibly climbs with confetti — closes the emotional loop of the core journey.

**Mobile/tablet/desktop.** iPhone: support landscape for graph + heatmap. iPad: split view, pointer hover states on nodes (hover HUD), keyboard shortcuts (⌘R rescan). Desktop-class (future Catalyst): multi-window — graph in one window, device detail in another, for installers.

---

## Phase 7 — Engineering Improvements

**Architecture.** Introduce three seams, keep the rest simple:

```
┌────────────┐   protocol    ┌──────────────────┐   writes   ┌─────────────┐
│ SwiftUI    │ ◄──────────── │ NetworkMonitor    │ ─────────► │ Stores      │
│ Views      │  @Observable  │ (poll loop, owns  │            │ (SwiftData) │
└────────────┘               │  transitions)     │            └─────────────┘
                             └────────┬─────────┘
                                      │ protocol DiscoveryService
                        ┌─────────────┴─────────────┐
                        │ HomeKitDiscovery │ DemoDiscovery │ (future) MatterDiagnostics
                        └───────────────────────────┘
```

- Extract the 170-line poll loop from `MeshViewModel.init` into a `NetworkMonitor` actor owning transitions (offline grace, topology diff, snapshot). ViewModels become thin projections. This is the single highest-leverage refactor: it makes offline/topology logic unit-testable and kills the singleton web (`MatterDiscoveryService.shared`, four store singletons) via constructor injection through one `AppDependencies` value in the environment.
- Adopt the already-declared `LiveDiscoveryService` protocol (rename `DiscoveryService`); conform HomeKit impl; add `DemoDiscoveryService` — unblocks demo mode, previews, and tests simultaneously.
- Replace four hand-rolled JSON stores + `JSONSerialization` survey persistence with SwiftData (`@Model SurveyPoint` already half-implied by CHANGELOG). One migration, then history features (uptime, trends) come nearly free via queries.

**Reliability & error recovery.** Replace `try?` swallowing in persistence and BGTask submission with `os.Logger` categories (`discovery`, `persistence`, `bg`) + user-visible degradation where it matters (a "storage full" banner beats silent data loss). Sentinel RSSI values → `enum Reachability { case offline; case quality(Int) }`.

**Concurrency.** The poll loop mixes `[weak self]`, `MainActor.run` blocks, and unprotected caches (`deviceIDCache`, `accessoryCache` touched from delegate + task group). Annotate `MatterDiscoveryService` `@MainActor` (HomeKit delegates are main-thread anyway) and let `measureSignalQualities` take an immutable snapshot (it already does — formalize it). `NetworkMonitor` as an actor removes the rest.

**Performance.** Scene-phase gating (pause polling when backgrounded — currently burns CPU until suspension); snapshot diffing (done, §8); run force layout off-main with positions applied in one animation; memoize `NetworkHealthScore` per poll tick instead of per render.

**Testing strategy.** Unit: `NetworkHealthScore` rule table (parameterized), offline grace-period transitions via injected clock, persistence round-trips, heatmap presenter. Snapshot tests for widget views. One UI smoke test on the demo service (launch → dashboard shows grade). Target: the scoring and transition logic at ~90%, views opportunistically.

**CI/CD.** Add `.github/workflows/ci.yml`: macOS runner → `brew install xcodegen swiftlint` → generate → `xcodebuild test -destination 'iOS Simulator'` → SwiftLint as a separate job. Later: TestFlight lane via fastlane, release-please changelog automation (fixes the aspirational CHANGELOG problem).

**Observability & analytics.** `os.Logger` + MetricKit crash/hang collection now (zero dependencies). If/when analytics: privacy-first (TelemetryDeck), events limited to feature usage — never network contents. Document this in the privacy manifest.

**Security.** `.completeFileProtection` on all stores; strip precise coordinates from CSV by default (opt-in "include location" toggle with a warning); sanitize device names for filenames; App Group data reviewed for the widget (snapshot is aggregate-only — good, keep it that way).

**Documentation.** README currently lists internal build paths from another machine (`/Users/MAC/Projects/ThreadMapper`) — replace with relative instructions; fix CHANGELOG false claims; add `ARCHITECTURE.md` with the diagram above and a "data honesty" section explaining what's estimated vs measured — this doubles as App Review notes.

---

## Phase 8 — Continuous Improvement Loop: Iteration 1 (implemented)

Highest-impact improvement identified: **the 1 Hz `reloadAllTimelines()` battery/perf defect (H1)** — implemented, plus seven surgical fixes that were safe without a simulator:

1. **H1** `AppGroupStore.writeSnapshot` now diffs meaningful content and enforces a 60 s minimum between `WidgetCenter` reloads.
2. **H3** `SurveyViewModel.savedPoints` is now observed — saved-survey list, counts, and deletes update live.
3. **H7** CSV export URLs are generated once per appearance, not on every render.
4. **H8** Weak-device lookups use exact name matching instead of substring `contains`.
5. **H10** `project.yml` signing team typo fixed (`QCSX955Y7Pi` → `QCSX955Y7P`).
6. **M3 (partial)** `SurveyMapView` now uses the shared RSSI color scale.
7. **M6** Checklist reachable: linked from Settings (inner `NavigationStack` removed for correct push behavior).
8. **M7** Onboarding copy rewritten user-first; false SwiftData/Bluetooth claims removed.

**Next iterations (in order):** (2) `Reachability` enum replacing RSSI sentinels + honest "Response Quality" labeling → (3) `NetworkMonitor` extraction + `DiscoveryService` protocol + demo mode → (4) identity re-keying to `uniqueIdentifier` with store migration → (5) SwiftData migration → (6) room-first survey. Each ends with the same questions: simpler? faster? more intuitive? more honest? Every "yes, but…" becomes the next iteration's backlog.

## Phase 8 — Iteration 2 (implemented)

1. **H2** Metadata propagation: `ThreadDevice.metadataSignature` + the poll loop now diffs signatures, so renames, room moves, battery and channel changes reach the UI.
2. **H9** No fabricated data: Apple Park fallback removed; `SurveySample.location` is optional, sessions with no fix are discarded rather than invented.
3. **M8** `SurveyPoint.room` end-to-end: guided surveys tag each session with the surveyed room (persisted, shown in Saved Surveys) — groundwork for the room-first survey.
4. **M1** Scene-phase gating: poll loop idles while backgrounded (`ContentView` scenePhase → `MeshViewModel.isAppActive`).
5. **M4** `TMStyle` in `Sources/Shared`: single source for grade colors and room icons; duplicates removed from Dashboard, GuidedSurvey, and the widget.
6. **M12** Health computed once per poll tick in `MeshViewModel.health`; Dashboard reads it instead of recomputing per render.
7. **M15** Device notes persistence debounced (was one disk write per keystroke).
8. **M5** Location permission now requested when a survey starts, not at app launch.
9. **H4 (partial)** "Estimated" labeling: device-detail footer and dashboard trend title now disclose that signal values are latency-derived.
10. **H13** `.github/workflows/ci.yml` added: SwiftLint job + xcodegen + `xcodebuild test` on an iOS simulator. CHANGELOG 0.2.0 documents all of the above and corrects 0.1.0's inaccurate claims.

**Iteration 3 backlog (next highest impact):** `Reachability` enum replacing the `-100`/`-92` sentinels; `DiscoveryService` protocol adoption + `DemoDiscoveryService` (unblocks demo mode, previews, and testing the poll loop); re-key `DeviceStatsStore`/`ActivityStore`/notifications by `uniqueIdentifier`.

## Phase 8 — Iteration 4 (implemented)

1. **H11** Graph hit-testing + pan speed fixed: `MeshGraphView` now stores `viewSize` from `GeometryReader` and uses it to invert the `scaleEffect` transform in `handleTap` — converting visual tap coordinates back to canvas layout space before distance testing. Drag gesture now divides translation by `scale` so pan speed is constant regardless of zoom level.
2. **H5** Estimated topology label: the legend in `MeshGraphView` now shows "Estimated topology" (italic) so users understand the star layout is inferred, not real Thread parent/child data.
3. **H4 (complete)** Response Quality rename across all views: `DeviceListRow` shows the quality label ("Good", "Fair"…) instead of raw `dBm` numbers; `DeviceDetailView` header now says "Response Quality · estimated" with the quality label as the primary metric and stat cells use "RQ" instead of "dBm"; `MeshGraphView` HUD shows "quality (est.)" instead of "X dBm".
4. **M14** `PrivacyInfo.xcprivacy` created in `Sources/ThreadMapperApp/` — declares location (coarse, for survey), device inventory (other data types), UserDefaults API access (`CA92.1`), and file timestamp access (`C617.1`). Unblocks App Store submission.
5. **28** Quiet hours: `NotificationService.isInQuietHours()` reads `quietHoursEnabled/Start/End` from `UserDefaults` and suppresses all notifications during the configured window (midnight-wrapping supported). Settings UI added as a dedicated "Quiet Hours" section with start/end time pickers that appear when the toggle is on.
6. **M9** `BGTaskScheduler.submit` error no longer silently swallowed — failure is logged via `os.Logger` (category: `background`) so it appears in Console and Instruments.

**Remaining High issues:** H6 store identity migration to UUID (partially done for DeviceStatsStore/notifications — ActivityStore and SurveyViewModel still use device name as key).

**Iteration 5 →** see below.

## Phase 8 — Iteration 5 (implemented)

1. **34–35 App Intents / Siri** — Two `AppIntent` structs in `Sources/ThreadMapper/Intents/NetworkHealthIntents.swift`:
   - `GetNetworkHealthIntent` — "Check my Thread network in ThreadMapper" returns grade, score, and a human-readable summary via Siri dialog. Reads from `AppGroupStore.readSnapshot()` so it works without opening the app.
   - `GetOfflineDevicesIntent` — "Which devices are offline in ThreadMapper" lists all offline device names from the snapshot, or confirms all devices are online.
   - `ThreadMapperShortcuts: AppShortcutsProvider` registers three phrase variants per intent; `updateAppShortcutParameters()` called on app launch from `ThreadMapperApp.init()`.
   - `WidgetSnapshot` extended with `offlineDeviceNames: [String]` and `summary: String`; `MeshViewModel` now writes the offline device name list and a composed summary on every poll tick.
2. **8 Mesh Resilience Score** — `resilienceSection` added to `DashboardView` between Tips and Trend sections. Grades A–F based on border-router and total-router counts (A = 2+ BRs, 4+ routers; D = single router, no failover; F = no BR). Shows: 62px grade ring, descriptive summary, BR + router counts, and the names of the critical single-point-of-failure devices when grade is D or F.
3. **51 Health Streaks** — `HealthStreakStore` (`@Observable`, singleton, JSON-persisted) tracks consecutive Grade-A days. `record(grade:)` is called once per calendar day regardless of poll frequency. `currentStreak`, `longestStreak`, and `totalADays` are persisted across launches. A flame badge ("N-day streak") appears in the "Network Health" section header when `currentStreak ≥ 2`.

**Iteration 6 →** see below.

## Phase 8 — Iteration 6 (implemented)

1. **Room-first survey CTA** — `SurveyWalkView` restructured so "Survey My Home" (guided, room-by-room) is the prominent primary action with a large icon card and description. The GPS free-walk is moved into a clearly labeled "Free Walk" section below with a footer explaining it's the advanced/outdoor option. The header "Guided Walk" button removed — replaced by the card.
2. **Room Coverage bars** — New `roomCoverageSection` in `SurveyWalkView` aggregates all saved survey points with a room tag via `SurveyViewModel.roomStats()`. Each room gets a horizontal quality bar (color-coded, sorted best-first) showing response quality and sample count. Appears as soon as at least one guided survey has been completed.
3. **Rich completion card** — `GuidedSurveyView.completionCard` replaced with a results summary showing: best-coverage room, weakest room (with suggestion to add a router if signal < −75 dBm), and a list of weak devices detected across all completed rooms. Data sourced from `SurveyViewModel.roomStats(for: completedRooms)` and `weakDeviceNames(for: completedRooms)`.
4. **Raw coordinates removed** — Lat/lng strings removed from `SurveyMapView.detailCard` (replaced with room label), `SurveyWalkView.weakSpotSummary` (replaced with count + advice), and `SavedSurveyList.surveyRow` (GPS surveys now labeled "GPS survey" with a location icon instead of coordinates).
5. **Response Quality labels** — Remaining "dBm" instances in `SurveyWalkView.currentReadingSection` and `weakLinksSection` replaced with quality labels ("Good signal", "Fair", etc.) consistent with the Dashboard and mesh graph (completes H4 across the full app).

**Iteration 7 →** see below.

## Phase 8 — Iteration 7 (planned)

Three features selected from the full roadmap — one per category. Chosen because each builds directly on existing infrastructure (no new services required) and collectively deepen the product's value proposition from three independent angles: data fidelity, passive insight delivery, and monetization.

---

### Feature A — Latency Percentiles: p50 / p95 per Device (Core #9)

**What:** Replace the single "average RSSI" stat in `DeviceDetailView` with three signal-quality statistics: median (p50), worst-10th-percentile (p95), and jitter (p95 – p50 spread). A device with p50 = Good but p95 = Poor is intermittently flaky — the kind of diagnosis the current average hides completely.

**Why now:** `DeviceStatsStore` already stores up to 200 timestamped `Reading(timestamp: Date, rssi: Int)` entries per device in memory. The percentile computation is a pure sort-and-index operation — zero new persistence, zero new services.

**Technical plan:**

1. **`DeviceStatsStore`** — add a computed method `percentiles(for deviceID: UUID) -> (p50: Int, p95: Int, jitter: Int)?`:
   ```swift
   func percentiles(for deviceID: UUID) -> (p50: Int, p95: Int, jitter: Int)? {
       guard let readings = recentReadings[deviceID], readings.count >= 5 else { return nil }
       let sorted = readings.map(\.rssi).sorted()
       let p50 = sorted[sorted.count / 2]
       let p95 = sorted[min(sorted.count - 1, sorted.count * 95 / 100)]
       return (p50: p50, p95: p95, jitter: p95 - p50)
   }
   ```
   The existing `recentReadings` dictionary (capped at 200 entries, already tracked) is the source — no schema change needed.

2. **`DeviceDetailView`** — replace or augment the existing "RQ" stat cell with three new cells in the stats grid:
   - "Median RQ" — p50 quality label + color (e.g. "Good")
   - "Worst 10%" — p95 quality label (highlights intermittent drops)
   - "Jitter" — p95 – p50 as a number; tinted orange/red if > 15 (indicates instability)
   A `jitterLabel` helper: `jitter < 10 → "Stable"`, `10–20 → "Variable"`, `> 20 → "Erratic"`.

3. **`SignalSparklineView`** — add two horizontal dashed reference lines at the p50 and p95 RSSI values (drawn with `Canvas` `stroke path` using `[3, 3]` dash pattern). These lines make the distribution visible on the sparkline without cluttering it. Label them with tiny "p50" / "p95" tags at the right edge.

4. **`NetworkHealthScore`** — update the weak-device penalty: currently any device with avg RSSI < −75 is "weak". Change to: weak if p95 < −80 (i.e., at least 5% of readings are Poor), which is more accurate and forgiving of brief spikes.

**Files:** `DeviceStatsStore.swift`, `DeviceDetailView.swift`, `SignalSparklineView.swift`, `NetworkHealthScore.swift`
**Effort:** ~1 day

---

### Feature B — Auto-Generated Weekly Health Report (AI #14)

**What:** Every 7 days, the app generates a plain-English summary of how the network performed that week and delivers it as a local notification with a "Read report" action that opens a `WeeklyReportView` sheet. No server, no ML — pure template generation from the data already in `HealthHistoryStore`, `ActivityStore`, and `DeviceStatsStore`.

**Why now:** `HealthHistoryStore` has up to 288 entries (24h at 5-min intervals, rolling); `ActivityStore` has timestamped events including `deviceOffline`, `healthDegraded`, `healthImproved`; `DeviceStatsStore` has per-device `DeviceStats`. Generating a weekly report is a read operation on all three — no new data collection.

**Technical plan:**

1. **`WeeklyReportStore`** — `@Observable` singleton, JSON-persisted:
   ```swift
   struct WeeklyReport: Codable, Identifiable {
       let id: UUID
       let generatedAt: Date
       let weekStart: Date
       let avgScore: Int           // average health score over the week
       let peakGrade: String       // best grade achieved
       let offlineEventCount: Int  // total offline events
       let mostProblematicDevice: String?  // device with most offline events
       let improvementDelta: Int   // score(last day) - score(first day)
       let streakDays: Int         // from HealthStreakStore
       let body: String            // pre-rendered plain-English paragraph
   }
   ```
   `generate() -> WeeklyReport` is called once per week (checked on app foreground):
   - Filter `HealthHistoryStore.entries` to the last 7 days → compute avg score, peak grade
   - Filter `ActivityStore.events` to `.deviceOffline` in last 7 days → count by device name → find max
   - `HealthStreakStore.shared.currentStreak` for the streak line
   - Template: *"Your Thread network averaged Grade [X] this week ([score]/100). [Device] was the most disruptive, going offline [N] times. [Streak line if ≥ 3 days: 'You're on a [N]-day Grade A streak — great work.'] [Improvement line: 'Performance improved by [delta] points since Monday.']"*
   - Persist report to `weekly_report.json`; expose via `WeeklyReportStore.shared.latestReport`

2. **Notification delivery** — in `NotificationService`, add `scheduleWeeklyReport()`: a `UNCalendarNotificationTrigger` firing every Sunday at 9 AM. On tap, open the app to the report sheet. Reschedule after each delivery.

3. **`WeeklyReportView`** — full-page sheet (or `ContentUnavailableView`-based empty state):
   - Header: grade badge (same ring as Dashboard, 72px), week date range, avg score
   - Body text: the generated paragraph in `.body` style
   - Stats row: offline events · streak · improvement delta
   - "Share" button: `ShareLink` to share the report text as plain text or a simple PNG card (generated with `ImageRenderer`)

4. **Entry point** — in `DashboardView`, add a "Weekly Report" button in the header toolbar when `WeeklyReportStore.shared.latestReport != nil` (bell + dot badge). Also accessible from `ActivityFeedView`.

5. **`AppIntent` extension** — add `GetWeeklyReportIntent` to `NetworkHealthIntents.swift`: "What's my Thread report for this week in ThreadMapper?" — returns `latestReport?.body` or a fallback.

**Files:** `WeeklyReportStore.swift` (new), `WeeklyReportView.swift` (new), `NotificationService.swift`, `DashboardView.swift`, `NetworkHealthIntents.swift`
**Effort:** ~2–3 days

---

### Feature C — Pro Tier Paywall (Premium #47)

**What:** StoreKit 2 subscription gate separating a free tier (core dashboard, 7-day history cap, single border-router monitoring) from a Pro tier (unlimited history, resilience score, health streaks, Siri shortcuts, weekly reports, room survey results, Watch complication when built). Paywall triggered contextually — not at launch — when a free user first encounters a Pro feature.

**Why now:** The Pro-only features are already built. StoreKit 2 requires no server — receipt validation is on-device. Adding the gate now, before the App Store submission, locks in the revenue model before users expect everything for free.

**Technical plan:**

1. **`ProStore`** — `@Observable` singleton using StoreKit 2:
   ```swift
   @Observable final class ProStore {
       static let shared = ProStore()
       private(set) var isPro: Bool = false
       private(set) var product: Product?
       // Product IDs (configured in App Store Connect):
       static let annualID = "com.tintronixlab.ThreadMapper.pro.annual"   // $4.99/yr
       static let lifetimeID = "com.tintronixlab.ThreadMapper.pro.lifetime" // $14.99
   }
   ```
   On init: verify existing entitlements via `Transaction.currentEntitlements`. Observe `Transaction.updates` for renewals/revocations. Persist a `isPro` flag to `UserDefaults(suiteName: AppGroupStore.groupID)` so the widget and intents can read it without launching the app.

2. **`PaywallView`** — presented as a sheet from any Pro feature gate:
   - Header: "ThreadMapper Pro" with the mesh icon
   - Feature list: 5 bullet points with SF Symbol icons (history, resilience, Siri, weekly report, streaks)
   - Pricing: two buttons — Annual (with "Most popular" badge) and Lifetime
   - Footer: "Restore Purchases" link + legal disclaimer
   - On purchase success: `ProStore.shared.isPro = true` → dismiss sheet → feature becomes available immediately

3. **Free-tier limits** (enforced in the existing code with guard statements):
   - `HealthHistoryStore.record`: cap at 7-day window for free users (currently 24h, extend to 7d free / unlimited Pro). Change `maxEntries = isPro ? 2016 : 288` (2016 = 7 days × 288 per day).
   - `resilienceSection` in `DashboardView`: show a "Pro" lock chip if not Pro; tapping presents `PaywallView`
   - `HealthStreakStore` display: show streak only for Pro; free users see "Upgrade to track streaks"
   - Siri shortcuts: `openAppWhenRun = isPro` — free tier opens the app instead of answering in-place (still works, just less seamless)
   - Weekly report: Pro-only feature; the notification and sheet are gated

4. **Contextual paywall triggers** (the right moment, not intrusive):
   - First time `resilienceSection` would show a non-trivial grade (C or below) → soft prompt: "Unlock Resilience Score with Pro"
   - First guided survey completion → "Pro unlocks full room history and weekly reports" → `PaywallView`
   - History chart truncated at 7 days → "See 30+ days of history with Pro" inline button

5. **`@AppStorage("isPro")`** — as a secondary fast-path check in views. The authoritative check is `ProStore.shared.isPro` (StoreKit-verified), but `@AppStorage` provides synchronous read without waiting for `async` StoreKit calls during view rendering.

6. **App Store Connect setup** (outside the codebase): create the two products, set up pricing, add entitlement to `PrivacyInfo.xcprivacy` (no new API access needed), add `StoreKit Testing` config file for local testing in Simulator.

**Files:** `ProStore.swift` (new), `PaywallView.swift` (new), `DashboardView.swift`, `HealthHistoryStore.swift`, `HealthStreakStore.swift`, `NetworkHealthIntents.swift`
**Effort:** ~3–4 days (not counting App Store Connect product setup)

---

**Secondary Iteration 7 items (carry from previous backlog):** Dynamic Type audit — replace all fixed `font(.system(size: N))` with semantic text styles (`.caption2`, `.footnote`) so accessibility text sizes work; VoiceOver graph navigation (H12) with an `accessibilityChildren` overlay on `MeshGraphView`'s `Canvas`; `.completeFileProtection` on all JSON store files (one `write(options: [.atomic, .completeFileProtection])` change per store).

## Phase 8 — Iteration 7 (implemented)

### Feature A — Latency Percentiles (Core #9)
1. **`DeviceStats.p50 / p95 / jitter / jitterLabel`** — computed from the sorted readings array already stored in `DeviceStatsStore`. `p50` = median; `p95` = worst 5th percentile (min 5 readings required); `jitter` = spread in pts; `jitterLabel` = "Stable / Variable / Erratic" based on thresholds (< 10 / 10–20 / 20+).
2. **`SignalSparklineView`** — draws two additional reference lines when ≥ 5 readings exist: a blue dashed p50 line labeled "p50" and an orange dashed p95 line labeled "p95", both at the left edge. These sit above the existing zone threshold lines so the user can instantly see typical vs worst-case signal positions.
3. **`DeviceDetailView`** — a second stat row (Median · Worst 10% · Jitter) appears below the existing Live/Avg/Min/Max row once 5+ readings are collected. The quality label (Good/Fair/Poor/…) is the primary value in each cell rather than a raw number, consistent with the Response Quality rename (H4).

### Feature B — Auto-Generated Weekly Health Report (AI #14)
4. **`HealthHistoryStore`** extended from 24h (`maxEntries = 288`) to 7 days (`maxEntries = 2016`); restore cutoff updated to `-7 × 86400 s`. This gives the weekly report genuine trend data.
5. **`WeeklyReportStore`** — `@Observable` singleton. `generateIfNeeded()` runs at each app foreground (gated: max once per 23 h). Aggregates: `HealthHistoryStore.entries` (avg score, peak grade), `ActivityStore.events` (offline event count, most disruptive device), `HealthStreakStore` (current streak, total A days). Renders a 2–4 sentence plain-English paragraph. Persists the latest report to `weekly_report.json`.
6. **`WeeklyReportView`** — sheet with a grade ring header, the prose body on a card, and a three-stat row (avg score · offline events · streak/A-day count). `ShareLink` exports the body as text.
7. **`DashboardView`** toolbar gains a "Weekly Report" secondary action (document icon) whenever `WeeklyReportStore.shared.latestReport != nil`.
8. **`NotificationService.scheduleWeeklyReport()`** — schedules a repeating `UNCalendarNotificationTrigger` for Sunday at 9 AM, set up the first time a report is generated.
9. **`ContentView`** — calls `WeeklyReportStore.shared.generateIfNeeded()` in the `.task` block on foreground.

### Feature C — StoreKit 2 Pro Tier (Premium #47)
10. **`ProStore`** — `@Observable` singleton with StoreKit 2. Verifies entitlements via `Transaction.currentEntitlements` on init; observes `Transaction.updates` for renewals/revocations. Persists `isPro` to `UserDefaults` (both standard and App Group) for fast synchronous reads. `DEBUG` builds are always Pro so development isn't gated. Products: `com.tintronixlab.ThreadMapper.pro.annual` + `.pro.lifetime` (requires App Store Connect product setup).
11. **`PaywallView`** — full-page sheet listing 5 Pro features with icons, two product purchase buttons (annual highlighted as "Most Popular"), and a restore link. Handles empty product list gracefully (shows spinner while StoreKit loads).
12. **`DashboardView` soft gates** — the "Network Health" streak badge shows a lock chip that presents `PaywallView` for non-Pro users; the "Mesh Resilience" section header shows a "Pro" lock badge. Content remains visible (trust-building), but the Pro CTA is clearly present.
13. **`ContentView`** injects `ProStore.shared` into the SwiftUI environment.

**Iteration 8 backlog:** Dynamic Type audit; VoiceOver graph navigation (H12); `.completeFileProtection` on all JSON stores; App Store Connect product setup for Pro tier; Spotlight indexing of devices (feature #57).

## Phase 8 — Iteration 8 (implemented)

### Feature A — `.completeFileProtection` on All JSON Stores (M14)
All 7 persistence callsites updated from `.atomic` to `[.atomic, .completeFileProtection]`:
`ActivityStore`, `HealthHistoryStore`, `DeviceNotesStore`, `HealthStreakStore`, `WeeklyReportStore`, `DeviceStatsStore`, and `SurveyViewModel`. Files are now encrypted at rest and inaccessible while the device is locked — required for App Store privacy compliance and prevents data exfiltration if the device is accessed while locked.

### Feature B — Achievements System (#52)
1. **`AchievementStore`** — `@Observable` singleton with 6 achievements: "First Steps" (first room survey), "Coverage Champion" (3+ rooms), "Grade A Network" (first Grade A), "Streak Starter" (3-day streak), "Streak Master" (7-day streak), "Resilient Home" (2+ border routers + 4+ routers). Persisted to `achievements.json` with `.completeFileProtection`. Merge strategy on restore handles new achievements added in future app updates without losing existing unlock state.
2. **`AchievementsView`** — List showing all achievements, locked items at 45% opacity, unlock date shown below unlocked items. Presented as a sheet from the Dashboard.
3. **`AchievementBanner`** — Spring-animated slide-in banner at the top of Dashboard that auto-dismisses after 4 seconds when an achievement is unlocked. Dismiss button for manual close.
4. **Dashboard `achievementsSection`** — Appears between Resilience and Trend sections once at least one achievement is unlocked. Shows trophy icon, unlocked count, and up to 3 badge icons inline. Taps into `AchievementsView` sheet.
5. **Trigger wiring**:
   - `streak3` / `streak7` → `HealthStreakStore.record()` after updating `currentStreak`
   - `firstGradeA` → `MeshViewModel` poll loop when `health.grade == "A"`
   - `resilienceA` → `MeshViewModel` when `brCount >= 2 && routerCount >= 4`
   - `firstSurvey` / `surveyThreeRooms` → `GuidedSurveyView.stopRecording(room:)` based on `completedRooms.count`

### Feature C — Haptic Geiger-Counter Survey Mode (#69)
1. **Haptic toggle** — Waveform toolbar button appears in `GuidedSurveyView` while recording is active. Icon uses `.pulse` symbol effect when enabled to signal it's live.
2. **Variable-interval haptic loop** — `startHapticPulse()` runs a `Task` that reads the average RSSI across all discovered devices and maps it to a `UIImpactFeedbackGenerator` pulse:
   - avgRSSI > −55 (Excellent): 0.3 s · heavy impact
   - avgRSSI > −65 (Good): 0.5 s · medium impact
   - avgRSSI > −75 (Fair): 1.0 s · medium impact
   - avgRSSI > −85 (Poor): 1.8 s · light impact
   - else (Very Poor): 3.0 s · light impact
   Better signal = faster, stronger pulses — analogous to a Geiger counter picking up more signal as you walk toward coverage.
3. **Live signal row** — Updated to show quality labels ("Good", "Fair", "Poor") instead of raw RQ numbers, consistent with the rest of the app.
4. **Haptic hint** — Instructional caption shown below the room description before recording starts so users know the feature exists.
5. Task is cancelled in `stopRecording()` and `hapticEnabled` resets to `false` so the next room starts clean.

**Iteration 9 backlog:** Dynamic Type audit (replace `font(.system(size: N))` with `.caption2`/`.footnote` semantic styles); VoiceOver graph navigation (H12, `accessibilityChildren` overlay on Canvas); Spotlight indexing of devices (#57 — `CSSearchableItem` + `CSSearchableIndex`); App Store Connect Pro product setup; confetti animation on grade improvement (#53).

## Phase 8 — Iteration 9 (review: Dashboard / Network Health regression)

**Trigger:** After the last PR (`906cc3b "fixes"`), the Dashboard's **Network Health** section behaves incorrectly — tiles feel unresponsive and parts of the section are inconsistent/stale. That PR reworked the hero stat grid and the issue rows from plain cards into `NavigationLink`s driving a new `DeviceFilterView`, added collapsible Room Coverage / Devices sections, and gave `NetworkHealthScore.Issue` an `affectedDevices` payload. This review isolates what regressed and lays out the fix plan.

> **Verification note:** this environment is Linux with no Xcode/Simulator, and the package imports `HomeKit`/`UIKit` (see H13), so the app cannot be built or run here. Findings below are from static review of the landed diff; each fix should be confirmed on a simulator before merge.

### Findings (Dashboard / Network Health)

| # | Sev | Location | Finding |
|---|-----|----------|---------|
| D1 | **High** | `DashboardView.healthSection` + `tappableStatCard` (`DashboardView.swift:171–201`, `254–277`) | The four hero tiles (Devices / Routers / Offline / Weak) are **four `NavigationLink`s packed into a single `List` row**, alongside the grade ring. Multiple `NavigationLink`s in one `List` cell is unreliable on iOS: their tap regions overlap inside the shared row, so taps can miss, activate the wrong destination, or fail to register — the most likely cause of "the Network Health tiles don't do anything." |
| D2 | **High** | `issueRow` / `issueRowContent` (`DashboardView.swift:326–361`) | Issue rows share the same multi-`NavigationLink`-in-`List` fragility. Worse, the row is tappable **only when `affectedDevices` is non-empty**, so "No border router detected" (empty `affectedDevices`) is silently non-interactive while its neighbours navigate — inconsistent affordance with no visible cue which rows are actionable. |
| D3 | **Med** | `DeviceFilterSpec` (`DeviceFilterView.swift:4–7`) + hero counts | Drill-in lists capture a **frozen `[ThreadDevice]` snapshot** at push time. `ThreadDevice` is a plain (non-`@Observable`) class and `DeviceFilterView` observes nothing, so as the 1 Hz poll loop flips offline/weak/rssi the pushed "Offline Devices" list neither re-orders nor drops recovered devices — it disagrees with the live hero count until you pop and re-enter. |
| D4 | **Med** | `MeshViewModel.health` (`MeshViewModel.swift:172–173`), `NetworkHealthScore` (not `Equatable`) | `self.health` is **reassigned every poll tick** even when nothing changed, and `NetworkHealthScore` has no `Equatable` conformance, so Observation cannot elide the update — the entire Dashboard `List` re-evaluates ~once per second, which also re-arms the grade-ring spring animation and causes visible churn/jank in the section. |
| D5 | **Med** | `trendSection` (`DashboardView.swift:524–531`), `placementSection` / `buildPlacementSuggestions` (`DashboardView.swift:768–781`) | The "Response Quality" rename (H4), which iterations 4/6 record as **complete "across the full app,"** is not complete on the Dashboard: the trend header still prints `"\(avgRSSI) dBm avg"` and placement copy still says `"avg \(roomAvg) dBm"`. Raw pseudo-dBm is exactly the data-honesty problem H4 set out to remove. |
| D6 | **Low–Med** | `DashboardView.routerCount` (`:366`) vs `MeshViewModel` achievement gate (`:204–206`) | "Router" is counted two ways: the on-screen Resilience grade uses `isRouter || isBorderRouter`, but the `resilienceA` achievement uses `devices.filter(\.isRouter)` (excludes border routers). The Resilience card and the "Resilient Home" badge can therefore disagree for the same network. |
| D7 | **Low** | `NetworkHealthScore.Issue.id` (`NetworkHealthScore.swift:13`) | `id` is content-derived (`"\(icon)|\(message)"`). Stable today, but two issues sharing icon+message would collide and break `ForEach` identity — fragile keying for a list that changes every tick. |
| D8 | **Low** | `tappableStatCard` label (`:266`), grade sub-number (`:243`) | Fixed `font(.system(size: 9))` / `size: 11` in the hero defeat Dynamic Type (already on the standing a11y backlog; re-flagged because it lives in this section). |

### Fix plan (ordered)

1. **D1 + D2 — make the tiles and issue rows navigate reliably.** Replace the in-row `NavigationLink`s with plain `Button`s that append to the existing `navPath` (`Button { navPath.append(spec) } label: { … }`), keeping the single `navigationDestination(for: DeviceFilterSpec.self)`. `Button`s have no one-per-`List`-row restriction, so all four tiles and every issue row become independently tappable. Render a trailing chevron only on rows that actually navigate (issues with `affectedDevices`), so the affordance matches behaviour. *(Highest impact — this is the "not working" report.)*
2. **D3 — live drill-in lists.** Change `DeviceFilterSpec` to carry a lightweight category (an enum: `.all / .routers / .offline / .weak / .issue(id)`) instead of a captured array; have `DeviceFilterView` read `@Environment(MeshViewModel.self)` and recompute the filtered set on each render so the pushed screen tracks the live network.
3. **D4 — stop the 1 Hz churn.** Make `NetworkHealthScore` (and its `Issue`) `Equatable`, then assign in the poll loop only on change: `if newHealth != health { health = newHealth }`. Removes the per-second full-`List` re-evaluation and the spurious ring re-animation.
4. **D5 — finish the Response Quality rename on the Dashboard.** Route the trend "avg" and placement-suggestion copy through the shared `SignalStrength`/`TMStyle` quality label + color scale instead of printing `dBm`. Closes H4 for real and matches every other screen.
5. **D6 — one definition of "router."** Extract a single helper (e.g. `TMStyle`/`MeshViewModel.routerCount(includingBorderRouters:)`) and use it for both the Resilience grade and the achievement gate.
6. **D7 / D8 — hardening & a11y.** Give `Issue` a `UUID` identity (or hash more fields) and swap the fixed hero font sizes for semantic text styles as part of the pending Dynamic Type audit.

**Suggested PR grouping:** ship **D1–D2** (and the trivial **D5**) as the "dashboard fix" PR the user is waiting on; fold **D3–D4** into a follow-up "dashboard correctness/perf" PR; sweep **D6–D8** with the Iteration 9 a11y backlog.

### Iteration 9 (implemented — batch 1)

1. **D1** — Hero stat tiles (`tappableStatCard`) converted from in-row `NavigationLink`s to `Button`s that append the `DeviceFilterSpec` to `navPath`. Buttons have no one-per-`List`-row restriction, so all four tiles in the shared hero row are now independently tappable.
2. **D2** — Issue rows converted the same way (`Button` + `navPath.append`), and `issueRowContent` now takes an `actionable` flag: only rows with `affectedDevices` show a trailing chevron, so the tap affordance matches behaviour. The single `navigationDestination(for: DeviceFilterSpec.self)` still backs both.
3. **D5** — Dashboard "Response Quality" rename completed: the trend header now reads "Response Quality (estimated)" with a quality label (`rssiQualityLabel`) + `rssiColor` instead of "`N dBm avg`"; placement suggestions surface the quality label instead of raw `dBm`.

### Iteration 9 (implemented — batch 2)

4. **D3** — `DeviceFilterSpec` no longer captures a `[ThreadDevice]` snapshot; it carries a `Category` (`.all / .routers / .offline / .weak / .ids([UUID])`). `DeviceFilterView` now reads `@Environment(MeshViewModel.self)` and re-resolves the list on every render, so a drilled-in "Offline Devices" screen tracks the live poll loop and drops devices that recover or leave the network instead of showing a frozen set. *(Residual: `ThreadDevice` is still a non-`@Observable` class, so an rssi-only change that doesn't reassign `viewModel.devices` won't force a re-render — folded into the separate "make `ThreadDevice` observable / value-type" cleanup, not this batch.)*
5. **D4** — `NetworkHealthScore` and its `Issue` are now `Equatable`, and the poll loop assigns `self.health` only when the value actually changes (`if health != self.health { … }`). Identical ticks no longer invalidate every Dashboard observer, so the `List` stops re-evaluating ~once per second and the grade-ring spring animation only fires on a real score change.

**Not built/run here** (Linux, no Xcode — see H13); verify on a simulator that the four tiles and each actionable issue row push the correct *live* filtered list and that the Dashboard no longer visibly churns between ticks.

### Iteration 9 (implemented — batch 3)

6. **D6** — one definition of "router": `ThreadDevice.isRoutingCapable` (`isRouter || isBorderRouter`) is now the single source of truth, used by the Dashboard hero + Resilience grade, the `resilienceA` achievement gate (previously `filter(\.isRouter)`, which excluded border routers and could disagree with the on-screen grade), `MeshViewModel.routerDensity`/`warnings`, `DeviceFilterView`'s `.routers` category, `AppChecklistView`, and `SignalExtrapolator`.
7. **D7** — *resolved as by-design (no code change).* `Issue.id` is intentionally content-derived (`"\(icon)|\(message)"`): it must stay deterministic so `ForEach` identity is stable across poll ticks and the D4 `Equatable` conformance doesn't reassign `health` every tick. A random `UUID()` would reintroduce exactly the churn D4 removed. Issue messages are unique per issue type, so there is no real collision. Comment left in place documenting the intent.
8. **D8** — hero fonts now honor Dynamic Type: the grade letter (36), grade sub-score (11), and stat-tile label (9) fixed sizes are backed by `@ScaledMetric` (relative to `.largeTitle` / `.caption2`), so they render identically at the default text size but scale at accessibility sizes. The grade letter gains `minimumScaleFactor(0.5)` + `lineLimit(1)` so it shrinks to fit the fixed 92 pt ring instead of clipping. *(Scoped to the hero, as the finding was; a full-file Dynamic Type audit — the many other `.system(size:)` call sites — remains a separate pass best done with a simulator to catch layout regressions.)*

**Iteration 9 fully closed** (D1–D8). Remaining follow-ups are the larger refactors noted in passing: make `ThreadDevice` observable/value-type (removes the D3 rssi-staleness residual), the full Dynamic Type audit, and the real code cleanups behind the lint rules PR #2 relaxed to warnings (short-name renames, tuple→struct, file/type splits).

## Phase 8 — Iteration 10 (Mesh tab: real inferred topology — closes H5)

The Mesh tab previously drew a **fake star** — every non-BR device wired to the
*first* border router, no paths, `parentNodeID` never used (review issue **H5**).
HomeKit doesn't expose the Thread routing table (the live `MatterDiscoveryService`
can only tell a border router from "everything else"), so a *real* graph must be
inferred — but honestly, and structured like an actual Thread/Matter mesh.

**`MeshTopologyBuilder` rewrite** — a tiered, parent-assigned mesh:
`gateway (Wi-Fi / Internet) → border routers → mesh routers → end devices`.
- **Role inference:** trust explicit `isRouter` when any device reports it (demo /
  future Matter diagnostics); otherwise infer from power source — a mains device
  (no battery reported) relays, a battery device is a leaf.
- **Parent assignment:** a leaf prefers a **same-room mesh router** (a genuine hop
  through another Matter device) over a distant border router, then any router,
  then the strongest border router; routers attach to their best border router.
- **Forward-compatible:** an explicit `parentNodeID` that resolves to a router/BR
  is honored first, so real Thread diagnostics can later drop straight in.
- A synthetic `gateway` node (no backing device) gives every path a visible
  top — the Wi-Fi/internet uplink border routers reach through.

**`GraphLayout.hierarchical`** — a layered top-down layout keyed on `MeshNode.tier`
with children ordered under their parent's x, so multi-hop paths read clearly
(replaces the random force-directed layout for this view).

**`MeshGraphView`** — distinct glyphs per kind (gateway square w/ Wi-Fi, filled
border router, ringed "relay" router, dot device, green-ringed battery device);
backbone links dashed (IP uplink) vs solid mesh hops colored by quality. Selecting
a node **highlights its route to the internet** and the HUD spells it out — e.g.
*"Kitchen Sensor → Kitchen Plug (relay) → HomePod (border router) → Internet · via
1 relay"* — directly answering "does this device hop through another Matter
device?". Legend + an "Estimated paths — HomeKit doesn't report Thread routing"
note keep it honest.

**Models:** `MeshNode` gains `tier`, `parentID`, `isBattery`; `MeshNodeKind` gains
`.gateway`; `MeshLink` gains `kind` (`.backbone` / `.mesh`). All additive with
defaults (no persisted-schema break). `MeshViewModel.visibleDeviceCount` now
excludes the synthetic gateway.

**Tests:** `ThreadTopologyBuilderTests` rewritten for the tiered output —
gateway/backbone creation, the same-room multi-hop relay case, explicit-parent
honoring, the no-border-router orphan case, and mains-device router inference.

**Not built/run here** (Linux, no Xcode); CI compiles + runs the tests. The graph
visuals want an on-device look — parent inference is a heuristic, clearly labeled
estimated. **Next:** real Thread Network Diagnostics via the Matter framework
(feature #2) would replace inference with the actual routing table.

## Feature #2 — Matter Thread Network Diagnostics (planned)

Goal: replace the Mesh tab's *inferred* topology (Iteration 10) with the **real**
Thread routing table where possible.

### Platform reality (the constraint that shapes everything)
A third-party iOS app **cannot read the Thread routing table of HomeKit-commissioned
devices**:
- **HomeKit** exposes no Thread routing — `HMAccessory` has no parent/child, RLOC,
  role, or neighbor data. (Hence `MatterDiscoveryService` guessing `isBridge → BR`.)
- **Matter / `MatterSupport`** on iOS is for *commissioning*, not reading clusters;
  there is no public API to read the Thread Network **Diagnostics cluster** from
  HomeKit-owned devices.
- Reading that cluster needs a **Matter controller/admin on the fabric**, which
  Apple keeps in the daemon and does not expose to apps.

So "real routing" splits into what's obtainable vs not:
- ✅ **Network facts** (channel, PAN ID, ext PAN ID, network name, border-agent id)
  via the **`ThreadNetwork`** framework (`THClient`) — needs the
  `com.apple.developer.thread-network-credentials` entitlement (Apple-gated).
- ✅ **True routing table** only via an **OpenThread Border Router (OTBR) REST**
  endpoint (`/diagnostics`, `/node`) the user connects — Apple/Google BRs don't
  expose it; OTBR (e.g. HA SkyConnect / Home Assistant Yellow) does.
- ❌ **In-app per-node routing for HomeKit devices** — not available.

### Phased plan
- **Phase 0 — Spike (~1 wk):** confirm exact `ThreadNetwork`/`THCredentials` API +
  entitlement path; verify no HMAccessory/Matter route to per-node routing;
  correlate a Thread network → HomeKit accessories. Gate the rest on findings.
- **Phase 1 — Real network facts:** add entitlement; `ThreadCredentialsService`
  reads active credentials → real **channel/PAN/network name**. Immediate wins:
  accurate channel-conflict detection, real channel in Mesh HUD, true
  border-router/network count feeding the Resilience score.
- **Phase 2 — Diagnostics seam + real builder path:** `ThreadNodeDiagnostics`
  (role, RLOC16, parent RLOC, neighbor table w/ link margin) + `DiagnosticsProvider`;
  `MeshTopologyBuilder.buildGraph(from:diagnostics:)` builds edges/roles/quality
  from the real table, falling back to inference per-device. Wire `MeshViewModel`
  to pass a provider's diagnostics through.
- **Phase 3 — OTBR integration (stretch, ~1–2 wk):** `BorderRouterClient` connects
  to a user-provided OTBR REST endpoint, parses `/diagnostics`, maps RLOC→devices,
  feeds Phase 2. The one path to a genuine routing table.
- **Phase 4 — UI + honesty:** data-source badge in the Mesh legend
  ("Live routing · OTBR" vs "Estimated · HomeKit"); node HUD shows real
  role/RLOC/link-margin when present; Settings source picker; privacy-manifest /
  usage-string updates.
- **Phase 5 — Testing:** builder tests with real neighbor-table fixtures; credential
  parsing behind a fake `THClient`; keep `ThreadNetwork`/OTBR behind protocols so
  CI (no simulator Thread stack) stays green.

### Risks
Entitlement approval (Apple-gated); no in-app real topology for HomeKit devices
(true routing only via OTBR/companion); App Review scrutiny + privacy-manifest
additions; multi-fabric/multi-admin edge cases.

### Scope
**MVP = Phases 0–2 + 4** (real channel/PAN, clean diagnostics seam, honest
labeling) ≈ 3–4 wk. **Phase 3 (OTBR)** is the high-value stretch that actually
delivers a real routing table.

### Phase 0 scaffold (landed)
Inert seam so Phases 1–2 drop in without refactoring — no live behavior change:
- `ThreadNodeDiagnostics` (role → `meshKind`, `linkQuality` from real link margin)
  and `ThreadNetworkInfo` models.
- `DiagnosticsProvider` protocol + `NoDiagnosticsProvider` default (yields nothing
  → mesh stays inferred).
- `ThreadCredentialsService`: `ThreadNetwork` read scaffolded behind the
  `THREAD_CREDENTIALS` build flag (off in CI) so the unverified `THClient` mapping
  never risks a build break; returns nothing until the entitlement is provisioned.
- `MeshTopologyBuilder.buildGraph(from:diagnostics:)` — real-data path (parent
  edges from RLOC, roles, link quality) with inference fallback.
- Tests: real parent-edge construction, empty-diagnostics fallback, link-quality
  from margin, role→kind mapping, no-op provider.

**Next step to activate:** wire `MeshViewModel` to call a `DiagnosticsProvider` and
pass results to `buildGraph(from:diagnostics:)`; provision the Thread credentials
entitlement; then Phase 3 OTBR for the real routing table.

### Phase 3a — OpenThread Border Router connection (landed)
The one path to real Thread data that doesn't need Apple's entitlement: connect
an OTBR's REST API.
- `BorderRouterClient` (a `DiagnosticsProvider`) with an injectable fetcher —
  reads `/node` + `/node/dataset/active` → real `ThreadNetworkInfo` (network name,
  channel, PAN ID, ext PAN ID). Flows into the Mesh `threadNetworkBar`.
- Settings → "Border Router (advanced)": endpoint URL + "Test Connection".
  `ContentView` prefers a configured OTBR over the entitlement-gated
  `ThreadCredentialsService`; both stay dormant if unavailable (no behavior
  change by default). `NSLocalNetworkUsageDescription` added for LAN access.
- Tests: `/node` + dataset JSON parsing → `ThreadNetworkInfo`, unreachable →
  empty, connection check, diagnostics empty (Phase 3b).

**Phase 3b (next, needs hardware):** parse `POST /diagnostics` (child/route
tables) into `ThreadNodeDiagnostics`, and correlate OTBR nodes (ext-address) to
HomeKit accessories so the real routing table drives the graph. `nodeDiagnostics()`
is stubbed empty until then.

---

## Phase 8 — Iteration 11 (2026-07-09: safe-fix pass + forward work plan)

Re-scanned the tree against the original review. Confirmed the top-severity
items (widget reload storm, H2 metadata propagation, idle backoff, helper
duplication, D4 health churn) are already resolved in-tree. Ran a low-risk,
behavior-preserving pass and captured the remaining backlog in `WORKPLAN.md`.

**Shipped (no behavior change; each clears an opt-in lint warning or dead code):**
- Removed dead `rebuildGraph()` in `MeshViewModel` (`applyFilters()` is the live path).
- `BackgroundRefreshHandler`: `task as!` → `guard let` (completes the task on type mismatch instead of trapping).
- `DeviceStatsStore.stats`: `values.min()!/.max()!` → guarded bindings.
- `WeeklyReportStore`: `historyEntries.last!/.first!` → `if let` (guard already ensured count ≥ 2).
- `SurveyWalkView.bounds` / `SurveyMapView.initialCamera`: `min()!/max()!` → guarded bindings.

**Deferred to `WORKPLAN.md` (need Xcode build to verify):** name-keyed identity
→ `uniqueIdentifier` (P1), decompose the `MeshViewModel` init poll loop (P2),
split 400+ line views (P2), reduce singletons for DI/testability (P2), gate the
1 Hz main-actor work (P3), off-main graph layout (P3), concurrency/`Sendable`
audit + persistence consolidation (P4), Dynamic Type + contextual permissions (P5).

**Validation caveat:** prepared without a Swift toolchain — validated by static
analysis and guard-invariant reasoning. Run `make ci` before committing.

---

## Phase 8 — Iteration 12 (2026-07-09: P1 identity keying — name → uniqueIdentifier)

Closed the top backlog item from `WORKPLAN.md`: device identity was keyed by
mutable `name` in two places, so duplicate names collided and a rename read as a
membership change. Both are now keyed by `ThreadDevice.uniqueIdentifier`.

**Topology join/leave (`MeshViewModel`):** replaced `knownDeviceNames: Set<String>`
with `knownDeviceIDs: Set<UUID>` plus a `knownDeviceNamesByID: [UUID: String]`
last-seen-name map. Join/leave is diffed on IDs; display names are resolved from
current devices (joined) or the retained name map (left, since those devices are
already gone). Banner text, notifications, and activity events are unchanged in
shape — a rename no longer emits a spurious leave+join.

**Device-state map (`MeshViewModel` + `BackgroundRefreshHandler`):** the App Group
`deviceStates` dictionary is now keyed by `uniqueIdentifier.uuidString` in both the
foreground poll loop and the background handler, which diff it to fire offline/online
notifications. Storage key bumped `deviceStates` → `deviceStatesByID` so a legacy
name-keyed blob is ignored rather than misread (which could have fired false
offline alerts on first launch after update).

**Blast radius checked:** only `BackgroundRefreshHandler` reads `deviceStates`
(widget reads the snapshot, not this map); no tests touch these internals;
`notifyDeviceOffline(_:room:deviceID:)` call site matches. Behind a single-home
setup the observable behavior is identical; the win shows up with duplicate names,
renames, and (later) multi-home.

**Still open (P1 remainder):** namespace persisted keys by `HMHome.uniqueIdentifier`
before promoting multi-home. Verify with `make ci` before committing.

---

## Phase 8 — Iteration 13 (2026-07-11: test coverage sweep)

Systematically expanded the unit-test suite to cover all observable stores and the
core session manager. All tests use injectable stores (temp-file–backed) so they
run in complete isolation; no shared state or mocking.

**New test suites (Swift Testing `@Suite`):**
- `HealthHistoryStoreTests` — 5-minute throttle, cap enforcement, restore/cutoff, clearAll
- `ActivityStoreTests` — record ordering, 500-event cap, restore, 7-day cutoff, clearAll
- `AchievementStoreTests` — unlock idempotency, 5/10-device thresholds, restore/merge
- `HealthStreakStoreTests` — consecutive-day streak, same-day no-double-count, reset, totalADays
- `DeviceNotesStoreTests` — set/trim/debounce-key, clear, restore
- `WeeklyReportStoreTests` — generate-on-nil, 23-hour cooldown, stale replacement, persist-across-restart
- `SurveySessionManagerTests` — 11 tests covering `recordSample` (min samples, no duplicate coords,
  cap enforcement), `endSession` (7 cases including empty/GPS/coord variants), `startSession` reset.
  Uses `@MainActor` (`CLLocationManager` requires main thread); bypasses location tracker by passing
  explicit coordinates directly.

**`WeeklyReportStore` made injectable:** `init(storeURL: URL? = nil)` pattern
(shared instance keeps Documents path); `generateIfNeeded(now: Date = Date())` for
deterministic cooldown testing; `makeTestInstance()` static factory.

**`SurveySessionManager` `@MainActor`:** class required `@MainActor` isolation for
`CLLocationManager` — added annotation; all existing call sites were already on the
main actor so no behavior change.

---

## Phase 8 — Iteration 14 (2026-07-11: Dynamic Type audit — P5.1)

Audited all Swift source files for hardcoded `.font(.system(size: N))` literals.
Found 25 instances across 4 files. Replaced every one with either:
- **`@ScaledMetric`** (Canvas contexts, where semantic styles cannot be used directly)
- **Semantic text styles** (`.caption`, `.caption2`, `.system(.title, ...)` with `minimumScaleFactor`)

**Files changed:**
- `DeviceStatsStore.swift` (`SignalSparklineView`) — Canvas p50/p95 and Y-axis labels:
  `@ScaledMetric(relativeTo: .caption2) private var sparklineLabelSize: CGFloat = 7`
- `MeshGraphView.swift` — two `@ScaledMetric` properties (`canvasNodeLabel`, `canvasRoomLabel`)
  accessible by the Drawing/Layout extensions via `self`
- `MeshGraphView+Drawing.swift` — room zone label and node label switched from literals
  to `canvasRoomLabel`/`canvasNodeLabel + offset`
- `DashboardSections.swift` (`DashboardHealthHistorySection`) — chart axis `AxisValueLabel`:
  `@ScaledMetric(relativeTo: .caption2) private var chartAxisFont: CGFloat = 7`
- `ThreadMapperWidget.swift` (all 4 widget views) — grade letter literals (20/26/28 pt)
  replaced with `.system(.title3/.title, design: .rounded, weight: .black)` +
  `minimumScaleFactor(0.5).lineLimit(1)`; status/label sizes replaced with
  `.caption`, `.caption2` semantic styles

Closes P5.1. Widget grade letter now scales with the user's preferred text size while
`minimumScaleFactor` prevents overflow in the fixed widget canvas.

---

## Phase 8 — Iteration 15 (2026-07-13: quick wins + confetti + Spotlight)

**Correctness fixes:**
- `HealthHistoryStore.Entry.id` changed from `var id: Date { timestamp }` (duplicate
  timestamps broke `Identifiable`/`ForEach`) to `let id: UUID`. Custom `init(from:)`
  falls back to `UUID()` if `id` key is absent, so existing persisted JSON migrates
  silently on first launch.
- Onboarding Skip button: removed `#if DEBUG` gate so release users can skip the
  three-screen onboarding without paging through all screens.
- README: corrected "Force-directed layout" → "Hierarchical room-based layout",
  replaced `xcodegen`/`.xcodeproj` build instructions with SPM workspace commands,
  removed stale "Iteration 3 (next)" roadmap section.

**Feature: confetti on grade improvement (#53)**
`ConfettiView` — 60-particle Canvas animation driven by `TimelineView` at 60 fps.
Particles rain from the top edge with randomized horizontal drift, spin, size, and
per-particle stagger delay. Fade-out starts at 1.8 s; auto-dismisses at 2.6 s by
clearing its binding. Respects `accessibilityReduceMotion` — no animation when
enabled.

`DashboardView` watches `health.grade` via `onChange`. Changes before the first
scan completes (`hasCompletedFirstScan`) are ignored to prevent cold-start false
positives. Only improvements (`gradeRank(new) > gradeRank(old)`) trigger the burst.

**Feature: Spotlight device indexing (#57)**
`SpotlightService` — `CSSearchableItem` per device in the domain
`com.tintronixlab.ThreadMapper.devices`. Each item carries: title = device name,
contentDescription = room + role (Border Router / Router / Thread Device), keywords
(room, "Thread", "HomeKit"). Indexed via `CSSearchableIndex.default()` whenever
the device graph rebuilds (`mergeDevices` detects a change). Domain is cleared if
the device list drops to empty. No Info.plist changes required; `CoreSpotlight`
handles the user-activity type automatically.

**Remaining open items (pre-submission):**
- P1.2: namespace persisted store keys by `HMHome.uniqueIdentifier` (multi-home
  safety — needs migration strategy design before implementing)
- P2.5: singleton DI container — deferred; test suite coverage makes this lower risk
  but still not a pre-submission blocker
- P5.3: iPad/landscape layout — deferred; needs explicit layout design
- Widget "Updated X ago" `.relative` edge case (show "just now" floor)

## Phase 8 — Iteration 16 (2026-07-13: Swift strict-concurrency audit — P4.1)

**Goal:** resolve all strict-concurrency warnings (those that would be errors in
Swift 6) and lock in enforcement via `Package.swift`.

**Changes (7 files):**
- `AppGroupStore`: `nonisolated(unsafe)` on `lastReloadAt`/`lastContentHash` — both
  are always mutated inside `@MainActor` call sites but the enum itself is unisolated.
- `ThreadDevice`: added `@unchecked Sendable` — `final class` accessed exclusively
  through `@MainActor` contexts; the unchecked annotation is sound.
- `DemoDiscoveryService`: `@unchecked Sendable` — same reasoning; `var devices` only
  mutated via `await MainActor.run` inside `startScanning()`.
- `MatterDiscoveryService`: `@unchecked Sendable` — `@Observable` class whose
  mutable properties are always written from `Task { @MainActor in ... }` blocks.
- `MeshViewModel`: added `@MainActor` isolation — the class was already effectively
  main-actor-only (all meaningful work happens in `await MainActor.run { }` blocks);
  making this explicit silences all `capture of 'self' with non-Sendable type` warnings
  and makes the actor requirement clear at the declaration site.
- `SurveyViewModel.isoFormatter`: `nonisolated(unsafe)` — `ISO8601DateFormatter` is
  not `Sendable`, but this instance is effectively immutable (never re-assigned after
  creation).
- `Package.swift`: `.enableExperimentalFeature("StrictConcurrency")` added to both
  `ThreadMapper` and `ThreadMapperTests` targets — prevents regression.

**Round 2 (same iteration):** Six residual warnings from protocol existentials:
- `DiscoveryService`, `DiagnosticsProvider`: added `: Sendable` to the protocol
  declarations; conformers (`NoDiagnosticsProvider`, `ThreadCredentialsService`,
  `BorderRouterClient`) marked `@unchecked Sendable`.
- `SurveyViewModel.loadRecentSamplePoints`: removed redundant `Task { @MainActor in }`
  wrapper — the function is synchronous; dropped `@escaping` accordingly.
- `MeshViewModelOnlyTests`, `ThreadDiagnosticsTests`: added `@MainActor` to test
  classes that construct or call the now-isolated `MeshViewModel`.

**Widget polish:** `MediumWidgetView` "Updated 0 seconds ago" floor — pass `entryDate`
down from `NetworkHealthEntry`; show "Updated just now" when `updatedAt` is within 60 s
of the entry date.

**Result:** 0 strict-concurrency warnings under `SWIFT_STRICT_CONCURRENCY=complete`;
0 navigator issues; all 70 tests pass with 0 failures.

P4.2 (persistence consolidation) evaluated and closed as "hold" — stores are 62–88
lines each with heterogeneous restore logic; a `JSONStore<T>` generic would save ~35
lines across 3 files at the cost of meaningful new indirection.

## Phase 8 — Iteration 17 (2026-07-13: pre-submission audit)

**Goal:** sweep the remaining surface before App Store submission — privacy manifest
placement, background task registration, accessibility, IAP error handling.

**Fixes (6 commits):**

- `Info.plist`: added `UIBackgroundModes: [fetch]` — required for `BGAppRefreshTask`
  to be scheduled by the OS. Without this key the background widget refresh and
  offline-detection tasks would silently never fire.

- `PaywallView`: two IAP robustness fixes:
  1. Product loading failure now shows a "Couldn't load products / Try Again" state
     after the async task completes; previously the `ProgressView` spun indefinitely.
  2. Purchase errors (network failure, payment declined) are no longer swallowed via
     `try?`; surfaced via a standard alert so users understand why a transaction failed.

- `GradeRingView`: `.accessibilityElement(children: .ignore)` + unified label
  ("Network health grade A, score 85 out of 100") — VoiceOver previously read two
  disconnected strings.

- `ConfettiView`: `.accessibilityHidden(true)` — decorative Canvas animation has no
  semantic content; hiding prevents unwanted VoiceOver focus during celebrations.

- `PrivacyInfo.xcprivacy` placement confirmed in Xcode project Resources build phase.

**Verified:** `PrivacyInfo.xcprivacy` present in project Resources. App icon is
1024×1024 universal. All 70 tests pass; 0 navigator issues; 0 strict-concurrency
warnings. `StrictConcurrency` enforced in `Package.swift`.

**Remaining pre-submission open items (deferred):**
- P1.2: multi-home store key namespacing
- P2.5: singleton DI container
- P5.3: iPad/landscape layout

---

## Phase 8 — Iteration 18 (2026-07-13: search, troubleshooter, UX polish)

- **Troubleshooter** (`TroubleshooterView`): expanded problem-type coverage and improved step copy; steps now reflect the specific device role (border router vs end device) for more actionable guidance.
- **Activity Feed** (`ActivityFeedView`): in-list search bar added (`.searchable`) so users can filter events by device name or event type in long activity logs. Event rows polished with relative timestamps.
- **User Manual** (`UserManualView`): comprehensive in-app documentation added covering all major features — dashboard, mesh graph, survey, diagnostics, settings, and troubleshooting — formatted as a scrollable reference guide.
- **Notification Service**: minor fix to notification category registration ordering.
- **Dead code**: removed empty `Untitled.swift` created by Xcode.

---

## Phase 8 — Iteration 19 (Network Diagnostics engine — first pass)

Added a full Network Diagnostics engine and view as the app's deepest technical analysis feature.

**`NetworkDiagnosticsEngine`** — pure analysis engine producing a `Report` from a device list:
- `Recommendation` with priority (critical/high/medium), category, fix steps
- `RoomCoverage` graded A–F per room
- `DeviceHopInfo` (hop count, parent name)
- `ResilienceNode` (critical relay removal impact)
- `SignalTrendAlert` (devices degrading in last 30 min)

**`NetworkDiagnosticsView`** — full-screen sheet with sections: Summary stats, Recommendations, Resilience nodes, Room Coverage, Mesh Depth (hop counts), Channel Analysis, Diagnostic History. "Run Diagnostics" button triggers analysis with a loading state.

**`DiagnosticRunStore`** — `@Observable` singleton persisting scored run history so trend comparisons are possible across sessions.

---

## Phase 8 — Iteration 20 (Diagnostics enhancements — depth, vendor, BR comparison)

Batch of diagnostic depth improvements built on the engine from Iteration 19.

- **Hop-count depth indicators** in `MeshView` / `MeshViewComponents`: each device row in the mesh list now shows its inferred hop distance from the nearest border router (1–5+ hops, color coded green→red). Uses `NetworkDiagnosticsEngine.DeviceHopInfo`.
- **`DeviceDetailView` enhancements**: Mesh Path section (visual hop chain to internet), vendor insight notes (Eve, Nanoleaf, Apple, IKEA, Philips, Aqara, Bosch, Samsung — per-manufacturer tips), Device History section (first seen, offline event count from `ActivityStore`), Border Router Comparison section (side-by-side quality for multi-BR setups).
- **Live OTBR neighbor table** in `DeviceDetailView`: when a border router is configured, shows real Thread neighbor RLOCs with link quality and margin from the OTBR REST API.
- **Share Diagnostic Report**: `ShareLink` in `NetworkDiagnosticsView` exports a plain-text report covering all sections (summary, recommendations, room coverage, mesh depth, signal degradation, partitions).

---

## Phase 8 — Iteration 21 (Matter commissioning history + channel analysis)

- **Device History / Commissioning Timeline** (`DeviceHistoryView`): aggregates `ActivityStore` join/leave/offline events per device into a stability-graded timeline. Shows first seen, last activity, join count, offline count, and a stability grade (A–F). Accessible from the Dashboard.
- **Thread Channel Analysis** in `NetworkDiagnosticsView`: detects channel conflicts (multiple Thread networks on the same channel), shows device distribution per channel, flags non-standard channels (outside 15/20/25 recommended for Thread).

---

## Phase 8 — Iteration 22 (OTBR Dataset Inspector + Commissioning Readiness)

- **Topology Baseline Comparison** in `NetworkDiagnosticsView`: saves a `TopologySnapshot` (device count, router count, channel, recommendations hash) as baseline; subsequent runs show a diff — devices added/removed, grade change, recommendation delta. Surfaced with "Save as Baseline" toolbar button.
- **Failure Impact Analysis** (`NetworkDiagnosticsEngine.ResilienceNode`): identifies routing devices whose removal would isolate downstream end devices; shown as a dedicated section with isolation counts and affected device names.
- **Signal Degradation tracking** (`NetworkDiagnosticsEngine.SignalTrendAlert`): compares recent (last 30 min) vs baseline average RSSI per device; flags devices degrading > 5 dBm with sparkline context.
- **OTBR Thread Dataset Inspector** (`CommissioningReadinessView`): when an OTBR is configured, fetches and displays the active dataset (network name, channel, PAN ID, ext PAN ID, mesh-local prefix, key rotation interval, RLOC16, role). Includes commissioning readiness checklist and a "Test Connection" button.

---

## Phase 8 — Iteration 23 (Network Timeline + diagnostics polish)

- **Network Timeline** (`NetworkTimelineView`): health score chart (Swift Charts line graph) overlaid with event markers from `ActivityStore` — offline events, topology changes, health degradation/improvement — giving a visual history of what happened when. Accessible from the Dashboard or Activity Feed.
- **Expandable fix instructions** in `NetworkDiagnosticsView`: each recommendation row expands inline to show numbered fix steps; chevron rotates with spring animation. Steps are now populated by the engine for all recommendation types.
- **Room Signal History sparklines** in `NetworkDiagnosticsView`: the Room Coverage section gains per-room trend sparklines built from `DeviceStatsStore` readings, showing whether coverage is improving or degrading over the session.
- **Thread Network Partition Detection** (`NetworkDiagnosticsEngine.NetworkPartition`): BFS from all border routers across inferred topology links; devices with no path to any border router are reported as isolated clusters with a suggested gateway device.
- **Diagnostic Run History** with scored trend chart: `DiagnosticRunStore` stores scored runs (redundancy/coverage/interference/performance dimensions); the history section in `NetworkDiagnosticsView` shows a 4-line Swift Charts chart of dimension scores over time.
- **Mesh Quality Scorecard** in `NetworkDiagnosticsView`: 4-dimension fitness breakdown (Redundancy, Coverage, Interference, Performance) each graded A–F, shown as a grid with color-coded grade rings.

---

## Phase 8 — Iteration 24 (firmware tracking + device protocol compatibility)

Closed the two remaining unimplemented items from the original Phase 3 Matter feature brainstorm.

**Firmware Tracking:**
- `ThreadDevice.firmwareVersion: String?` — captured from `HMAccessory.firmwareVersion` in `MatterDiscoveryService`; sample versions added to all 8 `DemoDiscoveryService` devices.
- `FirmwareHistoryStore` — `@Observable` singleton recording version-change entries per device UUID. First observation silently seeds the baseline; subsequent changes (detected in `MeshViewModel.mergeDevices`) are logged with from/to versions and timestamps. Persisted with `.completeFileProtection`.
- `DeviceDetailView.firmwareSection` — shows current version; "Version History" button opens `FirmwareHistorySheet` (change log with from→to arrows and dates).
- `NetworkDiagnosticsView.firmwareOverviewSection` — lists all devices with reported firmware, shows recent update events with from/to versions.

**Device Protocol Compatibility:**
- `DeviceProtocol` enum (`threadBorderRouter / threadNative / matterBridge / zigbeeBridge / homeKitOnly / unknown`) added to `ThreadDevice.swift` with icon, color, shortLabel, detail, and `isThreadParticipant` properties.
- `ThreadDevice.deviceProtocol` — computed from manufacturer + role flags; correctly identifies Zigbee bridges (IKEA, Philips Hue), Thread BRs (Apple, Samsung), Matter bridges (Aqara), and Thread-native devices (Eve, Nanoleaf, Bosch).
- `DeviceDetailView.compatibilitySection` — shows protocol badge with icon and description; Zigbee bridges show an additional warning that downstream devices are not on the Thread mesh.
- `NetworkDiagnosticsView.compatibilityOverviewSection` — groups all devices by protocol, shows Zigbee/HomeKit-only callouts with actionable advice, and a "N of M Thread" summary in the header.
- Settings → About now links to `UserManualView`.

**Open items (continuing):** P1.2 multi-home namespacing, P2.5 DI container, P5.3 iPad/landscape layout.
