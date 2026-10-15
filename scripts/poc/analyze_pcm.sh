#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
task_dir=$(mktemp -d "${TMPDIR:-/tmp}/hearvia-analysis.XXXXXX")
trap 'rm -rf "$task_dir"' EXIT
xcrun swiftc "$task_root/Apps/iOS/Developer/AudioAnalysis.swift" "$task_root/scripts/poc/analyze_pcm.swift" -o "$task_dir/analyze_pcm"
"$task_dir/analyze_pcm" "$@"
