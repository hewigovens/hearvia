# TODO

Open work, grouped by what it needs. Finished work lives in `jj log`. State as of 2026-10-18.

## Handoff

- Version control: jj only, in the default workspace (no sibling workspaces); `git` only for gaps jj doesn't cover, never index-writing commands. See `agents/version-control.md`. Codex sometimes works in the same checkout: check `jj op log` and `jj diff --stat` for edits you didn't make before describing or pushing.
- `main` on `origin` (github.com/hewigovens/hearvia) is at mxvtsnvo (2026-10-18). `jj log -r 'main::@'` shows what isn't pushed yet; publish with `jj bookmark set main -r <rev>` and `jj git push --bookmark main`.
- Checks: `just format lint build test` locally; CI (`.github/workflows/ci.yml`, GitHub's `xcode-27` image) runs the kit tests, SwiftFormat, SwiftLint and unsigned builds of both apps on every push and pull request.
- Releases: `just testflight` / `just testflight-macos` upload to TestFlight (`docs/release.md`). Internal testers get every build; the external "Public Beta" group (public link, up to 1,000 testers) gets a build once it's added to the group, and the first build of each version needs Beta App Review. Latest: 0.1 (202610180940 iOS, 202610180941 Mac, built with Xcode 27.1), 2026-10-18.

## Next: TestFlight

- [ ] Beta App Review of 1.0 (3) iOS and (4) Mac (submitted 2026-10-18, both in the Public Beta group; the 0.1 builds were expired). Once approved, share the public link.
- [ ] App Store 1.0 is ready to submit (iOS and Mac, 2026-10-18): listing, keywords, screenshots (`scripts/frame_screenshots.py`), age rating 4+, free, every territory but mainland China (no ICP filing), review details, builds 1.0 (5) iOS and (6) Mac attached (with the Duo layouts and Apple TV subtitles), iPhone Duo screenshots included; release is manual. Submit with `asc review submit` or in App Store Connect when ready.
- [ ] Run the checks below on the TestFlight builds: no Developer tools, no Files sharing and no diagnostics log on iPhone; quick start and transcripts work.

## Check on iPhone

- [ ] Microphone with OpenAI Realtime and with the on-device translator, while another app plays: subtitles appear and the other app isn't ducked or paused.
- [ ] Quick start from a cold launch: the widget, the Control Center control and "Start Hearvia" in Shortcuts each open the app and start listening.
- [ ] Auto spoken language (on-device and Local LLM) with a real podcast: picks the language within a sentence or two; a language change mid-session is picked up after the next finished sentence.
- [ ] Leaving the app while listening starts the floating window ("Float when I leave Hearvia"), and Back to app doesn't stop listening.
- [ ] Transcripts: a session is saved after Stop and after leaving the app mid-session; with Sync with iCloud on, a Mac session appears on the iPhone and a delete on one device removes it on the other (iPhone → Mac works, 2026-10-18).

## Check on iPhone Duo (ships 2026-10-23)

- Xcode 27.1 (final, 2026-10-15) is at /Applications/Xcode-27.1.app with the iOS 27.1 and 27.0 simulators and a "Hearvia Duo" simulator; build with `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer` (also the selected Xcode now). Simulator screenshots come back black while the Mac is locked.
- [ ] Open and closed: home switches between one and two columns; transcripts show as a split view when open; onboarding stays readable; uneven safe areas don't clip anything.
- [ ] On a real Duo (both checked in the 27.1 Simulator, 2026-10-18): open in landscape while listening shows the book layout (subtitles and controls left, transcript right, nothing under the fold); half-folded in portrait shows tabletop (subtitles on the standing half, transcript and Stop on the flat half). PiP still starts when leaving the app from either.

## Check on Mac

- [ ] Microphone source end to end in the sandboxed build, launched from Finder (from a terminal, macOS asks for the terminal's microphone access).
- [ ] Save an API key in Settings → Translators in a Release build (Debug builds also read keys from `.env`).
- [ ] A long session rotates without losing text: OpenAI Realtime near 60 minutes, Gemini Live every few minutes (log event `translation_rotated`).
- [ ] On a macOS 26.4 Mac (none here; everything so far ran on 27): microphone source and the on-device translator end to end. Those two take the 26 fallbacks (`installTap` with a buffer copy in `MicrophoneCapture`, `AVAudioConverter` to `SpeechAnalyzer.bestAvailableAudioFormat` in `OnDeviceSpeech`); also check that the process tap, model downloads and Auto spoken language behave as on 27.

## Engineering

- [ ] Local LLM translator with Ollama / LM Studio. With a slow model, consider translating finished sentences only, since in-progress text is re-sent as it changes.
- [ ] iOS UI tests for the redesigned UI. This Mac has no iOS 27 simulator runtime (several GB to download); GitHub's `xcode-27` image has one.
- [ ] Tune the cloud silence threshold (about −40 dBFS peak, `CloudTiming.silencePeak`): videos with background music may never pause.
- [ ] Transcript lines are cut at sentence punctuation in the translation, so original/translation pairing is approximate.
- [ ] Gemini Live en → ja drops the last clause of a clip ("…smaller than expected"), and en → nl / pt cut the end too; recheck when the model leaves preview.
- [ ] Gemini Live: offer Traditional Chinese (`zh-Hant`) once the pickers can name scripts.
- [ ] Mac menu-bar-only launch closes the control window by polling for it (`MenuBarLabel.closeLaunchWindow`) because `.defaultLaunchBehavior` was unreliable; replace if SwiftUI gets a dependable way.

## Release

- [ ] Optional, only for downloads outside the Mac App Store: notarize a Developer ID build (needs a Developer ID Application certificate and a notarytool profile); see `docs/release.md`. The App Store build only needs the sandbox, which is in place.
- [ ] Liquid Glass icon via Icon Composer (`.icon`) instead of the PNG asset sets.

## Ideas and decisions

- Local LLM: Index-Translate-9B (Q8_0) in Unsloth Studio on a Mac Studio made no meaning errors in Chinese or Japanese on the 24-sentence set, at about 0.4 s per sentence, from both the Mac and the iPhone over the network (2026-10-17).
- TranslateGemma removed (decided 2026-10-17). On 24 English sentences the 4B model (MLX, 0.5 s per sentence on Mac, 1.4–1.9 s on iPhone) read more naturally than Apple's translator but changed facts in about 1 in 8; 12B (6.7 GB, 1.1 s) made no meaning errors but left English words untranslated and needs 7 GB. Apple's on-device translator was literal but accurate at 0.03 s. Code is in jj history (HearviaLLM, wqonquuz onward) if a later model is worth another look.
- Keys: free + bring-your-own-key for TestFlight and the App Store for now (decided 2026-10-15 and 2026-10-17). A paid tier could come later: a token server (App Attest + StoreKit check, short-lived provider tokens, the app still connects straight to OpenAI/Google) with minutes sold through In-App Purchase; on-device stays free.
- Hybrid "ChatGPT plan" mode: on-device speech + Responses API text translation (`gpt-6-luna`, effort none; ~3–5 s behind sentence end). Plan tokens can't do realtime audio; commercial use needs OpenAI's approval. Probe: `scripts/chatgpt_plan_probe.py`.
- Deployment targets: macOS 26.4 (TranslationSession(installedSource:target:preferredStrategy:) sets the floor), iOS 27 (decided 2026-10-18). iOS can't go lower: ScreenCaptureKit on iOS (other apps' audio) and the PiP renderer's `AVSampleBufferVideoRenderer.Receiver` are iOS 27 only, so iOS 26 would be microphone-only without PiP subtitles.
- iOS limitations: the screen-sharing picker appears every session; own-audio exclusion is broken on iOS 27.0.1.
