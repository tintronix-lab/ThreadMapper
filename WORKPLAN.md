# ThreadMapper — Active Backlog

**Last updated:** 2026-07-23 (Iter 62 — AI-D2/D4/D5/D7/D10)  
**Engineering log:** `REVIEW.md` (full iteration history, Iterations 1–26+)

---

## Shipped (summary — see REVIEW.md for details)

| Iteration | What shipped |
|---|---|
| 1–13 | Core architecture, MVVM, concurrency, widget, force-unwrap sweep, dead-code, test suite |
| 14 | Dynamic Type audit — 25 hardcoded font sizes → scaled styles (P5.1) |
| 15 | Confetti on grade improvement (#53), Spotlight device indexing (#57), correctness fixes |
| 16 | Swift strict-concurrency audit, zero warnings under `complete`, widget "just now" floor (P4.1) |
| 17 | Pre-submission audit — privacy manifest, IAP error handling, GradeRingView a11y, background modes |
| 18 | Troubleshooter expanded, Activity Feed search, in-app User Manual |
| 19 | NetworkDiagnosticsEngine (full), NetworkDiagnosticsView, DiagnosticRunStore |
| 20 | Hop-count indicators, DeviceDetailView vendor/history/BR-comparison, OTBR neighbor table, Share report |
| 21 | Device History / Commissioning Timeline, Thread Channel Analysis |
| 22 | Topology Baseline Comparison, Failure Impact Analysis, Signal Degradation tracking, OTBR Dataset Inspector |
| 23 | Network Timeline, expandable fix instructions, Room Signal History sparklines, Partition Detection, Diagnostic Run History, Mesh Quality Scorecard |
| 24 | Firmware tracking (FirmwareHistoryStore + DeviceDetailView + NetworkDiagnosticsView), Device Protocol Compatibility (DeviceProtocol enum, compatibility sections) |
| 25 | iPad NavigationSplitView + landscape orientation — AppTab enum, iPadLayout/iPhoneLayout, Info.plist (P5.3) |
| 26 | Firmware section always visible, HomeKit characteristic fallback for firmware version |
| 27 | Smart Home Advisor — PlacementSuggestion / AutomationSuggestion / SceneRecommendation engine + view |
| 28 | AI Insights — FoundationModels-powered MeshSummary + PredictiveAnalysis (iOS 26 only) |
| 29 | Notification deep linking, pull-to-refresh (Dashboard + Mesh), accessoryInline widget, Activity feed export |
| 30 | MeshView list-mode search — live filter by device name with empty state + clear button |
| 31 | Resilience Simulator — "What If" BFS impact analysis for border routers + relays; shield button in Mesh filter bar opens sheet with severity-grouped node list + per-node impact detail |
| 32 | Channel Interference Scanner — Canvas spectrum bar chart (ch 11–26 coloured by Wi-Fi overlap risk, Wi-Fi band zone shading, in-use markers, ★ recommended channel); Tools menu in Mesh filter bar replaces single shield button |
| 33 | BR Health Monitor — per-BR card with online/offline badge, RSSI sparkline (DeviceStatsStore), last-seen timestamp, "Only BR" + critical-offline warnings; added to Mesh Tools menu |
| 34 | New Device Alert — KnownDeviceRegistry (UserDefaults-persisted Set<UUID>); first-tick marks all devices known; subsequent joins checked cross-session; fires "New Thread Device Detected" push notification; toggle in Settings |
| 35 | Battery Life Estimator — days-remaining estimate for sleepy end devices in DeviceDetailView battery section; linear model (90-day typical profile); footer caveat; colour-coded urgency |
| 36 | Anomaly Detection Engine — `AnomalyDetector` computes per-device `DeviceTrajectory` (.stable/.declining/.critical) from `DeviceStatsStore` rolling baseline vs recent window; trajectory arrows in Mesh device rows; `DashboardAnomalyBanner` surfaces degrading devices |
| 37 | Conversational Network Assistant — `NetworkAssistantView` full chat UI with FoundationModels `LanguageModelSession`; context-injected system prompt with live mesh state + anomalies; suggested question chips; typing indicator; accessible from AI Insights |
| 38 | Structured @Generable Output — `OptimizationPlan` + `ActionableInsight` typed structs replace prose; ranked action cards with impact level + estimated % improvement; `RootCauseHypothesis` for correlated multi-device issues |
| 39 | Root Cause Correlation — `AINetworkAnalyzer.rootCauseAnalysis` fires when ≥2 devices are degrading simultaneously; `RootCauseCard` section in AI Insights shows root cause, affected devices, confidence, fix |
| 40 | Proactive Push Insights — `notifyProactiveInsight` in `NotificationService`; `MeshViewModel.fireProactiveAnomalyAlert` fires push when new critical anomalies appear; "Proactive AI insights" toggle in Settings |
| 41 | MeshView Map Export — `ImageRenderer` captures `MeshGraphView` Canvas at 2× scale (1024×768 pt); "Export Map" item in Mesh Tools menu (map mode only); `MeshMapShareSheet` previews image + `ShareLink` share button |
| 42 | Per-Device AI Assistant — "Ask AI about this device" section in DeviceDetailView; `NetworkAssistantView` accepts `focusDevice` parameter; session pre-seeded with device RSSI, battery, anomaly trajectory, role; auto-asks opening question |
| 43 | AI Weekly Digest — `scheduleWeeklyReportWithAIHeadline` generates an AI-written one-sentence summary using `HealthHistoryStore` trend data; used when toggling the weekly report in Settings; falls back to generic copy if AI unavailable |
| 44 | Live Activities — `ThreadNetworkActivityAttributes` (Shared); `LiveActivityManager` starts an ActivityKit Live Activity when a device goes offline after grace period; Dynamic Island shows grade letter (compact leading), offline count (compact trailing), full health in expanded; Lock Screen banner with grade circle + device/offline counts; activity ends 10 s after all devices come back online; `NSSupportsLiveActivities` added to Info.plist |
| 57 | AI-B1: Commissioning coach — `@Generable CommissioningBriefing`; `CommissioningBriefingStore`; triggered by `MeshViewModel` on first-seen join; dismissible card in `ActivityFeedView` "New Device" section |
| 56 | AI-B2: NL device queries — `@Generable NLDeviceFilter` (room/role/status/minHops/sort/battery); `AINetworkAnalyzer.parseNLFilter`; `MeshView` list search bar gets sparkles button + filter-active chip + match count; `applyNLFilter` + `clearNLFilter`; Pro + iOS 26 gated |
| 55 | AI-A3: Contextual metric explanation ("Explain This") — long-press signal stat cells (Live/Avg/Min/Max) or hop count row in `DeviceDetailView`; `MetricExplanationContext` struct; `AINetworkAnalyzer.explainMetric`; compact half-sheet with sparkles header; Pro + iOS 26 gated |
| 54 | AI-A1: Predictive failure prevention — OLS linear trend projection in `AnomalyDetector` (`projectHoursToFailure`); `projectedHoursToFailure: Double?` added to `DeviceAnomaly`; projection surfaced in `DeviceDetailView` signal section (triangle warning, time label, caption); passed into `AINetworkAnalyzer.deviceSummary` prompt so AI narrates the estimate; capped at 14 days; floored at 30 min |
| 45 | Control Center — `ScanNetworkControl` (`ControlWidget`, iOS 18+) with `OpenThreadMapperIntent` (`openAppWhenRun = true`); "Thread Network" button in Control Center opens ThreadMapper; added to `ThreadMapperWidgetBundle` behind `if #available(iOS 18.0, *)` |
| 46 | Positive Notifications — `notifyGradeImproved(from:to:)` fires when grade letter improves (gated on "Mesh health grade changes" toggle — same as drops); `notifyAllDevicesOnline(count:)` fires when last offline device recovers (gated on "Offline alerts" toggle); `hadOfflineDevices` flag prevents spurious "all online" fires; Settings label updated to "Mesh health grade changes" |
| 47 | Device Reliability Score — `reliabilitySection` in `DeviceDetailView`; filters `ActivityStore.events` by device UUID + kind (offline/BR-offline) for last 30 days; shows colour-coded reliability label (Excellent→Needs Attention), 30-day offline event count, and online streak (days since last offline event) |
| 48 | Shareable Network Health Card — `NetworkHealthCardView` (375×667 pt gradient card with grade hero, score bar, device/offline stat badges, branding); `ImageRenderer` renders at 2× scale from Dashboard "Share Health Card" toolbar button; `HealthCardShareSheet` previews image + `ShareLink` |
| 49 | AI Device Health Summary — auto-generated 2-sentence plain-English assessment per device; loads on `DeviceDetailView` appear via `AINetworkAnalyzer.deviceSummary(device:anomaly:stats:offlineCount:)`; shows in "AI Device Summary" section (sparkles header) above the AI chat button; iOS 26+, gated with `#available` |
| 50 | AI Activity Digest — `AINetworkAnalyzer.activityDigest(events:devices:)` summarises the 10 most recent events in 2 sentences; appears as a purple sparkles section at the top of `ActivityFeedView` when ≥3 events exist; reloads when event count changes; iOS 26+ |
| 51 | Mesh Expansion Advisor — `@Generable MeshExpansionPlan` (max 2 `ExpansionSpot`s with location, deviceType, reason, expectedBenefit); `AINetworkAnalyzer.meshExpansionPlan(devices:health:report:)` uses room coverage gaps, high-hop devices, and weak-signal rooms; shown in new "Mesh Expansion Advisor" section in `AIInsightsView`; runs in parallel with other analyses |
| 52 | AI Streaming Chat — `NetworkAssistantView` now uses `session.streamResponse(to:)` instead of `respond(to:)`; tokens stream into a live `StreamingBubbleView` (blinking cursor, scrolls as text grows) replacing the dots `ThinkingBubbleView`; on completion the final `ChatMessage` is appended and the streaming view clears; `Snapshot.content` used to access `String.PartiallyGenerated` from `ResponseStream<String>` |
| 53 | Interactive Widget — `RefreshWidgetIntent` (`AppIntent`, `openAppWhenRun = true`) added to widget bundle; `Button(intent: RefreshWidgetIntent())` arrow-clockwise icon in medium widget's "Updated" row lets users tap to open app and refresh from Home Screen; existing `widgetURL` tap still works for the rest of the widget |
| 58 | 30-Day History (Pro) — `TimeRange.month` ("30D") in `NetworkTimelineView` gated by `ProStore.isPro` → `PaywallView` (tap intercepted via `onChange`, selection reverts); `HealthHistoryStore` retention 7→30 days (`maxEntries` 8640) with new `downsampled(_:bucket:)` hourly averaging for the 30D chart; `WeeklyReportStore.generate` now filters history to 7 days (was silently relying on store retention); "30-Day History" paywall feature row |
| 59 | Resilience Simulator AI Narration (AI-B3) — `@Generable ResilienceNarration` struct with `scenario` + `fallback` fields; `AINetworkAnalyzer.resilienceNarration(impact:)` + `buildResiliencePrompt` private helper; `ImpactDetailView` gains "AI Impact Analysis" section (sparkles icon, loading spinner, scenario + fallback text) between Impact Summary and Affected Devices; Pro + iOS 26 gated via `.task` |
| 60 | AI-B4 + Self-Learning + Self-Healing — `AIMemoryStore` persists per-device observations (anomaly/offline/resolved) with 30-day retention and 10-min dedup; `MeshViewModel` records trajectory changes + offline events; `deviceSummary` injects memory fragment; `@Generable MaintenancePlan` + `MaintenanceCalendarView` (tasks grouped by Today/This week/This month); `@Generable AutoHealReport` + `HealingRecommendation`; "Self-Healing Insights" section + "Maintenance Calendar" link in `AIInsightsView`; `AutoHealRows` + `AIInsightsLinkRow` components |
| 61 | NF-2 through NF-10 — Per-Room Health Grid (`DashboardRoomHealthGrid`); Topology Change Digest on cold launch (`TopologyChangeDigestView` + `TopologyChangeSummary` AI); Background Health Watchdog (`BGProcessingTask` + `HealthWatcher` grade-drop notification); Router Saturation Monitor (NF-6 fix — `RouterSaturationSection` + `RouterLoadRow`); HomeKit Scene Triggers (`HomeKitSceneTriggerStore` + `HomeKitSceneTriggerView` in Settings); Battery Radio Efficiency Score (`radioEfficiency` row in `DeviceDetailView`); Diagnostic PDF Export (`DiagnosticPDFExporter` 3-page PDF via `UIGraphicsPDFRenderer`); Topology Time-Lapse (`TopologyTimeLapseStore` 720-frame ring buffer + `MeshTopologyRewindView` scrubber in Mesh Tools) |
| 62 | AI-D2/D4/D5/D7/D10 — Alert Urgency Scoring (`AlertScore` @Generable + `notifyDeviceOfflineAIScored` async); Weekly Health Coach (`CoachingPlan` + `CoachingAction` @Generable; coach card in `WeeklyReportView`); Anomaly Pattern Recognition (`AnomalyPattern` @Generable; pattern card in `DeviceDetailView`); AI Troubleshooter (`TroubleshootingGuide` + `AITroubleshootingStep` @Generable; AI diagnosis card in `TroubleshooterView`); Network Storyteller (`NetworkNarrative` @Generable; story section in `NetworkTimelineView`); paywall updated +5 rows; README + CHANGELOG + UserManualView updated |

---

## Open Items

### P0 — Active (implement next)

| # | Item | Notes |
|---|------|-------|
| ✓ | Channel Interference Scanner | **DONE** — Iter 32 |
| ✓ | Border Router Health Monitor | **DONE** — Iter 33 |
| ✓ | MeshView map export | **DONE** — Iter 41 |
| ✓ | Widget deep link — tapping widget opens Dashboard | **DONE** — already implemented (`widgetURL` + `onOpenURL`) |
| ✓ | Siri App Shortcut "Check my Thread network" | **DONE** — `NetworkHealthIntents.swift` (pre-existing) |

### P1 — Deferred (needs design before implementing)

| # | Item | Blocker |
|---|------|---------|
| ✓ | New Device Alert | **DONE** — Iter 34 |
| ✓ | Battery Life Estimator | **DONE** — Iter 35 |
| P1.2 | Multi-home store key namespacing | Needs migration strategy — `HMHome.uniqueIdentifier` prefix on all persisted keys; existing data must be promoted silently on upgrade |
| P2.5 | Singleton DI container | Low risk with current test suite; revisit if test coverage expands significantly |

### Already shipped (tools brainstorm cross-reference)

| Tool idea | Shipped as |
|---|---|
| Coverage Heatmap / Walk Mode | Iter 21 — `SurveyWalkView`, `GuidedSurveyView`, `SurveyHeatmapPresenter` |
| Resilience Simulator | Iter 31 — `ResilienceSimulator` + `ResilienceSimulatorView` |
| Long-term Trend Charts | Iter 23 — `NetworkTimelineView`, `HealthHistoryStore`, room sparklines |
| Commissioning Assistant | `CommissioningReadinessView` |
| Network Report Export | Iter 20 — Share report in `NetworkDiagnosticsView` |
| Scheduled Network Audit | `WeeklyReportStore` + `WeeklyReportView` |

### P2 — Out of scope (App Store Connect, not code)

- App Store Connect Pro product setup (requires Apple Developer Portal)
- Localization / internationalisation strings

---

## New Feature Backlog (brainstorm 2026-07-23)

Ten net-new ideas ranked roughly by user impact. None of these overlap with the AI Roadmap below.

| # | Feature | Why | Implementation sketch |
|---|---------|-----|----------------------|
| ✓ NF-1 | **Apple Watch Companion** | **DONE** — 2026-07-23. `ThreadMapperWatch` target; `WatchConnectivityManager` iPhone-side; `WatchConnectivityStore` + `WatchDashboardView` on Watch; `ThreadMapperWatchWidget` WidgetKit complications (circular/inline/rectangular). |
| ✓ NF-2 | **Per-Room Health Grid** | **DONE** — Iter 61. `DashboardRoomHealthGrid` with grade cards A–F; tap → room filter. |
| ✓ NF-3 | **Topology Change Digest on Cold Launch** | **DONE** — Iter 61. `TopologyChangeDigestView` sheet on re-open after >1 h; `TopologyChangeSummary` AI narration (iOS 26+ Pro). |
| ✓ NF-4 | **Background Health Watchdog** | **DONE** — Iter 61. `BGProcessingTask` (`healthwatch`) + `HealthWatcher`; grade-drop local notification; `processing` background mode added to Info.plist. |
| NF-5 | **iCloud Sync** | Households have multiple iPhones/iPads — notes and custom names should follow the user | CloudKit `CKRecord` sync for `DeviceOverrideStore` (custom names), `DeviceNotesStore`, `AIMemoryStore` observations, and survey session list; conflict resolution: latest-write-wins with timestamp |
| ✓ NF-6 | **Router Saturation Monitor** | **DONE** — Iter 61. `RouterSaturationSection` + `RouterLoadRow` in `BRHealthMonitorView`; progress bars per router; overload warning at 80%. |
| ✓ NF-7 | **HomeKit Scene Triggers** | **DONE** — Iter 61. `HomeKitSceneTriggerStore` + `HomeKitSceneTriggerView` in Settings; grade threshold picker (C/D/F); fires `HMHome.executeActionSet` when grade crosses threshold. |
| ✓ NF-8 | **Battery Radio Efficiency Score** | **DONE** — Iter 61 (prev session). `radioEfficiency` row in `DeviceDetailView` battery section for sleepy end devices. |
| ✓ NF-9 | **Full Diagnostic PDF Export** | **DONE** — Iter 61. `DiagnosticPDFExporter` generates 3-page PDF (summary + grade, device inventory, recommendations) via `UIGraphicsPDFRenderer`; "Export Diagnostic PDF" in Dashboard toolbar. |
| ✓ NF-10 | **Mesh Topology Time-Lapse** | **DONE** — Iter 61. `TopologyTimeLapseStore` 720-frame ring buffer (50-min dedup); `MeshTopologyRewindView` with slider + play/pause; accessible from Mesh Tools menu. |

---

## New Feature Backlog — Round 2 (brainstorm 2026-07-23)

Ten more ideas based on gaps identified after NF-1–10. All are net-new and don't overlap with the AI Roadmap.

| # | Tier | Feature | Why users need it | Implementation sketch |
|---|------|---------|-------------------|----------------------|
| NF-11 | Pro | **Multi-Home Support** | Users with a vacation home or office have multiple HomeKit homes — currently ThreadMapper only shows the "primary" home. | Add a home picker (segmented or `Menu`) to the tab-bar header; scope all data stores (`HealthHistoryStore`, `DeviceStatsStore`, `ActivityStore`, notes) to `HMHome.uniqueIdentifier` as a key prefix; `PersistedStore` already supports arbitrary keys so no migration risk. Pro feature. |
| NF-12 | Pro | **Mesh Health Calendar (365-Day Heatmap)** | Weekly chart only shows 24h; 30-day chart shows trends but not patterns. A GitHub-style contribution grid lets users see which *days of the week* or *seasons* their mesh is worst. | `HealthHistoryStore` already stores per-minute samples; down-sample to daily average grade; render a 52-column × 7-row `LazyVGrid` with colored cells (A=green, B=mint, C=yellow, D=orange, F=red); tap a cell to see that day's activity events; Lives in a new `HealthCalendarView` accessible from Dashboard or Timeline. Pro. |
| NF-13 | Pro | **Signal Quality Drop Alerts** | Offline alerts notify when a device disappears. There's no alert for *degrading but still online* devices — which is often an earlier warning sign. | Extend `NotificationService` with `notifySignalDegraded(device:from:to:)`; `AnomalyDetector` already computes trajectory — fire when trajectory transitions to `.declining` or `.critical` and the device has been below "Fair" quality for >5 minutes; configurable per-device threshold in Device Detail → Notifications; toggle in Settings alongside offline alerts. Pro. |
| NF-14 | Pro | **Scheduled Diagnostic Reports** | Power users and installers want a PDF in their inbox every Sunday without opening the app. | New `ScheduledReportStore` (`@AppStorage` for enabled, frequency: weekly/monthly, last-sent date); `BGProcessingTask` wakes app → runs `DiagnosticPDFExporter` → presents a `UIActivityViewController` on next foreground (Files/Mail/AirDrop). Falls back to a "Tap to share" notification if the share sheet can't show immediately. Pro. |
| NF-15 | Pro | **Custom Device Groups / Labels** | HomeKit rooms describe physical location, but users also think in logical groups: "Critical Infrastructure", "Battery Devices", "Guest Zone". These don't map to rooms. | Add a `groupLabel: String?` field to `DeviceOverrideStore` alongside the existing custom name; UI: long-press a device row → "Assign Group" action sheet with up to 5 user-defined groups + "None"; filter chip in `MeshFilterBar` and device list header for group; groups stored as `Set<String>` in `DeviceOverrideStore`. Pro. |
| NF-16 | Free | **Device Uptime Leaderboard** | Users with many devices don't know which are the "bad actors" causing most alerts. A ranked list makes the problem obvious without hunting through the activity feed. | Filter `ActivityStore.events` by `kind == .offline` per device for the last 30 days; compute `uptimePct = 1 - (offlineSeconds / totalSeconds)` using event timestamps; render a ranked `List` with a percentage bar, colour-coded from green (99%+) to red (<90%); add a "Most Problematic" section at the bottom for devices below 95%. New `DeviceUptimeView` accessible from Dashboard or Devices tab toolbar. Free — it drives upgrade motivation. |
| NF-17 | Pro | **Installer / Technician Export Pack** | Smart home installers and ISPs need a single file to diagnose a customer's mesh remotely. Currently they'd need to manually screenshot + export multiple things. | New "Share with Installer" button in Settings → Tools; generates a ZIP containing: mesh map PNG (`ImageRenderer`), diagnostic PDF (`DiagnosticPDFExporter`), device inventory CSV, and a `network_summary.json` with grade, score, device count, BR count, channel list; shares via `UIActivityViewController`. Pro. |
| NF-18 | Free | **Notification Quiet Hours** | Alert fatigue is real. Users don't want offline notifications at 3am for a sensor that always comes back online. | New `QuietHoursStore` (`@AppStorage`): enabled toggle, start/end time (stored as `Int` hour); `NotificationService.schedule(…)` checks `QuietHoursStore` before posting — if within quiet window, delays delivery to `quietHoursEnd`; configurable in Settings → Notifications. Free quality-of-life improvement. |
| NF-19 | Pro | **Floorplan Signal Overlay** | The survey heatmap is GPS-based (outdoors/large spaces). Indoors, users want to import a floorplan PNG and see signal quality overlaid on their actual house layout. | `FloorplanStore` stores a `UIImage` + two calibration tap points with known real-world coordinates (room corners); `SurveyWalkView` gains a "Map on Floorplan" mode that renders survey points as colored circles on the image; `ImageRenderer` exports the annotated floorplan. Requires photo library permission. Pro. |
| NF-20 | Pro | **HomeKit Scene Health Tracker** | `HomeKitSceneTriggerStore` already *runs* scenes when health drops. But users don't know if those scenes *succeed* or fail — a thread-mesh scene that targets offline devices silently fails. | `HomeKitSceneHealthStore` records each `executeActionSet` call result (success/error) with timestamp; `HomeKitSceneTriggerView` gains a "Recent Triggers" section showing last 10 invocations with outcome badge (green checkmark / red X); fire a push notification if a scene fails 3 times in a row. Pro. |

---

## AI Roadmap

The app is strong on **reactive AI** (explain what happened) and **structured generation**. The gaps are in **predictive AI**, **conversational guidance**, and **ambient/proactive intelligence**. Items below are ordered roughly by implementation difficulty and data-pipeline readiness.

**Status as of 2026-07-23:** 7 done · 2 partial · 3 open (out of 12 items)

### Tier A — Highest ROI, data pipeline already exists

| # | Status | Feature | Implementation notes |
|---|--------|---------|----------------------|
| AI-A1 | ✓ Done | **Predictive failure prevention** | OLS projection in `AnomalyDetector.projectHoursToFailure`; `DeviceAnomaly.projectedHoursToFailure: Double?`; triangle warning row in `DeviceDetailView` signal section; projection injected into `AINetworkAnalyzer.deviceSummary` prompt. Iter 54. |
| AI-A2 | ✓ Done | **Conversational diagnostic sessions** | `NetworkAssistantView` (Iter 37) + streaming (Iter 52) + per-device focus (Iter 42). Core multi-turn chat fully shipped. Note: `TroubleshooterView` decision-tree augmentation (AI asking clarifying questions mid-tree) not wired up — optional follow-on. |
| AI-A3 | ✓ Done | **Contextual metric explanation ("Explain This")** | Long-press Live/Avg/Min/Max signal stat cells or hop count row → compact sheet (`presentationDetents .fraction(0.4)`) with AI 2-sentence explanation; `AINetworkAnalyzer.explainMetric`; `MetricExplanationContext` struct; network-average + trajectory injected into prompt; Pro + iOS 26 gated. Iter 55. |

### Tier B — High value, moderate new work

| # | Status | Feature | Implementation notes |
|---|--------|---------|----------------------|
| AI-B1 | ✓ Done | **AI commissioning coach** | When a device joins for the first time (checked via `KnownDeviceRegistry`), `MeshViewModel` fires `AINetworkAnalyzer.commissioningBriefing` (iOS 26+, Pro); `@Generable CommissioningBriefing` (roleExplanation, topologyFit, recommendation) stored in `CommissioningBriefingStore`; `ActivityFeedView` shows a dismissible "New Device" sparkles card. Iter 57. |
| AI-B2 | ✓ Done | **Natural language device/topology queries** | `@Generable NLDeviceFilter` in `AINetworkAnalyzer` (room, role, status, minHops, sortOrder, batteryPoweredOnly, filterDescription); `parseNLFilter(query:rooms:deviceCount:)`; `MeshView` list-mode search bar upgraded — sparkles button triggers AI parse on iOS 26+/Pro, filter-active chip shows description + match count, `applyNLFilter` maps to `[UUID]` and overrides `roomGroups`, `clearNLFilter` resets both text and filter. Iter 56. |
| AI-B3 | ✓ Done | **Resilience Simulator AI narration** | `@Generable ResilienceNarration` (scenario + fallback) in `AINetworkAnalyzer`; `resilienceNarration(impact:)` + `buildResiliencePrompt`; `ImpactDetailView` adds "AI Impact Analysis" List section with sparkles header, ProgressView while loading, scenario + fallback text; `.task` fires on Pro + iOS 26; state stored as `String?` pairs. Iter 59. |
| AI-B4 | ✓ Done | **Predictive maintenance calendar** | `@Generable MaintenanceTask` + `MaintenancePlan`; `AINetworkAnalyzer.maintenancePlan` pulls firmware age, battery, anomalies, and 30-day offline freq; `MaintenanceCalendarView` groups by timeframe (Today/This week/This month); accessible via NavigationLink in `AIInsightsView` assistant section. Iter 60. |

---

#### AI-B3 — Implementation Detail

**What it produces:** A new "AI Impact Analysis" section inside `ImpactDetailView` (the per-node detail sheet) with two fields from a `@Generable ResilienceNarration` struct:

- **`scenario`** (1–2 sentences) — the human story: which rooms/devices lose connectivity and why it matters. E.g. "Losing the Living Room Relay cuts off 4 bedroom sensors. They'll need to route through the Kitchen Hub, which is already serving 6 devices."
- **`fallback`** (1 sentence) — what coverage remains. E.g. "The Kitchen Hub can reach 2 of the 4 affected devices; the remaining 2 have no alternative path."

Gated: **Pro + iOS 26** (same as AI-A3, AI-B1, AI-B2). No new file, no store — narration is ephemeral per sheet.

##### File 1: `AINetworkAnalyzer.swift`

Add `@Generable ResilienceNarration` struct after `CommissioningBriefing`:

```swift
@available(iOS 26, *)
@Generable(description: "Plain-English story of a Thread mesh resilience simulation")
struct ResilienceNarration {
    @Guide(description: "1–2 sentences describing which rooms and devices lose connectivity if this node is removed, and why it matters. Mention room names. No jargon.")
    var scenario: String

    @Guide(description: "1 sentence on what coverage or fallback path remains. If no border router remains, say the whole network loses internet.")
    var fallback: String
}
```

Add `resilienceNarration` method and `buildResiliencePrompt` private helper.

Prompt data from `ResilienceSimulator.Impact`:

| Prompt field | Source |
|---|---|
| Node name, type, room | `impact.removedNode.{name, kind, room}` |
| Severity | `impact.severity` → "critical / major / minor / safe" |
| End devices cut off | `impact.affectedDeviceCount` |
| Relays lost | `impact.affectedRouterCount` |
| Affected rooms | `Set(impact.affectedNodes.compactMap(\.room))` |
| BRs remaining | `impact.totalBorderRouters - 1` (0 if `isLastBorderRouter`) |

##### File 2: `ResilienceSimulatorView.swift` — `ImpactDetailView`

State additions:
```swift
@Environment(ProStore.self) private var proStore
@State private var narration: ResilienceNarration? = nil   // wrapped in #available block
@State private var isLoadingNarration = false
```

New List section between "Impact Summary" and "Affected Devices":
```swift
if proStore.isPro, #available(iOS 26, *) {
    Section("AI Impact Analysis") {
        if isLoadingNarration {
            HStack { ProgressView(); Spacer() }
        } else if let n = narration {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 6) {
                    Text(n.scenario).font(.subheadline)
                    Text(n.fallback).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```

`.task` on the `NavigationStack`:
```swift
.task {
    guard proStore.isPro else { return }
    if #available(iOS 26, *) {
        isLoadingNarration = true
        narration = try? await AINetworkAnalyzer.resilienceNarration(impact: impact)
        isLoadingNarration = false
    }
}
```

---

### Tier C — Longer-term / needs more design

| # | Status | Feature | Implementation notes |
|---|--------|---------|----------------------|
| AI-C1 | ~ Partial | **AI network journal / changelog** | Iter 43 shipped a one-sentence AI headline for the weekly digest. Missing: the full paragraph-length narrative of what changed (devices joined/left, firmware updates, signal changes, anomalies resolved) stored alongside `WeeklyReportStore`. |
| AI-C2 | Open | **AI device naming suggestions** | When `KnownDeviceRegistry` detects a new unnamed device, AI suggests a friendly name from vendor + role + signal-inferred location. One-tap accept chip in the new-device alert or `DeviceDetailView`. |
| AI-C3 | ~ Partial | **Topology placement assistant (interactive)** | Iter 51 (Mesh Expansion Advisor) covers expansion advice with `@Generable MeshExpansionPlan`. Missing: the interactive map-tap flow — user taps blank area on mesh map → AI explains role, routing, expected hop count for that specific spot. |
| AI-C4 | Open | **Siri deep integration** | Extend existing App Intents with parameter-accepting variants: "Check the status of my kitchen sensor", "Is my border router online?" — AI generates the spoken response via `LanguageModelSession`. Fully on-device, no network required. |
| AI-C5 | ✓ Done | **Cross-session device memory** | `AIMemoryStore` (`AIObservation` with kind/detail/isResolved, `[UUID: [AIObservation]]` persisted via `PersistedStore`); `summaryPromptFragment` injected into `deviceSummary`; `recurringOfflineDevices` feeds AutoHeal; `MeshViewModel` records new anomaly-trajectory changes and offline events; 10-min dedup window; 30-day retention. Iter 60. |
