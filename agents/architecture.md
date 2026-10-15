# Architecture Guide

Load before changing package boundaries, engines, or what the app shells own.

## Layers

```text
HearviaKit (one Swift package, one `HearviaKit` product, five modules)
  HearviaCore     Foundation only: Languages, LanguageName, EngineKind, TranslatorStatus, Transcript,
                  SentenceSegmenter, SubtitleText, SecretStore + KeychainStore
  HearviaAudio    AudioFeed (capture → 200 ms PCM16 chunks), PCM16Resampler, MicrophoneCapture, LevelMeter
  HearviaEngines  TranslationEngine protocol + EngineUpdate;
                  Realtime/  RealtimeEngine (+Audio: buffering, silence pause, rotation; +Events), RealtimeSocket,
                             RealtimeTranslationClient (WebSocket actor), RealtimeTiming, events, configuration
                  OnDevice/  OnDeviceEngine (+Text), OnDeviceSpeech (SpeechAnalyzer), OnDeviceTextTranslator, OnDeviceModels
  HearviaSession  LiveTranslator (+Run): preferences, one engine run at a time, observable text/transcript/stats
  HearviaUI       palette, Appearance, HearviaMark/Icon, HVButtonStyle, LevelBars, SegmentedChoice,
                  TranscriptList, OnDeviceModelsView, OnDeviceLanguages (picker lists per engine)
  hearvia-translate  CLI over Audio + Engines: streams an audio file through either engine
Apps/iOS     SwiftUI shell: ScreenCaptureKit / mic capture, PiP subtitle strip, home, onboarding, settings
Apps/macOS   SwiftUI shell: Core Audio process tap / mic capture, overlay panel, control window, menu bar,
             Dock menu (AppDelegate), first-run permission explainer; launch work lives in MenuBarLabel
             because the menu bar extra exists in both Dock and menu-bar-only modes
```

Module dependencies (enforced by Package.swift):

```text
Core, Audio: no dependencies
Engines → Core, Audio
Session → Core, Audio, Engines
UI      → Core, Engines
apps    → any of them; import only the modules a file uses
```

Platform branches inside the kit stay in `#if canImport` blocks (`Color+Hearvia`). Nothing in the kit imports app code.

## Data flow

```text
capture (app) → AudioFeed → TranslationEngine → EngineUpdate stream → LiveTranslator → app model → views
```

- **Engines** turn audio chunks into `EngineUpdate`s (status, full text, finished sentences, problems, failure, logs). An engine instance serves one run; switching languages or engines creates a new one. Engines never touch preferences, the Keychain or UI.
- **Session**: `LiveTranslator` owns translation preferences (`hearvia.engine`, `hearvia.sourceLanguage`, `hearvia.targetLanguage`, API key through `SecretStore`), creates engines through an injected factory, and applies their updates to observable state. Tests pass a fake engine factory, an in-memory `SecretStore` and a scratch `UserDefaults` suite.
- **App model**: `AppModel` (one per app) owns capture objects and platform presentation (PiP on iOS, overlay panel on macOS) and keeps them in step with `LiveTranslator`. Growing jobs go in `AppModel+Job.swift`.
- **Settings**: `AppSettings` (one per app, `@Observable`, `hearvia.*` keys) holds shell preferences: appearance, overlay/subtitle options, input source, onboarding.
- **Views** render state and call model methods; they do not talk to engines, capture or Core Audio directly.

## Concurrency

- `LiveTranslator`, engines, `AppModel`, `AppSettings` are `@MainActor`.
- Audio callbacks run on capture queues and only touch `Sendable` sinks (`AudioFeed.push`, `LevelMeter.measure`).
- Stale results are dropped by identity, not counters: `LiveTranslator` ignores updates from any engine other than the running one, and an engine ignores its own async results once stopped.
- `RealtimeTranslationClient` is an actor; `OnDeviceTextTranslator` is an actor wrapping a non-Sendable `TranslationSession`.

## Adding an engine

Conform to `TranslationEngine`, emit `EngineUpdate`s, add an `EngineKind` case and a branch in `LiveTranslator.makeEngine`. Test it the way `OnDeviceEngineTests` does: inject the model/network boundary and record its updates.

## Release files

Each app has a `PrivacyInfo.xcprivacy`; the Mac app has `Hearvia.entitlements` (hardened runtime, audio input). `scripts/strip_release_plist.sh` removes the Files-sharing keys from the iOS Release Info.plist. See `docs/release.md`.

## Engine contracts

- Realtime: 24 kHz mono PCM16 in 200 ms chunks; billed per connected minute, so the socket closes after 25 s of silence and reopens with pre-roll on sound; sessions expire after 60 minutes and are rotated a few minutes early; fatal auth/quota errors stop reconnecting. Original-language transcription is billed separately and only requested while "show original" is on (`LiveTranslator.setTranscribesSource`).
- On-device: speech models download through `AssetInventory`; translation models are installed through the system sheet (`.translationTask`). The low-latency translation model is a separate download and falls back to the standard one.
- Plan (ChatGPT) tokens cannot drive realtime audio; see `TODO.md`.
