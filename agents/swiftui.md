# SwiftUI Shell Guide

Load before changing app file layout, models, settings, or presentation.

## File Layout

```text
Apps/iOS/
├── App/          HearviaApp, AppModel (+Listening, +Subtitles, +Diagnostics, +QuickStart), AppSettings, InputSource
├── Home/         HomeView, HomePresentation, HomeHeader, StartPrompt, HomeTiles, ListeningSummary,
│                 TileSheet + SourceSheet, LanguagesSheet (LanguageCard), TranslatorSheet (EngineStatus),
│                 ChoiceRow, CircleButton
├── Transcripts/  TranscriptsSheet (in progress + saved), TranscriptDetailView (export, delete)
├── Onboarding/   OnboardingView, OnboardingPage, FeatureCard, Bullet, MicrophonePermissionRow
├── Settings/     SettingsView, TranslatorSettingsView (API keys and on-device models)
├── Capture/      CaptureController (ScreenCaptureKit), AudioProbe, ProbeSnapshot, AudioAnalysis,
│                 AudioSessionController, SessionMode
├── Subtitles/    PiPController, SubtitleRenderer, SubtitlePreview
├── Developer/    DeveloperView, DiagnosticsPanel, DiagnosticLog (PoC diagnostics)
├── QuickStart/   StartListeningIntent (+ QuickStart request, InputSource as AppEnum), HearviaShortcuts,
│                 QuickActionSceneDelegate (Home Screen quick actions, installed by HearviaApp)
├── Tests/
Apps/iOSWidgets/  HearviaWidgets extension: QuickStartWidget (Home/Lock Screen), QuickStartControl (Control Center).
                  Also compiles QuickStart/StartListeningIntent.swift and App/InputSource.swift; the intent runs in the app
Apps/macOS/
├── App/          HearviaMacApp (scenes), AppModel (+Capture), AppSettings, CaptureSource
├── Capture/      ProcessTapCapture, AudioProcesses, AudioProcess, CoreAudioProperty, CoreAudioError
├── Control/      ControlPanel (menu bar popover and main window), ListenHero, ControlTiles, OverlayOptions,
│                 EngineStatusLine
├── Overlay/      OverlayPanel (+ OverlayPointer), OverlayView
├── Settings/     SettingsView (tabs: General, Translators, Overlay, Diagnostics)
├── Transcript/   TranscriptView (Transcripts window: sidebar of sessions, export/copy/delete)
└── MenuBar/      MenuBarLabel, MenuBarMenu
Apps/Shared/      DevSecrets.generated.swift (generated, optional in project.yml)
```

`project.yml` globs `Apps/iOS` and `Apps/macOS`, so moves need no project edits. `Hearvia.xcodeproj` is generated (`just generate`) and not checked in.

## Conventions

- **State ownership**: the `App` creates `AppSettings` and `AppModel(settings:)` once in `init` as `@State`, and injects settings with `.environment(settings)`. Views read `@Environment(AppSettings.self)` and use a local `@Bindable var settings = settings` for bindings. Pass the model explicitly (`let model: AppModel`); use `@Bindable` only in views that bind model properties.
- **Settings side effects**: views or the model react to settings with `.onChange` (iOS home) or `withObservationTracking` (macOS overlay panel, which is AppKit). Settings objects only persist values; they do not call back into models.
- **Composition over long bodies**: a screen is a thin composer (`HomeView`, `ControlPanel`) over focused subviews (`HomeHeader`, `StartPrompt`, `HomeTiles`, `TranscriptCard`). Prefer a small `View` type over a long `@ViewBuilder` property when it has its own inputs.
- **Main screens**: both apps centre a `ListenButton` over three `ControlTile`s (Listen to · Languages · Translator). Starting animates one layout into the other, so keep the button's identity across states: one slot in a stable stack on iOS, `AnyLayout` on macOS. Drive it with one `.animation(_:value:)` on the listening flag.
- **Theme**: on macOS `AppSettings.applyAppearance()` sets `NSApp.appearance`, so every window (menu bar popover and overlay included) resolves the palette's dynamic colors the same way; don't add per-view `preferredColorScheme` there. iOS views use `preferredColorScheme`.
- **Shared look**: colors are `Color.hv*` tokens; buttons use `HVButtonStyle` or `ListenButton`. Never hard-code hex colors in an app view; the subtitle surfaces stay dark in both themes.
- **Copy**: plain, outcome-first, no jargon ("Other apps keep playing").

## Presentation Surfaces

- **Inline state**: missing models, missing API key, waiting for the iOS picker, errors under the main button.
- **Sheet / full-screen cover**: driven by one optional enum per screen (`HomePresentation`), not by several booleans.
  Each home tile opens a `TileSheet` (title over its choices, detent fitted to the content), so the three behave alike.
- **Floating window**: PiP on iOS (`PiPController`, 1.8:1 sample-buffer layer that must stay on screen inline; its ✕ stops listening, Back to app does not), overlay `NSPanel` on macOS (non-activating, all Spaces, compact while idle and full-size while listening, hover ✕ and Start/Stop, `WindowDragGesture` elsewhere unless click-through).

## Platform notes

- iOS: the PiP inline layer (`SubtitlePreview`) must stay in the view hierarchy while listening, or PiP cannot start on leaving the app.
- iOS: ScreenCaptureKit shows the system picker on every start; the app never plays audio (own-audio exclusion is unreliable on 27.0.1).
- macOS: the overlay hosting view returns itself from `hitTest` so any click drags the window.
