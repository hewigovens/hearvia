# Architecture Guide

Load before changing package boundaries, engines, or what the app shells own.

## Layers

```text
HearviaKit (one Swift package, one `HearviaKit` product, five modules)
  HearviaCore     Foundation only: Languages, LanguageName, EngineKind, TranslatorStatus, Transcript,
                  SentenceSegmenter, SubtitleText, SecretStore + KeychainStore
  HearviaAudio    AudioFeed (capture → 200 ms PCM16 chunks), PCM16Resampler, MicrophoneCapture, LevelMeter
  HearviaEngines  TranslationEngine protocol + EngineUpdate;
                  Cloud/     CloudEngine (+Audio: buffering, silence pause, rotation; +Events), CloudTiming,
                             TranslationSocket protocol + SocketEvent: one engine for every streaming provider
                  OpenAI/    OpenAIRealtimeClient (WebSocket actor) + configuration
                  Gemini/    GeminiLiveClient (WebSocket actor, 24 → 16 kHz) + configuration
                  OnDevice/  OnDeviceEngine (+Text), OnDeviceSpeech (SpeechAnalyzer), OnDeviceTextTranslator, OnDeviceModels
  HearviaSession  LiveTranslator (+Run, +Status): preferences, one engine run at a time, observable text/transcript/stats;
                  TranscriptHistory: one JSON file per finished session in Application Support/Hearvia/Transcripts;
                  BackgroundGPUAccess: platform-neutral grant, progress, cancellation and supersession state;
                  DownloadableEngine: an engine whose model the app downloads and runs (TranslateGemma)
  HearviaUI       palette, Appearance, HearviaMark/Icon, HVButtonStyle, ListenButton, ControlTile, LevelBars,
                  TranscriptList, OnDeviceModelsView, DownloadableEngineRow, OnDeviceLanguages (picker lists per engine)
  hearvia-translate  CLI over Audio + Engines: streams an audio file through any engine
HearviaLLM (separate package, so the kit and its tests stay MLX-free; build with xcodebuild, MLX needs its Metal library)
  HearviaGemma    TranslateGemma (download into Application Support/Hearvia/Models, memory gate), GemmaTranslator
                  (MLX, one sentence per call), GemmaEngine: the apps' DownloadableEngine for `.gemma`
  gemma-bench     CLI: downloads the model and times translating sentences one at a time
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
UI      → Core, Engines, Session
HearviaGemma → HearviaKit, mlx-swift-lm, swift-huggingface, swift-transformers
apps    → any of them; import only the modules a file uses
```

Platform branches inside the kit stay in `#if canImport` blocks (`Color+Hearvia`). Nothing in the kit imports app code.

## Data flow

```text
capture (app) → AudioFeed → TranslationEngine → EngineUpdate stream → LiveTranslator → app model → views
```

- **Engines** turn audio chunks into `EngineUpdate`s (status, full text, finished sentences, problems, failure, logs). An engine instance serves one run; switching languages or engines creates a new one. Engines never touch preferences, the Keychain or UI.
- **Session**: `LiveTranslator` owns translation preferences (`hearvia.engine`, `hearvia.sourceLanguage`, `hearvia.targetLanguage`, one API key per cloud engine through `SecretStore`, account `EngineKind.keyAccount`), creates engines through an injected factory, and applies their updates to observable state. Tests pass a fake engine factory, an in-memory `SecretStore` and a scratch `UserDefaults` suite.
- **App model**: `AppModel` (one per app) owns capture objects and platform presentation (PiP on iOS, overlay panel on macOS) and keeps them in step with `LiveTranslator`. Growing jobs go in `AppModel+Job.swift`.
- **Settings**: `AppSettings` (one per app, `@Observable`, `hearvia.*` keys) holds shell preferences: appearance, overlay/subtitle options, input source, onboarding.
- **Views** render state and call model methods; they do not talk to engines, capture or Core Audio directly.

## Concurrency

- `LiveTranslator`, engines, `AppModel`, `AppSettings` are `@MainActor`.
- Audio callbacks run on capture queues and only touch `Sendable` sinks (`AudioFeed.push`, `LevelMeter.measure`).
- Stale results are dropped by identity, not counters: `LiveTranslator` ignores updates from any engine other than the running one, and an engine ignores its own async results once stopped.
- `OpenAIRealtimeClient` and `GeminiLiveClient` are actors; `OnDeviceTextTranslator` is an actor wrapping a non-Sendable `TranslationSession`.

