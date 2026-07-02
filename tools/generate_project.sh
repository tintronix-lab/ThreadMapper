#!/bin/bash
set -euo pipefail
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
else
  echo "xcodegen not installed."
  echo "Install: brew install xcodegen || https://github.com/yonaskolb/XcodeGen"
  echo "Or open in Xcode directly: open /Users/MAC/Projects/ThreadMapper/Package.swift"
  exit 1
fi
