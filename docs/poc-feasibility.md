# iOS 27 system audio + PiP feasibility

> Archived PoC report. `Evidence/…` paths refer to `Archive/poc-evidence/`, kept locally and not in git. The project is now `Hearvia.xcodeproj` (generated), scheme **Hearvia**.

Assessment date: **2026-10-13**. Recommendation: **CONDITIONAL GO for a subtitles-only application**. Public APIs captured actual Safari PCM while readable, dynamically rendered PiP remained active for 65 seconds in both start orders. **Own-audio exclusion failed** on the tested device. Service coverage, microphone/routes, lock behavior and subtitle-only PiP review suitability remain decision gates.

## Verified environment

| Item | Observed value |
|---|---|
| Xcode | 27.0, build 27A266a; `/Applications/Xcode-27.0.0.app/Contents/Developer` |
| SDK / target | iPhoneOS 27.0 / iOS 27.0+ |
| Swift | Apple Swift 6.4; project uses Swift 6 language mode and complete concurrency checking |
| Device | Physical iPhone 16 Pro, iPhone17,1 |
| iOS | 27.0.1, build 24A446 |
| Access | Paired, Developer Mode enabled, wireless; initial lock/transport problems were resolved |
| Build / install | Actual app and test targets compiled and signed; installed and launched on the phone |
| Audio route | Built-in speaker; measured system output 48,000 Hz, 2 channels, typically 960 frames / 20 ms |
| Microphone | OFF in the measured A/C/D streams; confirmed by returned filter and logs |
| Permissions | System Screen Sharing sheet, explicit Share Entire Screen action, recording warning and red indicator. The authorized sharing card remains open until dismissed by tapping outside. Microphone permission was not exercised. |

Build evidence: `Evidence/build-for-testing-final-ui.log`, `Evidence/build-unsigned.log`, `Evidence/install-device.log`, and device environment JSON. Four mathematical/PCM-conversion unit tests passed on both this Mac and the physical phone. Device UI tests and collected samples are separate evidence from compilation.

## Results

| Test | Result | Evidence / limitation |
|---|---|---|
| Capture other-app PCM | PASS | Safari HTML5 H.264/AAC fixture: exported PCM contains the known alternating 440/880 Hz signal, not silence. Apple Podcasts also produced non-silent speech/program audio in a short capture; further results below. YouTube was not installed. |
| Capture continues in background | PASS | Safari capture alone, without PiP or audio-session activation: 69.26 s observed background span and 69.28 s PCM. Both combined runs also exceeded 60 s. This does not establish call/DRM behavior. |
| Zoom/Teams audio capture | NOT TESTED | Neither app was found on the phone; no call or consenting test participant was available. |
| Dynamic PiP subtitles | PASS | New text frames approximately once per second, visible over Home and Safari. C screenshots show frame #39 → #104 over 65 s. Portrait/landscape changes and start/stop/restore callbacks were exercised. Lock/unlock and deliberate minimum-size pinching remain untested. |
| PiP over another app | PASS | Safari screenshots at the beginning/end of both C runs show readable overlay text. YouTube overlay behavior remains untested because the app was absent. |
| Combined capture + PiP | PASS | Both capture → PiP → Safari and PiP → capture → Safari passed 65 s of foreground Safari playback with simultaneous system PCM and changing PiP. No sequence-dependent failure remained after correcting test setup. |
| Own-audio exclusion | FAIL | Genuine exclusion-OFF and exclusion-ON sessions both contain the app's 1 kHz tone. Recorded amplitude 0.070721 vs 0.070711; only −0.0013 dB difference, effectively no suppression. Microphone was OFF. |
| Audio route / session compatibility | NOT TESTED | Speaker + Playback/mix coexistence worked in C/D. Activating a session during already-running Podcasts playback was attempted but not completed. Microphone activation, exclusive category and wired/Bluetooth route changes still require validation. |
| Protected/DRM playback | NOT TESTED | No entitled protected source was supplied or exercised. No restriction is inferred from this missing test. |

## Measured audio and concurrent operation

The deterministic Safari fixture is a **source video in Safari**, not the PiP implementation. It alternates audible 440/880 Hz tones each second. The subtitle layer independently rasterizes new frames. The source AAC has RMS 0.070671, peak 0.103232 and 48 kHz stereo; `Evidence/safari-fixture-analysis.log` records its spectrum.

| Run | Background window | Received background PCM | Non-zero signal span | PiP frames in background | Maximum PiP frame gap |
|---|---:|---:|---:|---:|---:|
| C1 capture → PiP → Safari | 69.26 s | 69.22 s | 66.56 s between observed non-zero records | 69 | 1.005 s |
| C2 PiP → capture → Safari | 69.30 s | 69.30 s | 68.61 s between observed non-zero records | 70 | 1.004 s |

