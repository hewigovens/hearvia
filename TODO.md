# TODO

Open work, roughly by priority. State as of 2026-10-16.

## Handoff (where things stand)

- Version control: jj only, in the default workspace (no sibling workspaces). Use `git` only for things jj has no command for, never for commit/add/stash/checkout/reset/worktree. See `agents/version-control.md`.
- History: `main` → wxwkxwuv "Project setup, docs and tooling". On top, oldest first: smlvmklp architecture and agent guides; svourztr HearviaKit modules and release prep; unqokskr one-button main screens; qrlpnzpt tile sheets and transcript history; pmyrxrsz Gemini Live; umuvopot Mac app-wide theme; skutvlks Settings regrouped; rpwvlsyr App Store record and TestFlight milestone; norpsrnw quick start widget, Control Center control and shortcut; zmosyypz Home Screen quick actions; pyyxxryl TestFlight upload recipe and privacy site; nvzuworn transcripts kept and exported; qxwxpkqn Mac App Sandbox; wqonquuz TranslateGemma; nmwkqoyn TranslateGemma background pause and breathing play button; uluomzvq iPhone TranslateGemma labelling; then this TODO update.
- `main` on `origin` (github.com/hewigovens/hearvia) is at wuwnzrkn, pushed 2026-10-16. Publish later changes with `jj bookmark set main -r <rev>` and `jj git push --bookmark main`.
- CI: `.github/workflows/ci.yml` on GitHub's `xcode-27` image (kit tests, SwiftFormat, SwiftLint, unsigned iOS and Mac builds).
- [ ] svourztr is one large change (kit modules + four parallel work streams that touch the same files); split it in JayJay if separate commits are wanted.
- Last verified on 2026-10-16: `just test` (57 tests), Debug builds of both apps, swiftlint and swiftformat clean; the device and Mac checks marked below. TestFlight build 0.1 (202610161055) predates the sandbox, transcripts and TranslateGemma. `just build-tests` was last run before the redesign.

## Milestone: TestFlight 0.1

Goal: internal testers first (no review), then an external group. Keys are bring-your-own (`docs/release.md`); on-device works with no key.

Done:

- [x] App record in App Store Connect: "Hearvia" (Apple ID 6823200947, SKU `hearvia`), iOS + macOS, primary language English (U.S.), created 2026-10-15. Explicit App ID `dev.hewig.hearvia` registered for all platforms.
- [x] One bundle ID for both apps (`dev.hewig.hearvia`), so a later In-App Purchase is a universal purchase. The Mac app moved from `dev.hewig.hearvia.mac`: its settings and Keychain keys start fresh once, and the permission explainer shows again.
- [x] App ID `dev.hewig.hearvia.widgets` ("Hearvia Widgets") registered for the widget extension (2026-10-16).
- [x] Mac App Sandbox on (2026-10-16): all system audio, one app's audio, Gemini Live and the TranslateGemma download work sandboxed (`docs/release.md`).
- [x] `ITSAppUsesNonExemptEncryption = NO` in both apps (HTTPS/WSS only), so uploads skip the export-compliance question.
- [x] Version 0.1 from `MARKETING_VERSION`; build numbers are timestamps, so every upload is unique.
- [x] Hearvia 0.1 (202610161055) uploaded 2026-10-16 (processed, valid).
- [x] `just testflight` / `just testflight-macos` (`scripts/testflight.sh`, ported from AnyTime) archive, export and upload with the App Store Connect API key in `.env`; `just testflight-build ios|macos` stops before uploading (2026-10-16).
- [x] Privacy policy (`docs/privacy.html`) covers the on-device, cloud and TranslateGemma translators, transcripts and permissions.

Left for iPhone TestFlight (in order):

