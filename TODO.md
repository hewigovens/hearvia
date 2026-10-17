# TODO

Open work, grouped by what it needs. Finished work lives in `jj log`. State as of 2026-10-17.

## Handoff

- Version control: jj only, in the default workspace (no sibling workspaces); `git` only for gaps jj doesn't cover, never index-writing commands. See `agents/version-control.md`. Codex sometimes works in the same checkout: check `jj op log` and `jj diff --stat` for edits you didn't make before describing or pushing.
- `main` on `origin` (github.com/hewigovens/hearvia) is at llmkkzrp (2026-10-17). `jj log -r 'main::@'` shows what isn't pushed yet; publish with `jj bookmark set main -r <rev>` and `jj git push --bookmark main`.
- Checks: `just format lint build test` locally; CI (`.github/workflows/ci.yml`, GitHub's `xcode-27` image) runs the kit tests, SwiftFormat, SwiftLint and unsigned builds of both apps on every push and pull request.
- Releases: `just testflight` / `just testflight-macos` upload to the internal TestFlight group (`docs/release.md`). The builds there predate the 2026-10-17 changes.

## Next: TestFlight

- [ ] Upload new builds (`just testflight`, `just testflight-macos`) and install both from TestFlight.
- [ ] Run the checks below on those Release builds: no Developer tools, no Files sharing and no diagnostics log on iPhone; quick start and transcripts work.
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
- [ ] Transcripts sync with iCloud (Settings → Transcripts → Sync with iCloud on both devices): an iPhone session appears on the Mac and the other way round; a delete on one removes it on the other; turning sync off keeps this device's copies.
- [ ] Transcripts: a session appears after Stop (and after leaving the app mid-session); export a .txt to Files; swipe to delete; "Save transcripts" off keeps nothing.
- [ ] Gemini Live in the app: rotation every ~7–9 minutes, silence pause and resume, a language change mid-session.
- [ ] Delete the old "Hearvia PoC" install if it's still there (different bundle ID; settings and Keychain start fresh).

## Check on Mac

- [ ] Microphone source end to end, sandboxed; launch from Finder/`open` (from a terminal, macOS asks for the terminal's microphone access).
- [ ] Save an API key in Settings → Translators in the sandboxed build.
- [ ] Clicking the Dock icon reopens the control window; the Dock menu's Start/Stop and Show overlay.
- [ ] A real session close to 60 minutes rotates (log event `translation_rotated`).

## Engineering

- [x] Local model translator with Index-Translate-9B (Q8_0) in Unsloth Studio on the Mac Studio, from this Mac over the network (2026-10-17): no meaning errors in Chinese or Japanese on the 24-sentence set, 0.36 s (zh) / 0.43 s (ja) median per sentence; live subtitles in the sandboxed Mac app. Only "where we landed" came out literal. The Mac asks for Local Network access on first use.
- [x] Local LLM translator from the iPhone over the network: a Japanese podcast (other apps) → Chinese with Index-Translate-9B on the Mac Studio works well (2026-10-17).
- [ ] Local LLM translator with Ollama / LM Studio. With a slow model, consider translating finished sentences only, since in-progress text is re-sent as it changes.

- [ ] iOS UI tests for the redesigned UI. This Mac has no iOS 27 simulator runtime (several GB to download); GitHub's `xcode-27` image has one.
- [ ] Tune the cloud silence threshold (about −40 dBFS peak, `CloudTiming.silencePeak`): videos with background music may never pause.
- [ ] Transcript lines are cut at sentence punctuation in the translation, so original/translation pairing is approximate.
- [ ] Gemini Live en → ja drops the last clause of a clip ("…smaller than expected"), and en → nl / pt cut the end too; recheck when the model leaves preview.
- [ ] Gemini Live: offer Traditional Chinese (`zh-Hant`) once the pickers can name scripts.
- [ ] Mac menu-bar-only launch closes the control window by polling for it (`MenuBarLabel.closeLaunchWindow`) because `.defaultLaunchBehavior` was unreliable; replace if SwiftUI gets a dependable way.
- [ ] svourztr is one large change (kit modules + four parallel work streams); split it in JayJay if separate commits are wanted.

## Release

- [ ] Optional, only for downloads outside the Mac App Store: notarize a Developer ID build (needs a Developer ID Application certificate and a notarytool profile); see `docs/release.md`. The App Store build only needs the sandbox, which is in place.
- [ ] Liquid Glass icon via Icon Composer (`.icon`) instead of the PNG asset sets.

## Ideas and decisions

- TranslateGemma removed (decided 2026-10-17). On 24 English sentences the 4B model (MLX, 0.5 s per sentence on Mac, 1.4–1.9 s on iPhone) read more naturally than Apple's translator but changed facts in about 1 in 8; 12B (6.7 GB, 1.1 s) made no meaning errors but left English words untranslated and needs 7 GB. Apple's on-device translator was literal but accurate at 0.03 s. Code is in jj history (HearviaLLM, wqonquuz onward) if a later model is worth another look.

- Keys: free + bring-your-own-key for TestFlight and the App Store for now (decided 2026-10-15 and 2026-10-17). A paid tier could come later: a token server (App Attest + StoreKit check, short-lived provider tokens, the app still connects straight to OpenAI/Google) with minutes sold through In-App Purchase; on-device stays free.
- Hybrid "ChatGPT plan" mode: on-device speech + Responses API text translation (`gpt-6-luna`, effort none; ~3–5 s behind sentence end). Plan tokens can't do realtime audio; commercial use needs OpenAI's approval. Probe: `scripts/chatgpt_plan_probe.py`.
- iOS limitations: the screen-sharing picker appears every session; own-audio exclusion is broken on iOS 27.0.1.
