# Intent opportunities

## Existing App Intents inventory

Hearvia declares one App Intent action. It is an App Shortcut, a Control Center control, and it opens the app when run. It does not adopt an Apple Intelligence schema. A declaration is not proof that Siri or Shortcuts will offer it on a device.

| Business action | Intent / shortcut / entity / query paths and symbols | What is wired today | Missing pieces / evidence limits |
| --- | --- | --- | --- |
| Start live subtitles | `StartListeningIntent` in `Apps/iOS/QuickStart/StartListeningIntent.swift`. `HearviaShortcuts` in `Apps/iOS/QuickStart/HearviaShortcuts.swift`. `QuickStartControl` in `Apps/iOSWidgets/QuickStartControl.swift`. Optional `InputSource` parameter (`AppEnum`). | App Shortcut phrases "Start Hearvia" and "Start subtitles in Hearvia". Control Center button "Start Hearvia". `openAppWhenRun` is true. `perform` sets `QuickStart.shared.request`; `HomeView.startIfRequested` starts listening after onboarding. Widget and app both compile the intent. | Not exercised from Shortcuts or Siri in this session. No Spotlight index and no Apple Intelligence schema. The Mac app declares no App Intents. |

## Project and scope

- Project Hearvia, `/projects/29826d62-a2f9-45ed-97d9-25e2050f5c66`. Analysis date 2026-10-24. Imported app. Transcript search (list field, match marks, no-matches state, on-device search helper and tests) is in this change, on top of `ae7a1af`.
- First analysis. Reason: search on saved transcripts is now implemented, so the core-feature check runs before the handoff. No previous `intent-opportunities.md`.
- Brief: search the transcripts already on the device, from the list, on iPhone and Mac. Implemented that way. Search text is not sent off the device.
- Inspected: `TranscriptsSheet`, `TranscriptDetailView`, `TranscriptList`, `TranscriptSearch`, `TranscriptView` (Mac), `TranscriptHistory`, `LiveTranslator.savedTranscripts`, `StartListeningIntent`, `HearviaShortcuts`, `QuickStartControl`, `project.yml` deployment targets. Did not re-read the App Intents SDK interface files.

| Target / configuration | Relevant sources | Deployment target | SDK / toolchain evidence | Unknowns |
| --- | --- | --- | --- | --- |
| Hearvia iOS app | `Apps/iOS`, `project.yml` | iOS 27.0 | This session's simulator archive used Xcode 27.1 RC because `DuoPosture` calls an iOS 27.1 API. The default builder is Xcode 27.0 and cannot compile that call. | Whether a later default builder includes the 27.1 SDK. |
| HearviaWidgets | `Apps/iOSWidgets` | Same iOS app generation | Compiles in the same archive. Control uses `StartListeningIntent`. | Control was not tapped on a device. |
| Hearvia Mac | `Apps/macOS` | macOS 26.4 (package platforms) | Mac package tests for search passed on the default builder earlier this session. | Mac App Intents were not searched beyond a project-wide symbol search, which found none. |

## Decision summary

First batch: nothing new. Start Listening is already integrated. Searching transcripts is useful later, but the query lives only on the open list, and nothing outside that screen can open the list with a query. Adding a shortcut would be a new navigation hook, not a wire-up of a function the system can already call. That hook is out of this round. No Apple Intelligence schema was checked, so none is proposed.

## Assessed actions

### Start live subtitles — the user asks to start subtitles without hunting for the button

- **Business state:** implemented. `StartListeningIntent.perform` records a request. The home screen consumes it and starts listening when onboarding is already done.
- **Code chain:** Shortcut or control → `StartListeningIntent.perform` → `QuickStart.shared.request` → `HomeView.startIfRequested` → the existing listen path. Screen sharing for other apps still needs the system sheet in the foreground (`openAppWhenRun`).
- **Verdict:** already integrated.
- **Direction:** no change in this round. Repeating it asks to start again; it does not toggle off.
- **Access and safety:** no account. Microphone or screen-share permission is the existing listen path, unchanged.
- **Ordinary path:** already shipped in the app. Symbols read in project source: `AppIntent`, `AppShortcutsProvider`, `AppShortcut`, `openAppWhenRun`, `AppEnum`. SDK interface files were not re-read; availability is whatever this target already compiles.
- **Schema enhancement:** not determined. No schema guide was read for this action.
- **System entry points:** App Shortcut and a control are declared. Shortcuts visibility, Siri recognition, and a real device were not checked.
- **Priority and cost:** leave it. S, no new work.
- **Validation and next step:** not run from Shortcuts in the simulator this session.

### Search transcripts — the user wants the lines that contain a phrase

- **Business state:** implemented in the app. The list filters sessions whose original or translation contains the phrase. The open transcript marks every non-overlapping match and scrolls to the first. Saved sessions come from `TranscriptHistory` on disk. The session in progress is memory only. Undownloaded iCloud files stay hidden, same as the list.
- **Code chain:** Transcripts button on the home screen → `TranscriptsSheet` / Mac `TranscriptView` `@State` query → `Transcript.matches` and `TranscriptSearch.matchRanges`. There is no Intent. The query is not readable from outside the view.
- **Verdict:** recommended later, not in this batch. The brief is the on-screen field. A shortcut needs a proposed way to open the list with a phrase, which does not exist.
- **Direction:** a future intent could take a phrase, open the app, and show the same filtered list. If several sessions match, the list stays the result, same as typing in the field. If none match, the existing no-matches state. Repeating it replaces the phrase; it does not stack searches. Stable ids already exist on `Transcript` for a later "open this session" step. That open-with-phrase behavior is a proposal.
- **Access and safety:** no account. Results stay on device. The phrase would be an intent parameter, so Shortcuts could store it; that is a product choice, not part of the current field.
- **Ordinary path:** same App Intent pattern as Start Listening, plus a proposed navigation hook. Not ready until that hook exists. SDK annotations were not re-read.
- **Schema enhancement:** not applicable from evidence read. No domain was checked.
- **System entry points:** Shortcuts would be the useful one. Spotlight indexing of private transcripts was not assessed and is not proposed. Siri and Apple Intelligence were not evaluated.
- **Priority and cost:** after this round, if wanted. M. Depends on a navigation hook and a product yes. Assumption: people would rather speak a phrase than open the list. No usage numbers exist.
- **Validation and next step:** in-app search was checked on the iPhone 18 Pro simulator. An intent was not compiled.

## Exclusions

| Action | Why it is not a candidate |
| --- | --- |
| Delete one transcript, delete all | Destructive, and the confirmation dialog is the product. A shortcut would need its own confirmation design. |
| Export / Copy | Already a share sheet or the Mac pasteboard from the open transcript. |
| Save transcripts toggle, iCloud sync | Settings switches, not a task someone launches from outside the app. |
| Change language or translator | Setup, not the job the app was opened to do. |

## API and availability evidence

| ID | Symbol | Where it was read | Availability claimed | Limit |
| --- | --- | --- | --- | --- |
| E1 | `AppIntent`, `openAppWhenRun`, `AppEnum`, `AppShortcutsProvider`, `AppShortcut` | Project source listed above, already compiled into the iOS app | Not re-derived from SDK headers | Enough to say the app already uses them. Not enough to quote a new minimum OS. |

## Validation gaps

- Shortcuts, Siri, and the control were not run.
- Apple Intelligence schemas were not read.
- The Mac app has no App Intents in the files searched.
- Search-as-a-shortcut was not implemented and was not compiled.
