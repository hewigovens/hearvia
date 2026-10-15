# iOS feasibility PoC: measurement protocol

How the original ScreenCaptureKit + PiP feasibility study was run. Findings are in [poc-feasibility.md](poc-feasibility.md). These diagnostics now live in the iOS app under **Settings → Developer tools** (`Apps/iOS/Developer`). PoC scripts are in `scripts/poc/`; raw device logs and recordings are kept locally in `Archive/poc-evidence/` (not in git), so paths below that start with `Evidence/` refer to that folder.

## Components

- `CaptureController`: system picker consent, full-display filter, stream start/stop and errors. `.screen` output is discarded; `.audio` and `.microphone` are delivered to the analysis queue separately.
- `PCMDecoder` / `AudioMetrics`: owned PCM copy, normalized noninterleaved Float32, amplitudes and phase-independent 1 kHz projection.
- `AudioProbe`: per-source counts, PCM durations, silence, timestamp regressions, callback gaps, background measurements and 15-second CAF recording.
- `SubtitleRenderer` / `PiPController`: new 640×360 rasterized subtitle frames, iOS 27 sample-buffer receiver, host-clock render synchronizer, live playback delegate and PiP lifecycle callbacks.
- `AudioSessionController`: explicit session modes, mix/exclusive comparison, route and interruption logs, controlled 1 kHz playback.
- `DiagnosticLog`: timestamped JSONL and unified logging, stored in Documents/Evidence. Capture samples are stored only after pressing Record.

## Permissions and background execution