- [x] Stack pushed; GitHub Pages serves `docs/` from `main` and https://hewigovens.github.io/hearvia/privacy.html loads (2026-10-16).
- [ ] App Store Connect: privacy policy URL, and the App Privacy answers from `docs/release.md` (unchanged by TranslateGemma: Hearvia collects nothing from the download).
- [ ] A Release build on the phone (see "Verify on iPhone"): no Developer tools, no file sharing, no diagnostics log; quick start, transcripts and TranslateGemma work.
- [x] Internal TestFlight group "Internal" (internal, access to all builds; `TESTFLIGHT_GROUP=Internal` in `.env`) with hewigovens@gmail.com as tester (2026-10-16).
- [x] iOS 0.1 (202610161709) and Mac 0.1 (202610161713) uploaded with `just testflight` / `just testflight-macos`, processed and in Internal with What to Test notes (2026-10-16). The iOS one is the first archive with MLX and the increased-memory-limit entitlement.
- [ ] Install both from TestFlight and run the "Verify on iPhone" / "Verify on Mac" checks on these Release builds.
- [ ] TestFlight test information: what to test, feedback email, how to add an OpenAI or Gemini key, that a free-tier Gemini key's traffic may be used by Google, and that TranslateGemma is a 2.2 GB download for 8 GB iPhones with background translation on supported devices while iOS grants access.
- [ ] Internal group: you plus a couple of devices; then an external group through Beta App Review (needs the privacy URL and test information).

Left for Mac TestFlight:

- [ ] Sandboxed Mac: speak into the microphone (Microphone source) and save an API key in Settings → Translators; both untested so far.
- [x] Mac TestFlight build (see above). `scripts/testflight.sh` was adapted to asc 5.14: `builds info` instead of `builds find`, no `--version` with `--build-id`/`--build-number`, and no assigning builds to an internal group that already gets every build.

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
- [ ] Home: the play button breathes while idle (checked on Mac only).
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
- [x] TranslateGemma 4B (open weights, MLX, `HearviaLLM`) as a downloadable translator on 8 GB devices, with Apple speech recognition in front (2026-10-16). Mac (Release `gemma-bench`): 1.3 s load, ~0.5 s per sentence, 2.8 GB peak; the sandboxed Mac app downloads it in Settings and subtitles live speech. iPhone 16 Pro (Release, `GemmaDeviceTests`): 6.1 GB free with the increased-memory-limit entitlement, 1.7 s load, 1.4–1.8 s per sentence, 3.8 GB still free once loaded.
- [x] TranslateGemma background GPU support (2026-10-17): request a GPU-enabled continued-processing task for a listening session, report consumed audio, and revoke GPU access on cancellation or expiration. Unsupported devices and denied requests retain foreground translation. The signed iOS app includes Background GPU Access.
- [x] Background task registration (2026-10-17): register each concrete session identifier before submission; keep the wildcard only in Info.plist. Two registrations passed on iPhone 16 Pro, iOS 27.0.1. That phone reports background GPU support as unavailable, so the Gemma background probe skips.
- [ ] Verify background TranslateGemma with live capture, Apple speech recognition and PiP together on iPhone; include task cancellation, interruptions and returning to Hearvia after expiration.
- [ ] TranslateGemma in the iPhone app by hand, Hearvia on screen: microphone mode with no network, a few minutes of speech.
- [ ] TranslateGemma download in the iPhone app (Settings → Translators, 2.2 GB over Wi-Fi); the test phone has the model copied in already.
- [ ] TranslateGemma quality: 2 of 8 English test sentences came out wrong in Chinese ("fell asleep 20 minutes faster" → "slept 20 minutes"; "Activation went up" garbled). Compare against the built-in translator on real speech before calling it "better".
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

- [ ] No UI tests since the PoC smoke tests were removed (2026-10-16); add some for the redesigned iOS UI (GitHub's `xcode-27` image has iOS 27 simulators).
- [x] Unit tests for the cloud engine's reconnect/backoff, pause and rotation (fake socket).
- [x] Moved off the deprecated `installTap` to `installAudioTap`.
- [ ] `TranslationSession` is still not Sendable in the 27 SDK, so `OnDeviceTextTranslator` and `OnDeviceModelsView` keep `nonisolated(unsafe)`; revisit with a later SDK.
- [ ] `Apps/iOS/Developer/DeveloperView.swift` still offers only `Languages.supported`.
- [ ] Mac menu-bar-only launch closes the control window by polling for it (`MenuBarLabel.closeLaunchWindow`) because `.defaultLaunchBehavior` was unreliable; replace if SwiftUI gets a dependable way.
