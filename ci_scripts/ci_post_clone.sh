#!/bin/zsh

# Print commands as they run for clear CI log visibility
set -x
set -e

echo "==> Setting up environment..."

# Ensure Homebrew binary path is included for Apple Silicon / Intel runners
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Install XcodeGen if not already present
if ! command -v xcodegen &> /dev/null; then
    echo "==> XcodeGen not found. Installing via Homebrew..."
    brew install xcodegen
else
    echo "==> XcodeGen is already installed."
fi

echo "==> Generating Xcode Project..."
xcodegen generate

echo "==> Post-clone hook finished successfully."
