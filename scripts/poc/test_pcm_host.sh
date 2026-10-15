#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_dir=$(mktemp -d "${TMPDIR:-/tmp}/hearvia-pcm-tests.XXXXXX")
trap 'rm -rf "$task_dir"' EXIT
mkdir -p "$task_dir/Sources/HearviaPoC" "$task_dir/Tests/HearviaPoCTests"
cp "$task_root/Apps/iOS/Developer/AudioAnalysis.swift" "$task_dir/Sources/HearviaPoC/"
cp "$task_root/Apps/iOS/Tests/AudioAnalysisTests.swift" "$task_dir/Tests/HearviaPoCTests/"
cat > "$task_dir/Package.swift" <<'EOF'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HearviaPCMValidation", platforms: [.macOS(.v15)], targets: [
    .target(name: "HearviaPoC"),
    .testTarget(name: "HearviaPoCTests", dependencies: ["HearviaPoC"])
])
EOF
swift test --package-path "$task_dir"
