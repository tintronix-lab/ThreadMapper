#!/bin/bash
# Local mirror of .github/workflows/ci.yml.
#
# ThreadMapper depends on HomeKit and UIKit, so `swift build` / `swift test`
# against the macOS host cannot work — the build and test steps go through
# xcodebuild against an iOS simulator instead (see the Makefile).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> lint"
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint lint --reporter xcode || true
else
  echo "swiftlint not available; skipping"
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required (brew install xcodegen)" >&2
  exit 1
fi

echo "==> build + test (iOS Simulator)"
make test
