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
