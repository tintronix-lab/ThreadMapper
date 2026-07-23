# Development

## Prerequisites
- macOS 15+
- Xcode 26+ with an iOS simulator runtime installed
- Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Setup
```bash
git clone <repo-url>
cd ThreadMapper
make dev      # regenerate project + build + test
```

`ThreadMapper.xcodeproj` is generated from `project.yml` and goes stale whenever a
source file is added or renamed (`error: Build input file cannot be found`). Every
build target runs `make proj` first, or regenerate by hand with `xcodegen generate`.

> `swift build` and `swift test` do **not** work on this package: it imports HomeKit
> and UIKit, which exist only on iOS. `make build` and `make test` drive an iOS
> simulator through `xcodebuild`, matching `.github/workflows/ci.yml`.

## Run on a device
HomeKit returns no accessories in the simulator, so real data needs a physical
iPhone (paired, Developer Mode on, and registered to the signing team).

```bash
xcodegen generate
xcrun devicectl list devices                 # find the connected device's UDID
xcrun xcodebuild \
  -project ThreadMapper.xcodeproj \
  -scheme ThreadMapper \
  -destination 'id=<device-udid>' \
  -configuration Debug \
  -derivedDataPath build/DerivedDataDevice build
xcrun devicectl device install app \
  build/DerivedDataDevice/Build/Products/Debug-iphoneos/ThreadMapper.app
```

Or just open `ThreadMapper.xcodeproj` in Xcode, pick the device, and press Run.

## Lint
```bash
make lint
```

## CI
```bash
make ci
```

## Clean
```bash
make clean
```
