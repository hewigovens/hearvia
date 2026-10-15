# TODO

Open work, roughly by priority. State as of 2026-10-15.

## Verify on device (built, not yet tested)

- [ ] iOS microphone mode with both translators, including with another app playing (no ducking or interruption).
- [ ] iOS on-device translator while Hearvia is in the background with PiP up: does SpeechAnalyzer + Translation keep running?
- [ ] PiP keeps the slim 3:1 shape, and auto-starts when leaving the app ("Float when I leave Hearvia").
- [ ] Listening screen: transcript, level meter, timer, Stop. Settings sheet. Light theme on onboarding.
- [ ] Onboarding "Get ready" page: microphone Allow / denied → Settings, model downloads.
- [ ] Bundle IDs changed to `dev.hewig.hearvia` / `dev.hewig.hearvia.mac`: the old "Hearvia PoC" install can be deleted; the Keychain API key and settings start fresh.

## Cost and reliability (OpenAI Realtime)

- [ ] Close the session after 20–30 s of silence and reconnect when sound returns (billing is per connected minute).
- [ ] Rotate the session before the 60-minute expiry instead of relying on reconnect.
- [ ] Skip input transcription when "show original" is off.
- [ ] Transcript lines are cut at sentence punctuation in the translation, so original/translation pairing is approximate.

## Product

- [ ] Hybrid "ChatGPT plan" mode: on-device speech + Responses API text translation (`gpt-6-luna`, effort none; ~3–5 s behind sentence end). Plan tokens can't do realtime audio. Commercial use needs OpenAI's approval. Probe: `scripts/chatgpt_plan_probe.py`.
- [ ] API key / account UX beyond a pasted key.
- [ ] On-device supports more languages than the 13 realtime ones; offer them when that engine is chosen.
- [ ] Mac: option to run as a menu-bar-only app (no Dock icon); tighten the gap between original and translation in the overlay; first-run permission explainer.
- [ ] iOS: the screen-sharing picker appears every session (iOS limitation); own-audio exclusion is broken on iOS 27.0.1.

## Release

- [ ] Hardened runtime, notarization and sandbox review for the Mac app.
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) and App Store privacy answers (audio goes to OpenAI only with the Realtime translator).
- [ ] Liquid Glass icon via Icon Composer (`.icon`) instead of the PNG asset sets.
- [ ] Make sure Release builds never contain `DevSecrets` (Debug-only today).
- [ ] Remove or gate the PoC developer tools (`Apps/iOS/Developer`) for release.

## Code health

- [ ] UI tests (`Apps/iOS/UITests`) still target the PoC screens; rewrite for the new UI.
- [ ] Unit tests for LiveTranslator's on-device draining and transcript segmentation.
- [ ] `AVAudioInputNode.installTap` is deprecated in macOS/iOS 27; move to the replacement API.
- [ ] `OnDeviceTextTranslator` holds `TranslationSession` as `nonisolated(unsafe)`; revisit when the framework is Sendable.
