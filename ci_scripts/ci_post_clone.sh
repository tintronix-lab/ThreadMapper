cat << 'EOF' > ci_scripts/ci_post_clone.sh
#!/bin/zsh

# Stop script on first failure
set -e

echo "==> Installing XcodeGen via Homebrew..."
brew install xcodegen

echo "==> Generating Xcode Project..."
xcodegen generate

echo "==> Post-clone setup complete."
EOF