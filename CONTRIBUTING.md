# Contributing to Hearvia

Hearvia uses [Jujutsu](https://github.com/jj-vcs/jj) for version control, not git.

## Before you start

- **New features:** [open an issue](https://github.com/hewigovens/hearvia/issues/new) before starting, so the proposal can be discussed.
- **Bug fixes:** you may send a pull request directly. Link an issue if there is one and describe the bug and the fix.

## Setup

Needs macOS 27, Xcode 27 (with the Metal Toolchain: `xcodebuild -downloadComponent MetalToolchain`), [XcodeGen](https://github.com/yonaskolb/XcodeGen), [just](https://github.com/casey/just), SwiftFormat and SwiftLint:

```sh
brew install xcodegen just swiftformat swiftlint
```

To sign, copy `project.local.yml.example` to `project.local.yml` (gitignored) and set your team ID; `just generate` picks it up. Without it the apps still build unsigned (as in CI).

## Layout

```
HearviaKit/      Swift package shared by both apps, one product with five modules
  HearviaCore    languages, engine kinds, status, transcript and sentence segmentation, Keychain
  HearviaAudio   capture feed, resampler, microphone capture, level meter
  HearviaEngines TranslationEngine protocol; cloud (OpenAI Realtime, Gemini Live) and on-device engines
  HearviaSession LiveTranslator: preferences and the running engine, observable text and transcript
  HearviaUI      colors, appearance, icon mark, buttons, tiles, transcript list, model downloads
  hearvia-translate: CLI that streams an audio file through any engine
HearviaLLM/      Swift package for open-weight models (kept out of HearviaKit so its tests stay MLX-free)
  HearviaGemma   TranslateGemma download, MLX translator and engine; gemma-bench times it per sentence
Apps/iOS/        App, Home, Onboarding, Settings, Capture (ScreenCaptureKit), Subtitles (PiP), QuickStart, Developer
Apps/macOS/      App, Control, Overlay, Transcript, Settings, MenuBar, Capture (Core Audio process tap)
agents/          architecture, SwiftUI, design, testing, version-control and run/debug guides
docs/            release notes, screenshots, and the GitHub Pages site (index.html, privacy.html)
scripts/         dev secrets, icons, TestFlight uploads
TestMedia/       speech samples for the CLI
```

Architecture and conventions: [AGENTS.md](AGENTS.md) and the guides in `agents/`.

## Development

```sh
just generate      # Hearvia.xcodeproj from project.yml (not checked in); schemes Hearvia (iOS) and HearviaMac
just build         # both apps
just test          # HearviaKit unit tests
just run-mac       # launch the Mac app with JSON event logging
just install-ios   # build, install and launch on the paired iPhone (HEARVIA_DEVICE=<udid>)
just format lint
```

Run `just` for the full list. CI (`.github/workflows/ci.yml`, GitHub's `xcode-27` image) runs the kit tests, SwiftFormat, SwiftLint and unsigned builds of both apps on every push to `main` and every pull request.

### Development API keys

Put `OPENAI_API_KEY=sk-…` and/or `GEMINI_API_KEY=AIza…` (free from [Google AI Studio](https://aistudio.google.com/apikey)) in `.env` (gitignored). The pre-build script `scripts/gen_dev_secrets.sh` writes them into `Apps/Shared/DevSecrets.generated.swift` for **Debug builds only**, as fallbacks when no key is saved in the Keychain. Never ship a build with them, and never paste or commit a key.

### Try the engines without the apps

```sh
just translate TestMedia/speech/en.aiff zh                  # OpenAI Realtime (needs OPENAI_API_KEY)
just translate TestMedia/speech/en.aiff zh --gemini         # Gemini Live (needs GEMINI_API_KEY)
just translate TestMedia/speech/ja.aiff en --on-device=ja   # on-device
```

TranslateGemma has its own benchmark; see [agents/run-debug.md](agents/run-debug.md).

### App icon

`just icons` renders the iOS (default, dark, tinted) and macOS icon sets from the same geometry as `HearviaMark` in `HearviaKit/Sources/HearviaUI/HearviaMark.swift`.

### Releases

TestFlight uploads (`just testflight`, `just testflight-macos`), the sandbox and App Store privacy answers are in [docs/release.md](docs/release.md).

## Testing

Test behavior at the smallest layer that proves it; see [agents/testing.md](agents/testing.md). Bug fixes should include the regression test that would have caught them.

## Pull requests

Before publishing, do the two cleanup rounds from [AGENTS.md](AGENTS.md), then run `just format`, `just lint`, `just build` and `just test`. Write the change description as a short summary, a blank line, and a body saying what changed and why. Pull requests that change the UI should include screenshots.

## License

By contributing, you agree that your contributions are licensed under the project's [license](LICENSE).
