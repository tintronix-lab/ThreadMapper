# Contributing to ThreadMapper

## Branches
- `main` — stable
- `feat/<name>` — new features
- `fix/<name>` — bug fixes
- `chore/<name>` — tooling, deps

## Commits
Use Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.

## Checklist
- `swift build` passes
- `swift test` passes
- No secrets committed
- UI strings localized if user-facing
- SwiftData migrations documented if schema changes

## Setup
```bash
git clone <repo-url>
cd ThreadMapper
swift package resolve
swift build
swift test
```

