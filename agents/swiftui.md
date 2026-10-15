# SwiftUI Shell Guide

Load before changing app file layout, models, settings, or presentation.

## File Layout

```text
Apps/iOS/
├── App/          HearviaApp, AppModel (+Listening, +Subtitles, +Diagnostics), AppSettings, InputSource
├── Home/         HomeView, HomePresentation, HomeHeader, ReadyPanel, ListeningPanel, ListenControls,
│                 LanguageCard, EngineCard, EngineStatus, TranscriptCard, Card, CircleButton
├── Onboarding/   OnboardingView, OnboardingPage, FeatureCard, Bullet, MicrophonePermissionRow
├── Settings/     SettingsView
├── Capture/      CaptureController (ScreenCaptureKit), AudioProbe, ProbeSnapshot, AudioAnalysis,
│                 AudioSessionController, SessionMode
├── Subtitles/    PiPController, SubtitleRenderer, SubtitlePreview
├── Developer/    DeveloperView, DiagnosticsPanel, DiagnosticLog (PoC diagnostics)
├── Tests/, UITests/
Apps/macOS/
├── App/          HearviaMacApp (scenes), AppModel (+Capture), AppSettings, CaptureSource
├── Capture/      ProcessTapCapture, AudioProcesses, AudioProcess, CoreAudioProperty, CoreAudioError
├── Control/      ControlView, EngineStatusLine
├── Overlay/      OverlayPanel, OverlayView, DraggableHostingView
├── Settings/     SettingsView
├── Transcript/   TranscriptView
└── MenuBar/      MenuBarContent
Apps/Shared/      DevSecrets.generated.swift (generated, optional in project.yml)
```

`project.yml` globs `Apps/iOS` and `Apps/macOS`, so moves need no project edits. `Hearvia.xcodeproj` is generated (`just generate`) and not checked in.

## Conventions

- **State ownership**: the `App` creates `AppSettings` and `AppModel(settings:)` once in `init` as `@State`, and injects settings with `.environment(settings)`. Views read `@Environment(AppSettings.self)` and use a local `@Bindable var settings = settings` for bindings. Pass the model explicitly (`let model: AppModel`); use `@Bindable` only in views that bind model properties.
- **Settings side effects**: views or the model react to settings with `.onChange` (iOS home) or `withObservationTracking` (macOS overlay panel, which is AppKit). Settings objects only persist values; they do not call back into models.
- **Composition over long bodies**: a screen is a thin composer (`HomeView`) over focused subviews (`HomeHeader`, `ReadyPanel`, `ListeningPanel`, `ListenControls`). Prefer a small `View` type over a long `@ViewBuilder` property when it has its own inputs.
- **Shared look**: colors are `Color.hv*` tokens; buttons use `HVButtonStyle`; segmented choices use `SegmentedChoice` (system segmented controls ignore the tint on macOS). Never hard-code hex colors in an app view; the subtitle surfaces stay dark in both themes.
- **Copy**: plain, outcome-first, no jargon ("Other apps keep playing").

## Presentation Surfaces

- **Inline state**: missing models, missing API key, waiting for the iOS picker, errors under the main button.
- **Sheet / full-screen cover**: driven by one optional enum per screen (`HomePresentation`), not by several booleans.
- **Floating window**: PiP on iOS (`PiPController`, 3:1 sample-buffer layer that must stay on screen inline), overlay `NSPanel` on macOS (non-activating, all Spaces, draggable unless click-through).

## Platform notes

- iOS: the PiP inline layer (`SubtitlePreview`) must stay in the view hierarchy while listening, or PiP cannot start on leaving the app.
- iOS: ScreenCaptureKit shows the system picker on every start; the app never plays audio (own-audio exclusion is unreliable on 27.0.1).
- macOS: the overlay hosting view returns itself from `hitTest` so any click drags the window.
