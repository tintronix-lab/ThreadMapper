# ThreadMapper

Thread mesh coverage mapper for iOS 17+.

## Build
```bash
cd /Users/MAC/Projects/ThreadMapper
swift package resolve
swift build
swift test
```

## Runs
- `DashboardView` shows discovered Thread/Matter devices
- `MeshGraphView` renders links with force-directed layout
- `SurveyWalkView` captures manual signal samples
- `DeviceDetailView` shows Thread metadata

## Notes
- Requires iOS 17.0+
- HomeKit authorization needed for device discovery
- Matter topology is limited by HomeKit API exposure

## Pushing to GitHub
```bash
git remote add origin git@github.com:<owner>/ThreadMapper.git
git push -u origin main
```
