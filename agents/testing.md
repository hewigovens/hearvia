# Testing Guide

Load before adding tests or fixtures.

- `just test` runs the HearviaKit unit tests (`swift test`). This is the main gate; engine and conversion logic belongs there. Engines are tested by injecting their model/network boundary (`OnDeviceEngineTests`), `LiveTranslator` with a fake engine factory (`LiveTranslatorTests`).
- `Apps/iOS/Tests` holds PCM analysis tests. They need an iOS 27 destination; no iOS 27 simulator runtime may be installed, so compile them with `just build-tests` and run on a device when they matter.
- `Apps/iOS/UITests` still targets the PoC screens and is outdated; do not extend it before rewriting it for the current UI.
- Engines end to end: `just translate TestMedia/speech/en.aiff zh` (OpenAI Realtime, needs `.env`), the same with `--gemini` (Gemini Live, needs `GEMINI_API_KEY`), and `just translate TestMedia/speech/ja.aiff en --on-device=ja`.
- Choose the smallest layer that proves a behavior. Every bug fix adds the regression test that would have caught it, at the layer that owns the behavior. Do not add tests that only restate constants or wiring.
