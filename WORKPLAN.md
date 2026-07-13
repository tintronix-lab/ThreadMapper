# ThreadMapper — Optimization Work Plan

**Date:** 2026-07-09 · **Author role:** Principal iOS Engineer (pre-App-Store technical review)
**Scope:** full Swift package + app/widget targets (~9,100 LOC, iOS 17+, SwiftUI + HomeKit/Matter)
**Method:** `ios-codebase-optimizer` — Discover → Inspect → Improve → Refactor → Modernize → UX → Loop

> Companion to `REVIEW.md` (the living review log). This document is the forward-looking, prioritized backlog and records what shipped in this pass.

---

## Current state (assessment)

The codebase is in good shape and has already absorbed the highest-severity items from the original review. Verified as **already fixed** in the current tree:

- **Widget reload storm** — snapshot writes are diffed and throttled in `AppGroupStore`; the 1 Hz loop no longer calls `reloadAllTimelines()` every tick.
- **Metadata propagation (H2)** — `MeshViewModel` now merges HomeKit updates in place per `@Observable` property (name, room, channel, battery, roles) instead of relying on `ThreadDevice.==`.
- **Idle backoff** — the poll loop sleeps while backgrounded (`isAppActive`).
- **Helper duplication** — `gradeColor`/`roomIcon` consolidated into `Shared/TMStyle`; the widget forwards to it.
- **Health-score churn (D4)** — `health` is reassigned only when it actually changes.

What remains is mostly **maintainability, testability, and identity-correctness** debt — no longer crash-class, but worth clearing before scaling past a single home.

---

## Shipped this pass (safe, behavior-preserving)

Low-risk changes requiring no design decisions. All preserve existing behavior; each clears a real (opt-in-enabled) SwiftLint warning or removes dead code.

| # | Change | File |
|---|--------|------|
| S1 | Removed dead `rebuildGraph()` (never called; `applyFilters()` is the live path) | `ViewModels/MeshViewModel.swift` |
| S2 | `task as!` → safe `guard let` with completion on mismatch | `ThreadMapperApp/BackgroundRefreshHandler.swift` |
| S3 | `values.min()!/.max()!` → guarded bindings | `Services/DeviceStatsStore.swift` |
| S4 | `historyEntries.last!/.first!` → `if let` bindings | `Services/WeeklyReportStore.swift` |
| S5 | `lats/lngs.min()!/.max()!` → guarded bindings | `Views/SurveyWalkView.swift`, `Views/SurveyMapView.swift` |

**Verify in Xcode:** `make ci` (swiftlint + build + test). Expected: fewer `force_unwrapping`/`force_cast` warnings, no behavior change, tests still green.

---

## Backlog (prioritized)

### P1 — Correctness & identity

1. ~~**Kill name-keyed identity.**~~ **Done ✓** Switch join/leave detection and device-state maps to `uniqueIdentifier`; carry display name alongside.
2. **Multi-home safety.** Stores keyed by device name/UUID assume one home; `accessoryCache` merges homes. Namespace persisted keys by `HMHome.uniqueIdentifier` before promoting multi-home as a feature. *(deferred — needs migration strategy)*

### P2 — Maintainability & testability

3. ~~**Decompose the `MeshViewModel` poll loop.**~~ **Done ✓** Extracted pure functions; loop kept as orchestrator.
4. ~~**Break up the large views.**~~ **Done ✓** Subviews extracted from `DashboardView`, `MeshView`, `MeshGraphView`, `SurveyWalkView`.
5. **Reduce singletons for testability.** ~11 `static let shared` stores. Introduce a lightweight DI container so views and the view model can be tested with fakes. *(deferred pre-submission)*
6. ~~**Dead-code sweep.**~~ **Done ✓** Removed `RoomFilterView`, `Utils/ThreadMapperError`, and stale verification scripts.

### P3 — Performance

7. ~~**Gate the 1 Hz MainActor work.**~~ **Done ✓** Only recomputes aggregates + snapshot when devices/health actually change.
8. ~~**Force-directed layout off the main thread.**~~ **Done ✓** Layout runs on background task; positions published to main actor.

### P4 — Modernization (verify deployment target first)

9. **Swift Concurrency correctness.** Audit for `Sendable`/actor isolation on the shared stores; the poll loop hops MainActor frequently — consider an `actor` for the sampling/merge core. Adopt strict-concurrency checking incrementally.
10. **Persistence consolidation.** Multiple hand-rolled `Codable`/`JSONSerialization` stores with debounced writes. Evaluate a single SwiftData store or at least a shared `JSONStore<T>` generic to remove per-store boilerplate.

### P5 — UX & accessibility

11. ~~**Dynamic Type.**~~ **Done ✓** (Iteration 14) 25 hardcoded font sizes replaced with scaled text styles across 5 files.
12. ~~**Contextual permissions.**~~ **Done ✓** Location requested at survey start, not app launch.
13. **iPad/landscape.** Reconsider portrait-only + `UIRequiresFullScreen`. *(deferred — needs layout design decisions)*
14. ~~**Data honesty copy.**~~ **Done ✓** Latency-derived values consistently labeled "Response Quality" across all views.

---

## How to run each iteration

1. Pick the top unblocked item.
2. Make the change in small, verifiable commits.
3. `make ci` (or `make ci-xcode` for the simulator test action) after each batch.
4. Log the outcome as a new iteration entry in `REVIEW.md`.
5. Re-scan for opportunities the change created; repeat.

**Environment note:** this pass was prepared in a Linux sandbox with no Swift/Xcode toolchain, so changes were validated by static analysis and guard-invariant reasoning rather than a compiler. Run `make ci` locally to confirm before committing.
