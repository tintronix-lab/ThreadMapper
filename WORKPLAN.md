# ThreadMapper — Active Backlog

**Last updated:** 2026-07-19 (AI roadmap status audit)  
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

## AI Roadmap

The app is strong on **reactive AI** (explain what happened) and **structured generation**. The gaps are in **predictive AI**, **conversational guidance**, and **ambient/proactive intelligence**. Items below are ordered roughly by implementation difficulty and data-pipeline readiness.

**Status as of 2026-07-19:** 5 done · 2 partial · 5 open (out of 12 items)

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
| AI-B3 | Open | **Resilience Simulator AI narration** | Add AI-generated scenario summary to `ResilienceSimulatorView`: converts raw BFS impact scores into a human story ("Losing this BR isolates 4 bedroom devices; the next-best BR covers 2 of them"). One `AINetworkAnalyzer` call with the existing `SimulationResult`. |
| AI-B4 | Open | **Predictive maintenance calendar** | Combine `FirmwareHistoryStore` age, `DeviceStatsStore` health trends, battery estimates, and `ActivityStore` offline frequency to generate a prioritised weekly/monthly task list. Render as a timeline in a new `MaintenanceCalendarView` (similar structure to `NetworkTimelineView`). |

### Tier C — Longer-term / needs more design

| # | Status | Feature | Implementation notes |
|---|--------|---------|----------------------|
| AI-C1 | ~ Partial | **AI network journal / changelog** | Iter 43 shipped a one-sentence AI headline for the weekly digest. Missing: the full paragraph-length narrative of what changed (devices joined/left, firmware updates, signal changes, anomalies resolved) stored alongside `WeeklyReportStore`. |
| AI-C2 | Open | **AI device naming suggestions** | When `KnownDeviceRegistry` detects a new unnamed device, AI suggests a friendly name from vendor + role + signal-inferred location. One-tap accept chip in the new-device alert or `DeviceDetailView`. |
| AI-C3 | ~ Partial | **Topology placement assistant (interactive)** | Iter 51 (Mesh Expansion Advisor) covers expansion advice with `@Generable MeshExpansionPlan`. Missing: the interactive map-tap flow — user taps blank area on mesh map → AI explains role, routing, expected hop count for that specific spot. |
| AI-C4 | Open | **Siri deep integration** | Extend existing App Intents with parameter-accepting variants: "Check the status of my kitchen sensor", "Is my border router online?" — AI generates the spoken response via `LanguageModelSession`. Fully on-device, no network required. |
| AI-C5 | Open | **Cross-session device memory** | Persist per-device AI observations across sessions (lightweight JSON blobs keyed by device UUID in a new `AIMemoryStore`). When reopening a device chat, assistant proactively references recurring patterns ("This device had packet loss in June — I'm seeing it again"). |