## Adding an engine

Conform to `TranslationEngine`, emit `EngineUpdate`s, add an `EngineKind` case and a branch in `LiveTranslator.makeEngine`. Test it the way `OnDeviceEngineTests` does: inject the model/network boundary and record its updates.

A streaming cloud provider needs no new engine: write a `TranslationSocket` client (connect, send 24 kHz chunks converted to what the provider takes, map server messages to `SocketEvent`s, mark rejected keys and exhausted quota `fatal`), add a `CloudEngine` factory, and give the `EngineKind` a `keyAccount`. Test the client's message parsing the way `GeminiLiveClientTests` does; `CloudEngineTests` already cover reconnects, pauses and rotation.

## Release files

Each app has a `PrivacyInfo.xcprivacy`; the Mac app has `Hearvia.entitlements` (hardened runtime, audio input). `scripts/strip_release_plist.sh` removes the Files-sharing keys from the iOS Release Info.plist. See `docs/release.md`.

## Engine contracts

- Cloud engines (both): 24 kHz mono PCM16 in 200 ms chunks from the feed; the socket closes after 25 s of silence and reopens with pre-roll on sound; it is replaced a few minutes before the provider ends it; fatal auth/quota errors stop reconnecting. Original-language transcription is only requested while "show original" is on (`LiveTranslator.setTranscribesSource`).
- OpenAI Realtime: billed per connected minute; sessions expire after 60 minutes; the target language changes within a session; original-language transcription is billed separately.
- Gemini Live (`gemini-3.5-live-translate-preview`, preview): 16 kHz input; the target language is fixed per session, so a change opens a new one; Google ends a connection after about 10 minutes (and announces it with `goAway`), so it rotates every few minutes. Output is audio plus transcripts; the audio is discarded but billed. Translation settings go in `generationConfig`, transcript settings beside it in `setup` (the service rejects them inside `generationConfig`). Tested live 2026-10-15: subtitles trail the source transcript by about 0.2 s; with a Japanese target the preview model sometimes drops a sentence's last clause and moves on. Free tier available; about $0.037 per minute paid.
- TranslateGemma (`mlx-community/translategemma-4b-it-4bit`, 2.2 GB, Gemma Terms of Use): `OnDeviceEngine` with Apple speech recognition and TranslateGemma for the text, loaded per run and freed on stop. Measured on the Mac 2026-10-16: 1.3 s load, about 0.5 s per sentence (en→zh, en→ja), 2.8 GB peak footprint. Offered only on 8 GB devices; loading needs 3.2 GB free (`os_proc_available_memory` on iOS, with the increased-memory-limit entitlement). iPhone 16 Pro (Release): 1.7 s load, 1.4–1.9 s per sentence. On iOS, the app shell's `BackgroundTranslation` adapter requests a GPU-enabled `BGContinuedProcessingTask` for a Gemma listening session, only while foregrounded and on a supported device. `HearviaSession.BackgroundGPUAccess` owns grant, progress and cancellation state. The entitlement and `processing` background mode are configured in the iOS target. Compatibility comes from `BGTaskScheduler.supportedResources`, with no device-model allowlist. The UI distinguishes unsupported, available, requesting, active, denied and expired access; device support alone never implies a session grant. Progress counts consumed audio chunks; stopping or switching engines completes the task. A denied or expired task revokes GPU access, and returning to Hearvia permits another request. `GemmaTranslator` checks the injected grant before loading and between generated tokens; without a grant it throws `GemmaError.inBackground` behind other apps. MLX's CPU backend is too slow on the phone. MLX calls run inside `withError`, since its default handler ends the process. swift-huggingface 1.0 throws after a cache-less snapshot download even though every file landed; `TranslateGemma.download` checks the files and carries on.
- On-device: speech models download through `AssetInventory`; translation models are installed through the system sheet (`.translationTask`). The low-latency translation model is a separate download and falls back to the standard one.
- Plan (ChatGPT) tokens cannot drive realtime audio; see `TODO.md`.
