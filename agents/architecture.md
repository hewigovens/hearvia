# Architecture Guide

Load before changing package boundaries, engines, or what the app shells own.

## Layers

```text
HearviaKit (Swift package, iOS + macOS)
  Translation/  LiveTranslator (+Realtime, +OnDevice, +Transcript), TranslationFeed, TranslationEngine, TranscriptLine
  Realtime/     RealtimeTranslationClient (gpt-realtime-translate WebSocket actor), events, configuration
  OnDevice/     OnDeviceModels (availability, downloads), OnDeviceSpeech (SpeechAnalyzer), OnDeviceTextTranslator
  Audio/        PCM16Resampler, MicrophoneCapture, LevelMeter
  Storage/      KeychainStore
  Design/       palette (Color+Hearvia), Appearance, HearviaMark/Icon, HVButtonStyle, LevelBars,
                SegmentedChoice, TranscriptList, OnDeviceModelsView, LanguageName
  hearvia-translate  CLI: streams an audio file through either engine
Apps/iOS     SwiftUI shell: ScreenCaptureKit / mic capture, PiP subtitle strip, home, onboarding, settings
Apps/macOS   SwiftUI shell: Core Audio process tap / mic capture, overlay panel, control window, menu bar
```

Dependency direction: apps → HearviaKit. The kit never imports UIKit-only or AppKit-only app code; platform branches inside the kit stay in `#if canImport` blocks (`Color+Hearvia`).

## MVVM

```text
capture (app) → TranslationFeed → LiveTranslator (kit) → observable text/transcript → app model → views
```

- **Model (kit)**: `LiveTranslator` is the single pipeline. It owns engine choice, languages, the API key (Keychain), connection/reconnect, on-device sessions and the transcript. Anything both apps must agree on (segmentation, readiness, language names) lives here.
- **App model**: `AppModel` (one per app) owns capture objects and platform presentation (PiP on iOS, overlay panel on macOS), and keeps them in step with `LiveTranslator`. Growing jobs go in `AppModel+Job.swift`.
- **Settings**: `AppSettings` (one per app, `@Observable`, `hearvia.*` UserDefaults keys) holds shell preferences: appearance, overlay/subtitle options, input source, onboarding. Translation preferences stay on `LiveTranslator`.
- **Views** render state and call model methods; they do not talk to engines, capture or Core Audio directly.

## Concurrency

- `LiveTranslator`, `AppModel`, `AppSettings` are `@MainActor @Observable`.
- Audio callbacks run on capture queues and only touch `Sendable` sinks (`TranslationFeed.push`, `LevelMeter.measure`).
- Every async result is checked against `generation` before it changes state, so a slow result from a stopped session cannot overwrite a newer one.
- `RealtimeTranslationClient` is an actor; `OnDeviceTextTranslator` is an actor wrapping a non-Sendable `TranslationSession`.

## Engine contracts

- Realtime: 24 kHz mono PCM16 in 200 ms chunks; sessions expire after 60 minutes; fatal auth/quota errors stop reconnecting.
- On-device: speech models download through `AssetInventory`; translation models are installed through the system sheet (`.translationTask`). The low-latency translation model is a separate download and falls back to the standard one.
- Plan (ChatGPT) tokens cannot drive realtime audio; see `TODO.md`.