C1/C2 maximum audio callback gaps were 0.174/0.170 s, with zero decode errors and zero timestamp regressions. Callback batching and the two-second source loop's restart gaps must be distinguished from suspended capture. Roughly 58.2/58.3 s of the background PCM exceeded the diagnostic audible threshold; silence/restart portions of the source remain legitimate PCM. The non-zero signal persists beyond 60 s, while the stream continues delivering buffers and PiP updates.

The 15-second C1 export has RMS **0.062275**, peak **0.103232**, **77.65%** non-zero samples and clear 440/880 Hz windows with amplitude approximately 0.1. Its very small 1 kHz component is baseline leakage, not the app tone. C2 and capture-only A exports also contain the fixture signal. These actual PCM files and spectral evidence establish more than correctly formatted callbacks.

Relevant sessions: `session-D26861EA-4BFE-4571-95E4-115C1637B623.jsonl` (C1), `session-90D89CB2-3031-4835-8E47-D7BD118C2070.jsonl` (C2), and `session-35D60E81-2E1C-4C93-8358-1C70103D92CB.jsonl` (A), in the retrieved device-document folders. Exports:

- C1: `system-037FD7D9-01E1-493F-9FF7-F3C2181A988D.caf`.
- C2: `system-270A7039-229E-45E9-A3F8-094091A513BB.caf`.
- A: `system-543B4826-2CC1-42DA-8081-ADBB24B31CAA.caf`.

A compact canonical set is in `Evidence/measurements` (JSONL and CAF). Analysis is saved in `Evidence/c1-pcm-analysis.log`, `Evidence/c2-pcm-analysis.log`, and `Evidence/a-safari-pcm-analysis.log`. Beginning/end images are in `Evidence/screenshots-experiments`, mapped by its manifest. C1's visible counter changes #39 → #104 and elapsed capture 34 → 99 s; C2 changes #39 → #104 and 28 → 93 s. The overlay remains readable, with live PCM age around 0.0–0.1 s.

## Ordinary audio source: Apple Podcasts

A short Podcasts run produced actual program audio with maximum per-buffer RMS **0.279192**. Its stream had 48 kHz stereo PCM, zero decode errors, and 16.57 seconds of background callbacks, of which 14.38 seconds exceeded the signal threshold. The 15-second export is `system-725550A3-501E-4164-BB27-04C949186D22.caf` in `Evidence/device-documents-latest`; analysis is in `Evidence/podcasts-short-pcm-analysis.log`. The whole-file RMS was 0.102105, peak 0.881784, and non-zero percentage 76.62%. No speech recognition was used.

The playback confirmation predicate in the UI test did not match the Podcasts control, so the test stopped before its planned 65-second/activation phases despite receiving audio. The later rerun was blocked by the phone locking again, then the test runner lost its connection before bootstrap; it did not execute the test. **Podcasts 60-second survival and activation-interruption behavior are not established.** This is a test/access limitation, not evidence of a capture API failure. YouTube, Zoom and Teams were not installed; DRM and alternative routes were not exercised.

## Own-audio exclusion: measured failure

The app generates a 1 kHz mono CAF with source peak 0.1, then plays it using AVAudioPlayer. Both recordings preserve that tone along with Safari's separate 440/880 Hz source. This rules out success caused by silencing the entire mix.

| Passed exclusion flag | Recording | Whole-file RMS | 1 kHz amplitude | 1 kHz energy fraction |
|---|---|---:|---:|---:|
| false | `system-E6A30403-25D7-4E09-B0E1-8BCF82D19BD7.caf` | 0.080006 | 0.070721 | 39.07% |
| true | `system-E1525ADC-E7E2-4C26-87ED-10ACDCCD85BF.caf` | 0.080595 | 0.070711 | 38.49% |

`Evidence/own-exclusion-corrected-analysis.log` contains the paired comparison. OFF is explicitly logged in `session-BF8BF6D4-53D2-4C63-9099-FEB17DA69C7B.jsonl`; ON is logged in `session-C83A1F02-726A-42BB-AF12-872214D2B8AF.jsonl`. These used fresh streams, the same speaker route and generator, microphone OFF, and Playback + mix. Configuration values are logged from the values passed to SCStream; the public iOS stream interface does not offer configuration readback.

An earlier test labeled OFF had actually left the switch ON; that comparison is marked invalid and was discarded. The corrected OFF run checks the switch state. A later cleanup problem in that UI test occurred after the complete CAF was saved; the scrolling/control placement was repaired and the final D1 UI test passed. A green UI test indicates successful test actions, **not** successful audio exclusion.

