# TODO

Open work, roughly by priority. State as of 2026-10-15.

## Handoff (where things stand)

- Version control: jj only, in the default workspace (no sibling workspaces). Use `git` only for things jj has no command for, never for commit/add/stash/checkout/reset/worktree. See `agents/version-control.md`.
- History: `main` → "Project setup, docs and tooling" (wxwkxwuv). On top: smlvmklp "Adopt JayJay-style SwiftUI architecture and agent guides", svourztr "HearviaKit modules, Realtime cost controls, release prep and Mac polish", unqokskr "iOS, macOS: one-button main screens with animated start/stop", qrlpnzpt "iOS: tile sheets, transcript as history, quiet user stop, aligned onboarding", pmyrxrsz "HearviaKit, apps: Gemini Live translator behind a provider-neutral cloud engine", then the working copy. Nothing pushed; `main` not moved yet.
- [ ] Review the stack, then `jj bookmark set main -r <rev>` and `jj git push --bookmark main` (remote `origin` = github.com/hewigovens/hearvia).
- [ ] svourztr is one large change (kit modules + four parallel work streams that touch the same files); split it in JayJay if separate commits are wanted.
- Last verified on 2026-10-15: `just test` (50 tests), Debug builds of both apps, swiftlint and swiftformat clean, the device and Mac checks marked below. Release builds and `just build-tests` were last run before the redesign.

## Milestone: TestFlight 0.1

Goal: internal testers first (no review), then an external group. Keys are bring-your-own (`docs/release.md`); on-device works with no key.

- [x] App record in App Store Connect: "Hearvia" (Apple ID 6823200947, SKU `hearvia`), iOS + macOS, primary language English (U.S.), created 2026-10-15. Explicit App ID `dev.hewig.hearvia` registered for all platforms.
- [x] One bundle ID for both apps (`dev.hewig.hearvia`), so a later In-App Purchase is a universal purchase. The Mac app moved from `dev.hewig.hearvia.mac`: its settings and Keychain keys start fresh once, and the permission explainer shows again.
- [x] App ID `dev.hewig.hearvia.widgets` ("Hearvia Widgets") registered for the widget extension (2026-10-16).
- [ ] Mac only: TestFlight and the Mac App Store require App Sandbox. Checked 2026-10-16 on a scratch copy: with `app-sandbox`, `network.client` and `device.audio-input`, system-audio capture and on-device translation worked, with no Core Audio or network denials. Still to try sandboxed: per-app capture from the process list, microphone, Realtime/Gemini with a key, saving a key to the Keychain.
- [x] `ITSAppUsesNonExemptEncryption = NO` in both apps (HTTPS/WSS only), so uploads skip the export-compliance question.
- [x] Version 0.1 from `MARKETING_VERSION`; `just upload-ios` stamps `CFBundleVersion` with a timestamp, so every upload is unique.
- [x] `just upload-ios` archives a Release build and uploads it: Hearvia 0.1 (202610161055) uploaded 2026-10-16. Mac needs the sandbox first.
- [ ] Re-check a Release build on the phone first (no Developer tools, no file sharing, no diagnostics log; see "Verify on iPhone").
- [ ] App Privacy answers in App Store Connect from `docs/release.md`.
- [ ] Privacy policy at https://hewigovens.github.io/hearvia/privacy.html: `site/` and `.github/workflows/pages.yml` are ready; after pushing, set the repo's Pages source to GitHub Actions and enter the URL in App Store Connect.
- [ ] TestFlight test information: what to test, feedback email, how to add an OpenAI or Gemini key, and that a free-tier Gemini key's traffic may be used by Google.
- [ ] Internal group: you plus a couple of devices; then an external group through Beta App Review.

## Verify on iPhone (built, not yet tested)

- [x] iOS microphone mode with OpenAI Realtime (tested on device 2026-10-15, before the HearviaKit split).
- [x] Other apps (screen sharing) with the on-device translator and the floating window, on the redesigned build (tested on device 2026-10-15).
- [x] The floating window's ✕ stops listening; stopping from the red status-bar indicator shows no error (2026-10-15).
- [ ] Re-check microphone + Realtime on the current build: the mic path now uses `installAudioTap` instead of the deprecated `installTap`.
- [ ] iOS microphone mode with the on-device translator, and with another app playing (no ducking or interruption).
- [ ] The floating window auto-starts when leaving the app ("Float when I leave Hearvia"), and Back to app doesn't stop listening.
- [ ] Home: the play button's ripple and the move to the bottom when listening; the three tile sheets size to their content; the transcript sheet from the header.
- [x] Onboarding "Your languages" and "Get ready" pages render with the shared language picker and matching cards (screenshots 2026-10-15).
- [ ] Onboarding "Get ready": microphone Allow / denied → Settings, model downloads. Light theme on onboarding.
- [ ] Language pickers: on-device lists the system's languages, the cloud engines the fixed 13; switching to a cloud engine with an unsupported subtitle language falls back to English (unit-tested).
- [ ] Silence pause/resume and "show original" off on iOS (Realtime restarts when the toggle changes while listening).
- [ ] A Release build on the phone: no Developer tools in Settings, no Files sharing, no diagnostics log file.
- [ ] Bundle ID is `dev.hewig.hearvia` on both platforms: delete the old "Hearvia PoC" install; Keychain key and settings start fresh. Translation preferences also moved to `hearvia.engine` / `hearvia.sourceLanguage` / `hearvia.targetLanguage`, so languages reset once.

