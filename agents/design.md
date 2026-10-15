# Design Guide

Load before changing colors, icons, copy, or interaction patterns.

- Design canvas (icon, themes, every screen): <https://claude.ai/artifact/CG6JL1sBWvjKd1YFZGK3bM>.
- Themes: **Periwinkle** dark (default, accent `#8B9CFF` on `#0E1020`) and **Paper light** (accent `#2F5BFF` on `#F7F7F5`), switchable in Settings → Appearance (Dark / Light / System). Tokens live in `HearviaKit/Sources/HearviaUI/Color+Hearvia.swift`.
- Subtitle surfaces (PiP strip, inline preview, Mac overlay) are always dark: translation white, original speech grey above it.
- Icon: "wave to words" (three waveform bars becoming two subtitle lines). `HearviaMark` draws it in-app; `just icons` renders the asset catalogs from the same geometry.
- Hearvia must never interrupt what the user is watching or listening to: no audio playback, mixable audio sessions, and copy that says so.
- Touch targets ≥ 44 pt on iOS; keyboard shortcuts for Start/Stop on macOS (⌘↩).
