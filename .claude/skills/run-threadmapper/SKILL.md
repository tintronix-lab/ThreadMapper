---
name: run-threadmapper
description: Run, build, launch, start, screenshot, or test the ThreadMapper iOS app on a simulator. Use when asked to run the app, take a screenshot, verify a UI change, or confirm a feature works.
---

ThreadMapper is an iOS 17+ Thread mesh-network monitor app built with SwiftUI. It is driven via `xcrun simctl` — build with `xcodebuild`, install and launch on a simulator, then screenshot with `simctl io`. The driver script is `.claude/skills/run-threadmapper/smoke.sh`.

## Prerequisites

- Xcode 26+ with iOS 26.5 simulator runtime installed
- `xcodegen` in PATH (`brew install xcodegen`)
- iPhone 17 Pro simulator: `EF810E05-C12F-468D-9F55-4131492332E8` (verified present)

## Build

The xcodeproj is generated from `project.yml` by xcodegen and **goes stale whenever source files are added or renamed**. Always regenerate before building:

```bash
cd /Users/MAC/Documents/GitHub/ThreadMapper
xcodegen generate
xcrun xcodebuild \
  -project ThreadMapper.xcodeproj \
  -scheme ThreadMapper \
  -destination "id=EF810E05-C12F-468D-9F55-4131492332E8" \
  -configuration Debug \
  -derivedDataPath build/DerivedDataSim \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Built app lands at: `build/DerivedDataSim/Build/Products/Debug-iphonesimulator/ThreadMapper.app`

## Run (agent path)

Run the smoke script — it regenerates, builds, boots, installs, launches, and screenshots:

```bash
bash /Users/MAC/Documents/GitHub/ThreadMapper/.claude/skills/run-threadmapper/smoke.sh
```

Screenshots land in `/tmp/threadmapper-screenshots/`. Pass a custom UDID or output dir as arguments:

```bash
bash .claude/skills/run-threadmapper/smoke.sh <sim-udid> /tmp/my-screenshots
```

To take an additional screenshot after manual interaction:

```bash
xcrun simctl io EF810E05-C12F-468D-9F55-4131492332E8 screenshot /tmp/screen.png
```

## Run (human path)

Open in Xcode, select an iPhone simulator, hit Run (⌘R). The simulator window opens with the Dashboard tab active.

## Install on device

Per project convention, install to UDID `772F66FC` after every feature delivery:

```bash
xcrun xcodebuild \
  -workspace .swiftpm/xcode/package.xcworkspace \
  -scheme ThreadMapper \
  -destination 'id=772F66FC' \
  -configuration Debug \
  build 2>&1 | tail -5
```

## Test

```bash
xcrun xcodebuild \
  -project ThreadMapper.xcodeproj \
  -scheme ThreadMapper \
  -destination "id=EF810E05-C12F-468D-9F55-4131492332E8" \
  -derivedDataPath build/DerivedDataSim \
  test 2>&1 | grep -E "error:|Test Suite|passed|failed" | tail -20
```

## Gotchas

- **Do NOT build with `.swiftpm/xcode/package.xcworkspace` for simulator app installs** — that workspace only has the library product target, not the app target. You get a `.o` file, not a `.app` bundle. Use `ThreadMapper.xcodeproj` instead.
- **xcodeproj goes stale silently** — any rename or new source file causes `error: Build input file cannot be found`. Fix: `xcodegen generate` before building.
- **Bundle ID confusion** — the xcodeproj produces `com.tintronixlab.ThreadMapper`; the .swiftpm workspace produces `threadmapper.ThreadMapper` (wrong, no-op for installation). Always use the xcodeproj path.
- **App needs HomeKit home for real data** — on simulator without a HomeKit home it shows demo/mock data. The Dashboard still renders correctly with mock entries.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Build input file cannot be found: …Extrapolator.swift` | `xcodegen generate` — xcodeproj is stale |
| `xcrun simctl install` succeeds but `launch` shows wrong app | Wrong bundle ID; confirm it's `com.tintronixlab.ThreadMapper` |
| Screenshot is blank / simulator shows home screen | Add `sleep 4` after launch before screenshot |
| `simctl boot` fails with "Unable to boot device in current state: Booted" | Benign — already booted, script continues |
