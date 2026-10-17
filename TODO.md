# TODO

Open work, grouped by what it needs. Finished work lives in `jj log`. State as of 2026-10-17.

## Handoff

- Version control: jj only, in the default workspace (no sibling workspaces); `git` only for gaps jj doesn't cover, never index-writing commands. See `agents/version-control.md`. Codex sometimes works in the same checkout: check `jj op log` and `jj diff --stat` for edits you didn't make before describing or pushing.
- `main` on `origin` (github.com/hewigovens/hearvia) is at llmkkzrp (2026-10-17). `jj log -r 'main::@'` shows what isn't pushed yet; publish with `jj bookmark set main -r <rev>` and `jj git push --bookmark main`.
- Checks: `just format lint build test` locally; CI (`.github/workflows/ci.yml`, GitHub's `xcode-27` image) runs the kit tests, SwiftFormat, SwiftLint and unsigned builds of both apps on every push and pull request.
- Releases: `just testflight` / `just testflight-macos` upload to the internal TestFlight group (`docs/release.md`). The builds there predate the 2026-10-17 changes.

## Next: TestFlight

- [ ] Upload new builds (`just testflight`, `just testflight-macos`) and install both from TestFlight.
- [ ] Run the checks below on those Release builds: no Developer tools, no Files sharing and no diagnostics log on iPhone; quick start, transcripts and TranslateGemma work.
- [ ] Add a couple more internal testers; then an external group through Beta App Review (privacy URL, test information, feedback email and App Privacy are all set).

## Check on iPhone

- [ ] Microphone + OpenAI Realtime on the current build (the mic path uses `installAudioTap` now).
- [ ] Microphone with the on-device translator, with another app playing (no ducking or interruption).
- [ ] The floating window auto-starts when leaving the app ("Float when I leave Hearvia"), and Back to app doesn't stop listening.
- [ ] Home: the play button breathes while idle and ripples on press, moves to the bottom when listening; the three tile sheets size to their content; the transcript sheet from the header.
- [ ] Onboarding "Get ready": microphone Allow / denied → Settings, model downloads; light theme.
- [ ] Language pickers: on-device lists the system's languages, OpenAI Realtime the fixed 13, Gemini Live 76; switching to an engine without the subtitle language falls back to English (unit-tested).
- [ ] Silence pause/resume, and "show original" off (Realtime restarts when the toggle changes while listening).
- [ ] Quick start: the widget (small and medium), the Control Center control, "Start Hearvia" in Shortcuts and both Home Screen quick actions each open the app and start listening (other apps still show the iOS sharing sheet). Cold launch, and onboarding first on a fresh install.
- [ ] Transcripts: a session appears after Stop (and after leaving the app mid-session); export a .txt to Files; swipe to delete; "Save transcripts" off keeps nothing.
- [ ] TranslateGemma with Hearvia on screen: microphone mode with no network, a few minutes of speech; and the 2.2 GB download in Settings → Translators (the test phone has the model copied in already).
- [ ] Gemini Live in the app: rotation every ~7–9 minutes, silence pause and resume, a language change mid-session.
- [ ] Delete the old "Hearvia PoC" install if it's still there (different bundle ID; settings and Keychain start fresh).
- Skipped for now: background TranslateGemma with live capture, speech recognition and PiP together; the test iPhone has no background GPU support.

## Check on Mac

- [ ] Microphone source end to end, sandboxed; launch from Finder/`open` (from a terminal, macOS asks for the terminal's microphone access).
- [ ] Save an API key in Settings → Translators in the sandboxed build.
- [ ] Clicking the Dock icon reopens the control window; the Dock menu's Start/Stop and Show overlay.
- [ ] A real session close to 60 minutes rotates (log event `translation_rotated`).

## Engineering

- [ ] iOS UI tests for the redesigned UI. This Mac has no iOS 27 simulator runtime (several GB to download); GitHub's `xcode-27` image has one.
- [ ] Tune the cloud silence threshold (about −40 dBFS peak, `CloudTiming.silencePeak`): videos with background music may never pause.
- [ ] Transcript lines are cut at sentence punctuation in the translation, so original/translation pairing is approximate.
- [ ] Gemini Live en → ja drops the last clause of a clip ("…smaller than expected"), and en → nl / pt cut the end too; recheck when the model leaves preview.
- [ ] Gemini Live: offer Traditional Chinese (`zh-Hant`) once the pickers can name scripts.
- [ ] TranslateGemma quality: 2 of 8 English test sentences came out wrong in Chinese ("fell asleep 20 minutes faster" → "slept 20 minutes"; "Activation went up" garbled). Compare with the built-in translator on real speech before calling it "better".
- [ ] `TranslationSession` is still not Sendable in the 27 SDK, so `OnDeviceTextTranslator` and `OnDeviceModelsView` keep `nonisolated(unsafe)`; revisit with a later SDK.
- [ ] Mac menu-bar-only launch closes the control window by polling for it (`MenuBarLabel.closeLaunchWindow`) because `.defaultLaunchBehavior` was unreliable; replace if SwiftUI gets a dependable way.
- [ ] svourztr is one large change (kit modules + four parallel work streams); split it in JayJay if separate commits are wanted.

## Release

- [ ] Notarize a Developer ID build for distribution outside the App Store (needs a Developer ID Application certificate and a notarytool profile); see `docs/release.md`.
- [ ] Liquid Glass icon via Icon Composer (`.icon`) instead of the PNG asset sets.

## Ideas and decisions

- Keys: free + bring-your-own-key for TestFlight and the App Store for now (decided 2026-10-15 and 2026-10-17). A paid tier could come later: a token server (App Attest + StoreKit check, short-lived provider tokens, the app still connects straight to OpenAI/Google) with minutes sold through In-App Purchase; on-device stays free.
- Hybrid "ChatGPT plan" mode: on-device speech + Responses API text translation (`gpt-6-luna`, effort none; ~3–5 s behind sentence end). Plan tokens can't do realtime audio; commercial use needs OpenAI's approval. Probe: `scripts/chatgpt_plan_probe.py`.
- TranslateGemma on iPhone is for in-app use (decided 2026-10-16): offline microphone translation with Hearvia on screen; background translation only where iOS grants background GPU time.
- iOS limitations: the screen-sharing picker appears every session; own-audio exclusion is broken on iOS 27.0.1.
