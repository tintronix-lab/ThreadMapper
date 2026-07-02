#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLCHAIN="${TOOLCHAIN:-swift}"
echo "==> lint ($TOOLCHAIN)"
if [ "$TOOLCHAIN" = "swiftlint" ] && command -v swiftlint >/dev/null 2>&1; then
  (cd "$ROOT" && swiftlint lint --reporter xcode || true)
else
  echo "swiftlint not available; skipping"
fi
echo "==> build"
(cd "$ROOT" && swift build)
echo "==> test"
(cd "$ROOT" && swift test)
