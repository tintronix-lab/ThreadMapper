# Package
APP_NAME=ThreadMapper
SCHEME=$(APP_NAME)

# XcodeGen
XCODEGEN?=
XCODEPROJ=$(APP_NAME).xcodeproj
WORKSPACE=$(APP_NAME).xcworkspace

# Tools
SWIFT=swift
SWIFTLINT=swiftlint
XCODEBUILD=xcodebuild

# Flags
CLOBBER=.build DerivedData
PLATFORMS=OS=16.4

.PHONY: help resolve build test lint clean ci ci-xcode dev \
       xcodegen proj \
       fmt clippy

help:
	@echo "ThreadMapper make targets"
	@echo ""
	@echo "  make dev       - resolve + build + test"
	@echo "  make resolve   - swift package resolve"
	@echo "  make build     - swift build"
	@echo "  make test      - swift test"
	@echo "  make lint      - swiftlint lint"
	@echo "  make fmt       - swiftformat ."
	@echo "  make clean     - remove build artifacts"
	@echo "  make ci        - lint + build + test (SPM)"
	@echo "  make ci-xcode  - lint + xcodebuild test"
	@echo "  make xcodegen  - generate Xcode project"
	@echo ""

dev: resolve build test

resolve:
	$(SWIFT) package resolve

build:
	$(SWIFT) build

test:
	$(SWIFT) test

lint:
	$(SWIFTLINT) lint --reporter xcode || true

fmt:
	swiftformat . || true

ci: lint build test

ci-xcode: lint
	$(XCODEBUILD) \
		-sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
		-scheme $(SCHEME) \
		-derivedDataPath $(CURDIR)/DerivedData \
		test

xcodegen:
ifneq ($(XCODEGEN),)
	$(XCODEGEN) generate
endif

clean:
	rm -rf $(CLOBBER)


