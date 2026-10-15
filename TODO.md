# TODO

Open work, roughly by priority. State as of 2026-10-15.

## Handoff (where things stand)

- Version control: jj only, in the default workspace (no sibling workspaces). Use `git` only for things jj has no command for, never for commit/add/stash/checkout/reset/worktree. See `agents/version-control.md`.
- History: `main` → "Project setup, docs and tooling" (wxwkxwuv). On top: smlvmklp "Adopt JayJay-style SwiftUI architecture and agent guides", then svourztr "HearviaKit modules, Realtime cost controls, release prep and Mac polish" (the working copy). Nothing pushed; `main` not moved yet.
- [ ] Review svourztr, then `jj bookmark set main -r svourztr` and `jj git push --bookmark main` (remote `origin` = github.com/hewigovens/hearvia).
- [ ] svourztr is one large change (kit modules + four parallel work streams that touch the same files); split it in JayJay if separate commits are wanted.
- Last verified on 2026-10-15: `just test` (38 tests), Debug and Release builds of both apps, `just build-tests`, swiftlint and swiftformat clean, Mac runtime checks listed below.

## Verify on iPhone (built, not yet tested)

- [x] iOS microphone mode with OpenAI Realtime (tested on device 2026-10-15, before the HearviaKit split).
- [ ] Install the current build (`just install-ios`) and re-check microphone + Realtime: the mic path now uses `installAudioTap` instead of the deprecated `installTap`.
- [ ] iOS microphone mode with the on-device translator, and with another app playing (no ducking or interruption).
- [ ] iOS on-device translator while Hearvia is in the background with PiP up: does SpeechAnalyzer + Translation keep running?
- [ ] PiP keeps the slim 3:1 shape, and auto-starts when leaving the app ("Float when I leave Hearvia").
- [ ] Listening screen: transcript, level meter, timer, Stop. Settings sheet. Light theme on onboarding.
- [ ] Onboarding "Get ready" page: microphone Allow / denied → Settings, model downloads.
- [ ] Language pickers: on-device lists the system's languages, Realtime the fixed 13; switching to Realtime with an unsupported subtitle language falls back to English.
- [ ] Silence pause/resume and "show original" off on iOS (Realtime restarts when the toggle changes while listening).
- [ ] A Release build on the phone: no Developer tools in Settings, no Files sharing, no diagnostics log file.
- [ ] Bundle IDs changed to `dev.hewig.hearvia` / `dev.hewig.hearvia.mac`: delete the old "Hearvia PoC" install; Keychain key and settings start fresh. Translation preferences also moved to `hearvia.engine` / `hearvia.sourceLanguage` / `hearvia.targetLanguage`, so languages reset once.

## Verify on Mac

- [x] Realtime with system audio under the hardened runtime; silence pause after 25 s and resume with pre-roll; on-device ja → en; Dock vs menu-bar-only launch (5 launches); permission explainer; overlay keeps two original lines.
- [ ] Microphone source end to end. Launch the app from Finder/`open` (launching the binary from a terminal makes macOS ask for the terminal app's microphone access instead of Hearvia's).
- [ ] Settings → "Show in menu bar only" toggled live both ways; Dock-icon click reopens the control window; Dock menu Start/Stop and Show overlay.
- [ ] Session rotation in a real session close to 60 minutes (log event `translation_rotated`).
- [ ] Overlay: the faded top edge of the translation can leave a faint trace of a clipped line; check at other font sizes.

## Cost and reliability (OpenAI Realtime)

- [x] Close the session after 25 s of silence and reconnect when sound returns, with 1.6 s of pre-roll.
- [x] Rotate the session before the 60-minute expiry (unit-tested).
- [x] Skip input transcription when "show original" is off.
- [ ] Tune the silence threshold (about −40 dBFS peak, `RealtimeTiming.silencePeak`): videos with background music may never pause.
- [ ] Transcript lines are cut at sentence punctuation in the translation, so original/translation pairing is approximate.
- [ ] Source text from consecutive sessions (after a pause or rotation) is joined without a space ("…than expected Good evening").

## Product

- [ ] Hybrid "ChatGPT plan" mode: on-device speech + Responses API text translation (`gpt-6-luna`, effort none; ~3–5 s behind sentence end). Plan tokens can't do realtime audio. Commercial use needs OpenAI's approval. Probe: `scripts/chatgpt_plan_probe.py`.
- [ ] API key / account UX beyond a pasted key.
- [x] On-device offers more languages than the 13 Realtime ones.
- [x] Mac: Dock icon by default with a menu-bar-only setting and a Dock menu; tighter overlay; first-run permission explainer.
- [ ] iOS: the screen-sharing picker appears every session (iOS limitation); own-audio exclusion is broken on iOS 27.0.1.

## Release

- [x] Hardened runtime for the Mac app; sandbox review and notarization checklist in `docs/release.md`.
- [ ] Notarize a Developer ID build (needs a Developer ID Application certificate and a notarytool profile), and try App Sandbox with the process tap (see `docs/release.md`).
- [x] Privacy manifests for both apps and App Store privacy answers (`docs/release.md`). Audio Data is declared as collected (not linked, not tracking) because OpenAI retains API inputs for abuse monitoring; revisit if that changes.
- [ ] Liquid Glass icon via Icon Composer (`.icon`) instead of the PNG asset sets.
- [x] Release builds never contain `DevSecrets` or read `OPENAI_API_KEY`.
- [x] PoC developer tools are Debug-only.

## Code health

- [ ] UI tests (`Apps/iOS/UITests`) still target the PoC screens; rewrite for the new UI (needs an iOS 27 simulator or a device).
- [x] Unit tests for RealtimeEngine reconnect/backoff, pause and rotation (fake socket).
- [x] Moved off the deprecated `installTap` to `installAudioTap`.
- [ ] `TranslationSession` is still not Sendable in the 27 SDK, so `OnDeviceTextTranslator` and `OnDeviceModelsView` keep `nonisolated(unsafe)`; revisit with a later SDK.
- [ ] `Apps/iOS/Developer/DeveloperView.swift` still offers only `Languages.supported`.
- [ ] Mac menu-bar-only launch closes the control window by polling for it (`MenuBarLabel.closeLaunchWindow`) because `.defaultLaunchBehavior` was unreliable; replace if SwiftUI gets a dependable way.
