# Design Guide

Load before changing colors, icons, copy, or interaction patterns.

- Design canvas (icon, themes, every screen): <https://claude.ai/artifact/CG6JL1sBWvjKd1YFZGK3bM>.
- Themes: **Periwinkle** dark (default, accent `#8B9CFF` on `#0E1020`) and **Paper light** (accent `#2F5BFF` on `#F7F7F5`), switchable in Settings → Appearance (Dark / Light / System). Tokens live in `HearviaKit/Sources/HearviaUI/Color+Hearvia.swift`.
- Subtitle surfaces (PiP window, inline preview, Mac overlay) are always dark: translation white, original speech grey above it.
- Icon: "wave to words" (three waveform bars becoming two subtitle lines). `HearviaMark` draws it in-app; `just icons` renders the asset catalogs from the same geometry.
- Hearvia must never interrupt what the user is watching or listening to: no audio playback, mixable audio sessions, and copy that says so.
- Main screens follow the canvas's "Redesign B · One button" boards: a round listen button that ripples on press and becomes a pulsing red stop; while listening the button shrinks and the subtitles and transcript grow. Respect Reduce Motion.
- Touch targets ≥ 44 pt on iOS; keyboard shortcuts for Start/Stop on macOS (⌘↩).
