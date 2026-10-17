set shell := ["bash", "-euo", "pipefail", "-c"]

device := env_var_or_default("HEARVIA_DEVICE", "")

default:
  @just --list

# Generate Hearvia.xcodeproj from project.yml
generate:
  sh scripts/gen_dev_secrets.sh # The project lists its output, which a fresh clone doesn't have yet.
  if [ -f project.local.yml ]; then INCLUDE_LOCAL_PROJECT_YML=YES xcodegen generate; else INCLUDE_LOCAL_PROJECT_YML=NO xcodegen generate; fi

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
  @test -n "{{device}}" || { echo "Set HEARVIA_DEVICE to the iPhone's UDID (xcrun devicectl list devices)."; exit 1; }
  xcodebuild -project Hearvia.xcodeproj -scheme Hearvia -destination 'generic/platform=iOS' -quiet build
  xcrun devicectl device install app --device {{device}} "$(xcodebuild -project Hearvia.xcodeproj -scheme Hearvia -destination 'generic/platform=iOS' -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/Hearvia.app"
  xcrun devicectl device process launch --terminate-existing --device {{device}} dev.hewig.hearvia

# TestFlight (scripts/testflight.sh, settings in .env; see docs/release.md). Build numbers are timestamps.
# Check the App Store Connect API key
testflight-auth:
  scripts/testflight.sh auth

# Archive and export without uploading (output in build/testflight/)
testflight-build platform="ios":
  scripts/testflight.sh build-{{platform}}

# Archive, export and upload the iOS app
testflight:
  scripts/testflight.sh upload-ios

# Archive, export and upload the Mac app
testflight-macos:
  scripts/testflight.sh upload-macos

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