`UIBackgroundModes` includes **screen-capture** (Apple's iOS 27 full-display sample) and **audio** (PiP and optional microphone). `NSMicrophoneUsageDescription` describes the optional separate microphone experiment. Screen capture is authorized through `SCContentSharingPicker`; there is no invented screen-capture usage-description key and no custom capture entitlement. Camera, Photos, ReplayKit extensions and private APIs are not used.

System-only capture leaves `AVAudioSession` inactive. PiP and the tone activate **Playback + mix** by default. Enabling microphone in the system picker switches to **Play & record + mix**, using Apple's sample category/mode/options. Record its effect on routes and external playback. **Playback exclusive** intentionally lets you test interruption behavior. Deactivate Session is an experimental control and can break PiP/microphone playback; its effects are logged. Changing exclusion requires stopping capture and creating a fresh stream because `SCStream.updateConfiguration` is unavailable on iOS.

## Evidence rules

Non-zero means `abs(sample) > 1e-7`; the background “audible seconds” counter uses RMS > 0.0001 (−80 dBFS). These are diagnostic thresholds, not recognition of the source. Export and listen to the actual PCM. Microphone must be OFF during other-app and tone-exclusion tests so speaker leakage cannot masquerade as system capture. Requested output is 48 kHz stereo; observed format always comes from each actual buffer. PCM duration is frames/sample rate, separate from wall time.

Background span advances only on a received PCM buffer. The last-buffer age and maximum callback gap expose suspension. A 60-second span with a large gap or silence is not a pass. JSONL has `scene`, `system_pcm`, `microphone_pcm`, `subtitle_frame`, `capture_started`, `stream_ended`, `pip_*`, session/route events and manual observations. Subtitle enqueue acceptance alone is not proof of a visible, updating PiP window: inspect frame numbers on device and take screenshots at both ends.

## On-device protocol

Before each run, log the source app, clip and planned sequence. Record device model, Settings → General → About iOS version/build, route, source volume, microphone state, exclusion flag and session mode. Play a distinctive spoken clip you can identify in the CAF. Save permission-sheet screenshots and record whether granting capture changes source playback.

### A: each external audio source separately

1. Turn microphone OFF; leave the session inactive and PiP stopped. Enable own-audio exclusion. Press **Start Capture** and approve the full-display system sheet. Note every prompt and countdown.
   On the tested OS the sharing card stays open after authorization; tap outside it to return to the app. **Stop Sharing** ends capture.
2. Switch to Safari and play a non-DRM HTML5 video with audio. Confirm the source is audible. Continue for **at least 65 seconds** with Hearvia backgrounded. Return and note system PCM span, PCM seconds, audible seconds, last-buffer age, RMS, peak, non-zero percentage, callback gaps and stream errors.
3. For the export run, get the source playing, return briefly, press **Record Next 15 Seconds**, immediately return to the source and play the same distinctive segment for 20 seconds. Return, **Share CAF**, then listen on a computer. The file is named `system-*.caf`. Microphone recordings are named separately.
4. Repeat from a fresh stream for **YouTube**, **Apple Podcasts / ordinary audio**, **Zoom / Teams with a consenting test participant**, and **protected/DRM playback you are entitled to play**. Do not create a real call or install other apps just to run an automated test. If unavailable, record NOT TESTED.
5. Repeat with microphone offered/enabled in the system sheet. Confirm `.microphone` counters change separately. Compare external source playback and audio routes before/after. Permission granted and valid silent buffers alone never establish capture success.

### B: dynamic subtitles in PiP

1. Keep the inline preview visible. Disable **Show system RMS in PiP** to show changing sentences. Verify the frame number advances approximately once per second.
2. Press **Start PiP**. If the readiness message appears, keep the preview visible and retry once the “possible” state becomes yes. Record any failure callback.
3. Switch to Safari, then YouTube. Take screenshots at t=0 and t=65; record visible text/frame changes and any source interruption. System PiP controls remain present; this PoC does not hide them.
4. Switch apps repeatedly, rotate portrait ↔ landscape, shrink/enlarge the system PiP window, stash/un-stash it, pause/resume with system controls, and use restore. Confirm the inline preview and controls are restored. Record reported render dimensions and readability at the smallest usable size. These are pixel dimensions, not a contractual minimum size in points; the OS chooses its PiP bounds.
5. Lock for 10 seconds and unlock. Log whether PiP is hidden, suspended, stopped or restored and whether frame updates resume. Do not equate no PiP on the lock screen with a platform-wide failure.

### C: combined test — both orders

1. Set **Show system RMS in PiP** ON, microphone OFF, **Playback + mix**, own-audio exclusion ON.
2. Run **capture → PiP → Safari**. In Safari play an audible non-DRM HTML5 video for at least 65 seconds. Observe changing PiP frame numbers and PCM age/RMS. Take beginning/end screenshots. Return and save JSONL + CAF from a separate export run. Capture and PiP must both work during the same background interval.
3. Stop capture and PiP. Run **PiP → capture → Safari**, granting a fresh full-display picker session. Repeat exactly the same clip, duration and route. Record whether opening the picker terminates/suspends PiP or changes the source session.
4. Passing requires recognizable external PCM, no unexplained interruption/gaps, and visible updating PiP for the full interval. Capture elapsed wall time alone cannot satisfy this.

### D: own-audio exclusion and compatibility

1. Use headphones, microphone OFF, fixed route/system volume, and an external source with no 1 kHz tone. Establish its baseline. Start capture with exclusion **OFF**, press **Play 1 kHz Tone** (peak 0.1, expected original PCM RMS 0.07071), export 15 seconds and verify source playback did not stop.
2. Stop tone and capture, set exclusion **ON**, start a fresh stream, then start the identical source/tone again and export. Keep all other settings equal. Compare 1 kHz amplitude, energy fraction and RMS. Strong suppression with unchanged external-source PCM supports exclusion; losing all audio does not.
3. Run tone OFF/ON/OFF comparisons to distinguish a coincidental source tone. Speaker/microphone leakage invalidates this test. The per-buffer projection is approximate for short buffers; use the whole CAF analysis for frequency evidence.
4. Repeat with session activation alone, Playback + mix, Play & record + mix, and Playback exclusive. Switch speaker → wired/USB headphones → Bluetooth, if available. Log route/interruption notifications and whether source audio pauses, ducks, changes quality or disappears from PCM. Do not attribute every route change to an OS bug.

## Retrieve and inspect measurements

Use **Share JSONL Evidence** / **Share CAF**, or Files → On My iPhone → Hearvia PoC. Xcode Devices & Simulators can also download the app container. From this Mac:

```sh
xcrun devicectl device copy from --device YOUR_UDID \
  --domain-type appDataContainer --domain-identifier dev.hewig.hearvia \
  --source Documents --destination Evidence/device-documents
python3 scripts/poc/summarize_log.py Evidence/device-documents/Evidence/session-*.jsonl
sh scripts/analyze_pcm.sh unexcluded.caf excluded.caf
afplay system-recording.caf
```

The analyzer compiles the actual `AudioAnalysis.swift` with Apple's local frameworks and no dependencies. It prints sample rate, channels, duration, RMS, peak, non-zero percentage, 1 kHz amplitude and energy fraction; with two files it reports second/first attenuation in dB. Reduced 1 kHz energy must be interpreted against the external source baseline and listening evidence.

`FEASIBILITY.md` records what was actually verified in this session and the remaining decision gates. Subtitle-only PiP App Review suitability is a separate uncertainty from successful rendering.

## Optional deterministic Safari fixture

The host-only fixture generates a two-second H.264/AAC video whose audible tones alternate 440/880 Hz. Safari loops this source video; **PiP continues to render new subtitle frames independently**. It is useful for identifying the captured source and isolating a separate 1 kHz app tone. It cannot replace testing speech, service-specific playback or DRM.

```sh
xcrun swiftc -parse-as-library scripts/poc/make_test_video.swift -o /tmp/hearvia-make-video
/tmp/hearvia-make-video TestMedia/test.mp4
python3 -m http.server 8765 --directory TestMedia
```

Open `http://YOUR_MAC_LAN_IP:8765/index.html` in iPhone Safari and tap **Play test video**. The app itself makes no network calls. Keep the fixture server running for C/D; allow only your trusted local test network.

The C/D UI tests are opt-in and skip by default. After building for testing, add `HEARVIA_RUN_SAFARI=1` to the **UI test runner's** `EnvironmentVariables` dictionary in a copy of its `.xctestrun` file, keep that copy alongside the original build products, and run the selected C/D methods using `xcodebuild -xctestrun ... test-without-building`. The runner presses the user-visible full-display consent action as part of these explicitly enabled tests. Prepare Safari first; the methods never navigate or download source content automatically.
