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
