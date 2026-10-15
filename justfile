set shell := ["bash", "-euo", "pipefail", "-c"]

device := env_var_or_default("HEARVIA_DEVICE", "00008140-001E58C6117B001C")

default:
  @just --list

# Generate Hearvia.xcodeproj from project.yml
generate:
  xcodegen generate

# Build both apps
build: generate
  xcodebuild -project Hearvia.xcodeproj -scheme Hearvia -destination 'generic/platform=iOS' -quiet build
  xcodebuild -project Hearvia.xcodeproj -scheme HearviaMac -destination 'platform=macOS' -quiet build

# Compile the iOS test targets (run them on a device)
build-tests: generate
  xcodebuild -project Hearvia.xcodeproj -scheme Hearvia -destination 'generic/platform=iOS' -quiet build-for-testing

# HearviaKit unit tests
test:
  cd HearviaKit && swift test

# Build, install and launch on the paired iPhone
install-ios: generate
  xcodebuild -project Hearvia.xcodeproj -scheme Hearvia -destination 'generic/platform=iOS' -quiet build
  xcrun devicectl device install app --device {{device}} "$(xcodebuild -project Hearvia.xcodeproj -scheme Hearvia -destination 'generic/platform=iOS' -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/Hearvia.app"
  xcrun devicectl device process launch --terminate-existing --device {{device}} dev.hewig.hearvia

# Build and launch the Mac app with JSON event logging
run-mac *args: generate
  xcodebuild -project Hearvia.xcodeproj -scheme HearviaMac -destination 'platform=macOS' -quiet build
  "$(xcodebuild -project Hearvia.xcodeproj -scheme HearviaMac -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/Hearvia.app/Contents/MacOS/Hearvia" --verbose {{args}}

# Stream an audio file through an engine: just translate TestMedia/speech/ja.aiff en --on-device=ja
translate *args:
  cd HearviaKit && swift build -q
  HearviaKit/.build/debug/hearvia-translate {{args}}

# Render the app icon asset catalogs
icons:
  swift scripts/make_icons.swift

format:
  swiftformat .

lint:
  swiftlint lint --quiet
