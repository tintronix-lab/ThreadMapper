#!/bin/zsh

# Log all execution lines; do NOT use set -e so we can handle errors ourselves
set -uo pipefail
set -x

echo "==> Configuring build environment paths..."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

echo "==> Checking for XcodeGen..."
if command -v xcodegen &>/dev/null; then
    echo "==> XcodeGen already available at $(command -v xcodegen)"
elif brew install xcodegen; then
    echo "==> XcodeGen installed via Homebrew."
else
    echo "==> Homebrew install failed, trying to download XcodeGen binary..."
    XCODEGEN_VERSION="2.42.0"
    curl -fsSL "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip" -o /tmp/xcodegen.zip
    unzip -q /tmp/xcodegen.zip -d /tmp/xcodegen
    sudo mv /tmp/xcodegen/xcodegen /usr/local/bin/xcodegen
    rm -rf /tmp/xcodegen.zip /tmp/xcodegen
    echo "==> XcodeGen installed from GitHub release."
fi

echo "==> Generating Xcode Project..."
xcodegen generate
echo "==> project.pbxproj generated successfully."

echo "==> Post-clone hook finished successfully."