- [ ] Quick start: add the Hearvia widget (small and medium), the Control Center control and "Start Hearvia" in Shortcuts, and try both icon quick actions (long-press the app icon); each opens the app and starts listening (other apps still show the iOS sharing sheet). Check a cold launch, and that onboarding comes first on a fresh install.

- [ ] Transcripts on iPhone: a session appears under Transcripts after Stop (and after leaving the app mid-session); export a .txt to Files; swipe to delete; "Save transcripts" off keeps nothing.

## Verify on Mac

- [x] Realtime with system audio under the hardened runtime; silence pause after 25 s and resume with pre-roll; on-device ja → en; Dock vs menu-bar-only launch (5 launches); permission explainer; overlay keeps two original lines.
- [x] Redesigned control window, ready and listening (screenshots 2026-10-15); overlay hover ✕ and Start, drag, and the Visible chip bringing it back (2026-10-15).
- [ ] The menu bar popover (same panel as the window) opened from the status item, in both themes.
- [ ] Microphone source end to end. Launch the app from Finder/`open` (launching the binary from a terminal makes macOS ask for the terminal app's microphone access instead of Hearvia's).
- [ ] Settings → "Show in menu bar only" toggled live both ways; Dock-icon click reopens the control window; Dock menu Start/Stop and Show overlay.
- [ ] Session rotation in a real session close to 60 minutes (log event `translation_rotated`).
- [ ] Overlay: the faded top edge of the translation can leave a faint trace of a clipped line; check at other font sizes.

- [x] Transcripts on Mac: a session is saved on quit and listed in the Transcripts window with Export, Copy and Delete (2026-10-16).

## Gemini Live (preview)

- [x] CLI end to end with a free-tier key: en → zh and en → ja stream about 0.2 s behind the source transcript; a rejected key stops without reconnecting.
- [ ] en → ja dropped the clip's last clause ("…smaller than expected") on every run, even with more speech after it; recheck when the model leaves preview, and compare other targets.
- [ ] Try it in the apps on device: rotation every ~7–9 minutes, silence pause and resume, a language change mid-session.
- [ ] Offer Gemini its full 70+ subtitle languages instead of OpenAI's 13.

## Cost and reliability (cloud engines)

- [x] Close the session after 25 s of silence and reconnect when sound returns, with 1.6 s of pre-roll.
- [x] Rotate the session before the 60-minute expiry (unit-tested).
- [x] Skip input transcription when "show original" is off.
- [ ] Tune the silence threshold (about −40 dBFS peak, `CloudTiming.silencePeak`): videos with background music may never pause.
- [ ] Transcript lines are cut at sentence punctuation in the translation, so original/translation pairing is approximate.
- [ ] Source text from consecutive sessions (after a pause or rotation) is joined without a space ("…than expected Good evening").

## Product

- [ ] Hybrid "ChatGPT plan" mode: on-device speech + Responses API text translation (`gpt-6-luna`, effort none; ~3–5 s behind sentence end). Plan tokens can't do realtime audio. Commercial use needs OpenAI's approval. Probe: `scripts/chatgpt_plan_probe.py`.
- [x] Keys for TestFlight: bring your own key only (decided 2026-10-15). On-device is the default; testers paste an OpenAI or Gemini key in Settings → Translators. See `docs/release.md`.
- [ ] Keys for the App Store: decide on a paid tier later. Option on the table: a token server (App Attest + StoreKit check, short-lived provider tokens, the app still connects straight to OpenAI/Google) with minutes sold through In-App Purchase; on-device stays free.
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
- [x] Unit tests for the cloud engine's reconnect/backoff, pause and rotation (fake socket).
- [x] Moved off the deprecated `installTap` to `installAudioTap`.
- [ ] `TranslationSession` is still not Sendable in the 27 SDK, so `OnDeviceTextTranslator` and `OnDeviceModelsView` keep `nonisolated(unsafe)`; revisit with a later SDK.
- [ ] `Apps/iOS/Developer/DeveloperView.swift` still offers only `Languages.supported`.
- [ ] Mac menu-bar-only launch closes the control window by polling for it (`MenuBarLabel.closeLaunchWindow`) because `.defaultLaunchBehavior` was unreliable; replace if SwiftUI gets a dependable way.
