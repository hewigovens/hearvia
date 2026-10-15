# Hearvia

Live translated subtitles for anything you hear, on iPhone and Mac. Hearvia listens to other apps' audio or the microphone and shows subtitles on top of whatever you're doing: a floating Picture-in-Picture strip on iOS, a draggable overlay on macOS.

- **Input:** other apps (iOS: ScreenCaptureKit full-display audio; macOS: Core Audio process tap, all apps or one app) or the **microphone** (AVAudioEngine, no voice processing).
- **Translator:**
  - **On-device**: Speech `SpeechTranscriber` + Translation framework. Free, private, offline once the models are downloaded. Each finished sentence is translated, and the sentence still being spoken is re-translated as it changes.
  - **OpenAI Realtime**: `gpt-realtime-translate` over WebSocket. Lowest lag and best quality. Needs an API key; about $2/hour.
- **Look:** dark Periwinkle by default, Paper light optional (Settings → Appearance). Design canvas: <https://claude.ai/artifact/CG6JL1sBWvjKd1YFZGK3bM>.

Requires iOS 27 / macOS 27 and Xcode 27.

## Layout

```
Apps/
  iOS/         Hearvia for iPhone (Views, Capture, Subtitles = PiP, Developer = PoC diagnostics)
    Tests/     unit tests        UITests/  device smoke tests (outdated)
  macOS/       Hearvia for Mac (Views, Capture = Core Audio tap)
  Shared/      DevSecrets.generated.swift (generated, gitignored)
HearviaKit/    Swift package shared by both apps
               LiveTranslator, RealtimeTranslationClient, OnDeviceEngine, MicrophoneCapture, Theme
               hearvia-translate: CLI that streams an audio file through either engine
docs/          PoC feasibility report and measurement protocol
scripts/       gen_dev_secrets.sh, make_icons.swift, chatgpt_plan_probe.py; poc/ = PoC analysis tools
TestMedia/     speech samples for the CLI and a Safari test page
Archive/       local-only PoC evidence (gitignored)
```

## Build

```sh
brew install xcodegen
xcodegen generate                       # creates Hearvia.xcodeproj from project.yml
open Hearvia.xcodeproj                  # schemes: Hearvia (iOS), HearviaMac
```

Command line:

```sh
xcodebuild -project Hearvia.xcodeproj -scheme Hearvia -destination 'generic/platform=iOS' build
xcodebuild -project Hearvia.xcodeproj -scheme HearviaMac -destination 'platform=macOS' build
(cd HearviaKit && swift test)
```

The signing team in `project.yml` is this workspace's; replace `DEVELOPMENT_TEAM` for another account.

### Development API key

Put `OPENAI_API_KEY=sk-…` in `.env` (gitignored). The pre-build script `scripts/gen_dev_secrets.sh` writes it into `Apps/Shared/DevSecrets.generated.swift` for **Debug builds only**, as a fallback when no key is saved in the Keychain. Never ship a build with it.

### Try the engines without the apps

```sh
cd HearviaKit && swift build && cd ..
HearviaKit/.build/debug/hearvia-translate TestMedia/speech/en.aiff zh                  # OpenAI Realtime
HearviaKit/.build/debug/hearvia-translate TestMedia/speech/ja.aiff en --on-device=ja   # on-device
```

### App icon

`swift scripts/make_icons.swift` renders the iOS (default, dark, tinted) and macOS icon sets from the same geometry as `HearviaMark` in `HearviaKit/Sources/HearviaKit/Theme.swift`.

## Background

- [docs/poc-feasibility.md](docs/poc-feasibility.md): what iOS 27 allows (system audio via ScreenCaptureKit, live PiP subtitles) and what it doesn't.
- [docs/poc-measurement.md](docs/poc-measurement.md): how the PoC was measured; the same tools are in the iOS app under Settings → Developer tools.
- [TODO.md](TODO.md): open work.
