#!/bin/bash
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)/.."
swift package resolve
swift build
swift test
