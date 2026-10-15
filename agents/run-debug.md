# Run & Debug Guide

Load before building, running, or capturing screenshots.

- `just generate` → `Hearvia.xcodeproj`; `just build` builds both apps; `just run-mac` launches the Mac app with `--verbose` (JSON events on stdout); `--autostart` starts capture at launch and skips the first-run permission explainer (`defaults delete dev.hewig.hearvia.mac hearvia.hasExplainedPermissions` shows it again). `hearvia.menuBarOnly` selects menu-bar-only mode.
- iPhone: `just install-ios` builds, installs and launches on the paired device (`HEARVIA_DEVICE` overrides the UDID). Pass launch arguments after `--` with `xcrun devicectl device process launch … -- -hearvia.appearance light`.
- Screenshots: `xcrun devicectl device capture screenshot --device <udid> --destination out.png` (the phone must be unlocked; a locked phone returns a black image). Mac windows: `screencapture -o -l <windowID>`; never capture the whole screen, it includes the user's other apps.
- No iOS 27 simulator runtime may be installed; verify iOS UI on the device.
- PoC diagnostics are in Debug builds of the iOS app under Settings → Developer tools; logs export as JSONL from there. See `docs/poc-measurement.md`. Release builds have no developer UI and write no log file.
- Realtime engine log events: `translation_connected`, `translation_session`, `translation_paused` / `translation_resumed` (silence), `translation_rotated` (before expiry), `translation_error`, `translation_closed`.
- Keep scratch output outside the workspace tree; jj snapshots untracked files into the change.
