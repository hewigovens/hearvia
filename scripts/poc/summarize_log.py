#!/usr/bin/env python3
"""Summarize measured signals. Never classify callback activity as source-audio PASS."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("logs", nargs="+", type=Path)
args = parser.parse_args()
for path in args.logs:
    records = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    print(path.name)
    for source in ("system_pcm", "microphone_pcm"):
        rows = [r for r in records if r.get("event") == source]
        if not rows:
            print(f"  {source}: no measured PCM records")
            continue
        def nums(key):
            return [float(r[key]) for r in rows if key in r and r[key] != "none"]
        summary = {"records": len(rows), "formats": sorted({(r["sample_rate"], r["channels"]) for r in rows}),
                   "last": rows[-1], "rms_range": [min(nums("rms")), max(nums("rms"))],
                   "nonzero_percent_range": [min(nums("nonzero_pct")), max(nums("nonzero_pct"))]}
        print(json.dumps({source: summary}, indent=2))
    frames = [r for r in records if r.get("event") == "subtitle_frame" and r.get("active") == "true"]
    if frames:
        print(json.dumps({"pip_active_frames": len(frames), "first": frames[0], "last": frames[-1],
                          "active_frame_span": float(frames[-1]["uptime"]) - float(frames[0]["uptime"])}, indent=2))
    for r in records:
        if r.get("event") in ("manual_observation", "capture_error", "pcm_error", "stream_ended", "pip_error", "audio_session_notification"):
            print(json.dumps(r, sort_keys=True))
    print("  Listen to the CAF and verify the named source; these numbers alone do not prove other-app capture.")