Classification: **suspected OS/API implementation issue**, not a confirmed documented API restriction. Apple's [property documentation](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/excludescurrentprocessaudio) and SDK expose this setting for iOS 27 and describe exclusion of app audio. This run contradicts the intended effect. Root cause and behavior with another playback backend/device/OS build are not established. Do not rely on the flag to prevent feedback or add audible translated output based on this result.

## PiP timing, lifecycle and limits

The renderer uses the iOS 27 sample-buffer receiver attached to AVSampleBufferRenderSynchronizer, host-clock timing, monotonically increasing presentation timestamps and live infinite duration. There is no prerecorded subtitle video or silent looping audio. It handles playback pause/resume, enqueue failures/flush, session interruption notifications, readiness and restoration.

The initial first-tap startup race was reproduced: readiness changed shortly after audio-session activation. The implementation now retains that user request and waits briefly for readiness. Repeated physical-device startup tests passed afterward. Recorded render dimensions include **380×213** and **337×190** pixels. These are observed controller render sizes, including animation transitions; they do not prove the minimum practical resizable window size.

Portrait/landscape screenshots and logs in `Evidence/screenshots-validation` / `Evidence/test-device-validation.log` show PiP surviving orientation changes, then a restore request, completed restoration and stop. The repeated locked-device deployment errors are **not** tests of PiP surviving lock/unlock. Lock/unlock, deliberate pinching/stashing and readability at minimum size require the manual protocol.

## API restrictions and remaining hypotheses

| Finding / limitation | Classification | Consequence |
|---|---|---|
| System picker consent and returned full-display filter | Confirmed API requirement | Uses present(); checks display style. No macOS content enumeration/filter initializer is used. |
| allowedPickerModes, captureMicrophone | Confirmed API restriction on iOS | Use full-display picker entry point and microphone control/filter choice; attach separate microphone output. |
| updateConfiguration, minimumFrameInterval, queueDepth | Confirmed API restriction on iOS | Exclusion changes require fresh streams. No macOS throttling properties are set. |
| screen-capture and audio background modes | Confirmed configuration requirement | Matches Apple's iOS sample and PiP playback guidance; no unsupported entitlement or ReplayKit extension. |
| Initial locked phone / wireless timeout | Configuration/access problem | Resolved for runtime tests; retained deployment logs show their cause. |
| Sharing card stayed open / PiP covered controls / test switch tap did not toggle | Configuration/test-harness problems | Dismiss sharing UI, keep experiment controls together, verify actual switch state. These were corrected before interpreting measurements. |
| Own tone persists with exclusion enabled | Suspected OS/API issue | Measured FAIL on 27.0.1; supported property with ineffective behavior. |
| YouTube/calls/DRM, microphone, new routes, lock and minimum PiP size | Untested hypotheses | Need independent source/device tests. No universal capture or lock-survival claim. |

API/source checks used the installed SDK headers and Apple's current [iOS ScreenCaptureKit sample](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios), [ScreenCaptureKit documentation](https://developer.apple.com/documentation/screencapturekit), and [PiP controller documentation](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller). Lookup metadata and sample-download link are retained in Evidence. Camera/Photos permissions are omitted because those features are not used; microphone has its usage description and is separately authorized through the picker.

## Policy assessment, separate from runtime feasibility

Apple describes PiP as video playback and supports sample-buffer content. Its [custom-player guidance](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player) requires user initiation; this app starts from the PiP button and retains system controls. The documentation does not explicitly endorse a subtitle-only floating utility for other apps.

[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 2.5.1 requires intended API use, 2.5.4 limits background services to intended purposes, and 2.5.14 requires consent and a recording indication. A production app needs a defensible media/accessibility use case and review clarification. This is **policy uncertainty**, not a confirmed prohibition or approval guarantee.

## Reproduction and decision

Open the real `HearviaPoC.xcodeproj`, choose HearviaPoC and your signing team, then run on an unlocked iOS 27+ iPhone. Follow [README.md](README.md)'s A–D steps. For repeatable Safari input, generate/serve TestMedia/index.html using the documented host commands. Approve Share Entire Screen, dismiss the sharing card, start PiP through its button, switch to Safari, play the source and wait at least 65 seconds. Repeat in reverse order. Export CAF and JSONL; run the supplied spectrum/log analysis scripts and listen to the actual CAF. For D, stop capture before changing the flag, confirm its state and use a fresh stream.

**CONDITIONAL GO:** the central Safari system-audio + live-subtitle PiP design works through public APIs on the tested phone. Continue a subtitles-only translation prototype, with the app's audible output disabled during capture. Complete YouTube, call/DRM, microphone/route, lock/minimum-size and policy validation before claiming broad support or shipping. If audible dubbing or guaranteed own-audio isolation becomes a requirement, this measured exclusion failure is a blocker until a supported solution is verified.
