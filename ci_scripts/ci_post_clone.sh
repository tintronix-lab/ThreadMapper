#!/bin/zsh

# Fail script on first error and log all execution lines
set -euo pipefail
set -x

echo "==> Configuring build environment paths..."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

echo "==> Checking for XcodeGen..."
if ! command -v xcodegen &> /dev/null; then
    echo "==> Installing XcodeGen via Homebrew..."
    brew install xcodegen
else
    echo "==> XcodeGen already available."
fi

echo "==> Generating Xcode Project..."
xcodegen generate

echo "==> Post-clone hook finished successfully."
