# Hearvia

[![CI](https://github.com/hewigovens/hearvia/actions/workflows/ci.yml/badge.svg)](https://github.com/hewigovens/hearvia/actions/workflows/ci.yml)

Live translated subtitles for anything you hear, on iPhone and Mac. Hearvia listens to other apps' audio or the microphone and shows subtitles on top of whatever you're doing: a floating Picture-in-Picture strip on iOS, a draggable overlay on macOS.

- **Input:** other apps (iOS: ScreenCaptureKit full-display audio; macOS: Core Audio process tap, all apps or one app) or the **microphone** (AVAudioEngine, no voice processing).
- **Translator:**
  - **On-device**: Speech `SpeechTranscriber` + Translation framework. Free, private, offline once the models are downloaded. Each finished sentence is translated, and the sentence still being spoken is re-translated as it changes.
  - **OpenAI Realtime**: `gpt-realtime-translate` over WebSocket. Lowest lag and best quality. Needs an API key; about $2/hour.
  - **Gemini Live**: `gemini-3.5-live-translate-preview` over the Live API. Free tier for testing; needs a Gemini API key.
  - **TranslateGemma**: Apple speech recognition + Google's open TranslateGemma 4B, run with MLX. A 2.2 GB download for 8 GB devices; offline. On iPhone it translates while Hearvia is on screen (iOS keeps background apps off the GPU).
- **Look:** dark Periwinkle by default, Paper light optional (Settings → Appearance). Design canvas: <https://claude.ai/artifact/CG6JL1sBWvjKd1YFZGK3bM>.

Requires iOS 27 / macOS 27 and Xcode 27.

## Layout

```
HearviaKit/      Swift package shared by both apps, one product with five modules
  HearviaCore    languages, engine kinds, status, transcript and sentence segmentation, Keychain
  HearviaAudio   capture feed, resampler, microphone capture, level meter
  HearviaEngines TranslationEngine protocol; Realtime (WebSocket) and on-device (SpeechAnalyzer + Translation)
  HearviaSession LiveTranslator: preferences and the running engine, observable text and transcript
  HearviaUI      colors, appearance, icon mark, buttons, segmented control, transcript list, model downloads
  hearvia-translate: CLI that streams an audio file through any engine
HearviaLLM/      Swift package for open-weight models (kept out of HearviaKit so its tests stay MLX-free)
  HearviaGemma   TranslateGemma download, MLX translator and engine; gemma-bench times it per sentence
Apps/iOS/      App, Home, Onboarding, Settings, Capture (ScreenCaptureKit), Subtitles (PiP), Developer (PoC tools)
Apps/macOS/    App, Control, Overlay, Transcript, Settings, MenuBar, Capture (Core Audio process tap)
agents/        architecture, SwiftUI, design, testing, version-control and run/debug guides (start at AGENTS.md)
docs/          release notes, PoC feasibility report and measurement protocol; also the GitHub Pages site
               (index.html, privacy.html: https://hewigovens.github.io/hearvia/)
scripts/       gen_dev_secrets.sh, make_icons.swift, chatgpt_plan_probe.py; poc/ = PoC analysis tools
TestMedia/     speech samples for the CLI and a Safari test page
```

Architecture and conventions: [AGENTS.md](AGENTS.md).

## Build

Needs Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen), [just](https://github.com/casey/just), SwiftFormat and SwiftLint (`brew install xcodegen just swiftformat swiftlint`).

```sh
just generate      # Hearvia.xcodeproj from project.yml (not checked in); schemes Hearvia (iOS) and HearviaMac
just build         # both apps
just test          # HearviaKit unit tests
just run-mac       # launch the Mac app with JSON event logging
just install-ios   # build, install and launch on the paired iPhone (HEARVIA_DEVICE=<udid>)
just format lint
```

The signing team in `project.yml` is this workspace's; replace `DEVELOPMENT_TEAM` for another account.

CI (`.github/workflows/ci.yml`, GitHub's `xcode-27` image) runs the kit tests, SwiftFormat and SwiftLint, and unsigned builds of both apps on every push to `main` and every pull request.

### Development API key

Put `OPENAI_API_KEY=sk-…` and/or `GEMINI_API_KEY=AIza…` (free from [Google AI Studio](https://aistudio.google.com/apikey)) in `.env` (gitignored). The pre-build script `scripts/gen_dev_secrets.sh` writes them into `Apps/Shared/DevSecrets.generated.swift` for **Debug builds only**, as fallbacks when no key is saved in the Keychain. Never ship a build with them.

### Try the engines without the apps

```sh
just translate TestMedia/speech/en.aiff zh                  # OpenAI Realtime (needs .env)
just translate TestMedia/speech/en.aiff zh --gemini         # Gemini Live (needs GEMINI_API_KEY)
just translate TestMedia/speech/ja.aiff en --on-device=ja   # on-device
```

### App icon

`just icons` renders the iOS (default, dark, tinted) and macOS icon sets from the same geometry as `HearviaMark` in `HearviaKit/Sources/HearviaUI/HearviaMark.swift`.

## Background

- [docs/poc-feasibility.md](docs/poc-feasibility.md): what iOS 27 allows (system audio via ScreenCaptureKit, live PiP subtitles) and what it doesn't.
- [docs/poc-measurement.md](docs/poc-measurement.md): how the PoC was measured; the same tools are in the iOS app under Settings → Developer tools.
- [TODO.md](TODO.md): open work.
