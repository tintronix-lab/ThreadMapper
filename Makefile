# Package
APP_NAME=ThreadMapper
SCHEME=$(APP_NAME)

# XcodeGen
XCODEGEN?=xcodegen
XCODEPROJ=$(APP_NAME).xcodeproj

# Tools
SWIFT=swift
SWIFTLINT=swiftlint
XCODEBUILD=xcrun xcodebuild

# Flags
CLOBBER=.build DerivedData build/DerivedDataSim
DERIVED=$(CURDIR)/build/DerivedDataSim

# ThreadMapper depends on HomeKit and UIKit, so it only builds for iOS —
# `swift build` / `swift test` against the macOS host cannot work. Everything
# below drives an iOS simulator through xcodebuild, matching .github/workflows/ci.yml.
# Picks the first available iPhone simulator rather than pinning a name, since
# device names drift between Xcode releases.
SIM_UDID=$(shell xcrun simctl list devices available --json | python3 -c "import json,sys; rt=json.load(sys.stdin)['devices']; print(next(d['udid'] for k,ds in rt.items() if 'iOS' in k for d in ds if d.get('isAvailable') and d['name'].startswith('iPhone')))")
DESTINATION=platform=iOS Simulator,id=$(SIM_UDID)

XCFLAGS=-project $(XCODEPROJ) \
	-scheme $(SCHEME) \
	-destination '$(DESTINATION)' \
	-derivedDataPath $(DERIVED) \
	-skipPackagePluginValidation \
	CODE_SIGNING_ALLOWED=NO

.PHONY: help resolve build test lint clean ci dev proj fmt

help:
	@echo "ThreadMapper make targets"
	@echo ""
	@echo "  make dev       - proj + build + test"
	@echo "  make proj      - regenerate $(XCODEPROJ) from project.yml"
	@echo "  make build     - xcodebuild (iOS Simulator)"
	@echo "  make test      - xcodebuild test (iOS Simulator)"
	@echo "  make lint      - swiftlint lint"
	@echo "  make fmt       - swiftformat ."
	@echo "  make resolve   - swift package resolve"
	@echo "  make clean     - remove build artifacts"
	@echo "  make ci        - lint + build + test"
	@echo ""

dev: proj build test

# The generated project goes stale whenever a source file is added or renamed,
# which surfaces as "Build input file cannot be found" — always regenerate first.
proj:
	$(XCODEGEN) generate

resolve:
	$(SWIFT) package resolve

build: proj
	$(XCODEBUILD) $(XCFLAGS) build

test: proj
	$(XCODEBUILD) $(XCFLAGS) test

lint:
	$(SWIFTLINT) lint --reporter xcode || true

fmt:
	swiftformat . || true

ci: lint build test

clean:
	rm -rf $(CLOBBER)
