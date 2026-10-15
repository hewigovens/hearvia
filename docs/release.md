# Release Checklist

What a distributable Hearvia build needs, and what is already in place. State as of 2026-10-15.

## Build configuration

| Concern | Debug | Release |
|---|---|---|
| OpenAI and Gemini keys from `.env` (`DevSecrets`) | Baked in when `.env` exists | Empty: `scripts/gen_dev_secrets.sh` writes `""` for non-Debug configurations, and the generated file compiles the keys out under `#if DEBUG` |
| iOS developer tools (Settings → Developer tools, `Apps/iOS/Developer`) | Present | Compiled out (`#if DEBUG`) |
| iOS diagnostic JSONL in Documents/Evidence | Written | Not written; events go to unified logging with field values redacted (`privacy: .private`) |
| iOS `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` | Present | Removed from the built Info.plist by `scripts/strip_release_plist.sh` |
| Mac hardened runtime | On | On |

The Mac app also reads `OPENAI_API_KEY` and `GEMINI_API_KEY` from the process environment as fallbacks. That only works when someone launches the binary with that variable set, so it never ships a key, but drop it if a release should only use the Keychain.

## Privacy manifest

`Apps/iOS/PrivacyInfo.xcprivacy` and `Apps/macOS/PrivacyInfo.xcprivacy` (identical) declare:

- **Tracking:** none; no tracking domains.
- **Required-reason APIs** (app and HearviaKit, which is linked statically):
  - `UserDefaults` → `CA92.1` (the app's own settings and translation preferences).
  - System boot time (`ProcessInfo.systemUptime`) → `35F9.1` (time between in-app events: subtitle lag, audio stats, log timestamps). Nothing leaves the device.
  - No file timestamp, disk space or active keyboard APIs are used. Re-audit when adding code: `grep -rnE "systemUptime|mach_absolute_time|UserDefaults|AppStorage|creationDate|modificationDate|attributesOfItem|volumeAvailableCapacity|statfs|activeInputModes" Apps HearviaKit/Sources`.
- **Collected data:** Audio Data, not linked to the user, not used for tracking, purpose App Functionality. See the judgment call below.

## App Store privacy answers

- **Do you or your third-party partners collect data from this app?** Yes, Audio Data only:
  - When the user chooses the OpenAI Realtime translator, captured speech audio is streamed to OpenAI with the user's own API key to produce subtitles. It isn't stored by Hearvia, sent anywhere else, or linked to an identity by Hearvia.
  - The on-device translator sends nothing off the device.
  - Declaring it is the conservative reading: OpenAI's API retains inputs for a limited time for abuse monitoring, which goes beyond "processed only in real time". If the declaration changes, change both privacy manifests to match.
- **Linked to identity:** No. **Used for tracking:** No. **Purpose:** App Functionality.
- **Everything else** (contact info, identifiers, usage data, diagnostics, location, and so on): not collected. There are no analytics or crash-reporting SDKs. The API key stays in the device Keychain.

## iOS

- [ ] Archive with the Release configuration and upload through Xcode Organizer or `xcodebuild -exportArchive`.
- [ ] Before upload, check that the archive has no key: `strings Hearvia.app/Hearvia | grep -c "sk-"` should print 0.
- [ ] The UI tests target still uses the old prototype screens; don't rely on it as a release check.

## macOS: hardened runtime, sandbox, notarization

### Hardened runtime (done)

`ENABLE_HARDENED_RUNTIME = YES` with `Apps/macOS/Hearvia.entitlements`:

- `com.apple.security.device.audio-input`: microphone input under the hardened runtime.
- The Core Audio process tap needs only `NSAudioCaptureUsageDescription` (already in Info.plist) plus the user's consent in the system prompt. No extra hardened-runtime exception is needed.
- No JIT, unsigned memory, library validation or DYLD exceptions are needed: the app loads only system frameworks and the statically linked HearviaKit.

Still to check on a real run: start capture from system audio and from the microphone in a hardened Release build, since the entitlement problems this setting can cause only show up at runtime.

### App Sandbox (not enabled; looks feasible, needs a test)

What Hearvia does on the Mac, and how it fares in the sandbox:

| Feature | Sandbox needs |
|---|---|
| Microphone (`AVAudioEngine`) | `com.apple.security.device.audio-input` |
| Other apps' audio (Core Audio process tap + private aggregate device) | Taps are created with the audio-capture TCC permission, not by reading other processes, so no temporary exception should be needed. Untested in the sandbox. |
| Listing audio processes (`kAudioHardwarePropertyProcessObjectList`, bundle IDs) | Core Audio HAL properties; expected to work. Untested. |
| OpenAI Realtime WebSocket | `com.apple.security.network.client` |
| On-device Speech and Translation, model downloads | System services; no entitlement |
| Keychain (API key) | Works inside the sandbox; the item moves to the sandbox's keychain access group, so a key saved by an unsandboxed build won't carry over |
| Overlay panel, menu bar, `ShareLink`, pasteboard | No entitlement |

To try it, add `com.apple.security.app-sandbox`, `com.apple.security.network.client` and keep `com.apple.security.device.audio-input`, then test system-audio capture with a few apps (Safari, Music, a Chromium browser), microphone capture, and Realtime translation. The sandbox is required for the Mac App Store, optional for Developer ID distribution.

### Notarization checklist (Developer ID, outside the App Store)

Credentials needed:

- A **Developer ID Application** certificate for team `V28VJH6B6S` in the login keychain (the project currently signs with Apple Development).
- An app-specific password for the Apple ID, or an App Store Connect API key (key ID, issuer ID, `.p8` file), stored once with `xcrun notarytool store-credentials hearvia-notary ...`.

Steps:

```sh
xcodegen generate
xcodebuild -project Hearvia.xcodeproj -scheme HearviaMac -configuration Release \
  -archivePath build/HearviaMac.xcarchive archive
# ExportOptions.plist: method developer-id, teamID V28VJH6B6S, signingStyle automatic
xcodebuild -exportArchive -archivePath build/HearviaMac.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
codesign --verify --strict --deep --verbose=2 build/export/Hearvia.app
codesign -d --entitlements - --verbose=2 build/export/Hearvia.app   # flags=0x10000(runtime), no get-task-allow
ditto -c -k --keepParent build/export/Hearvia.app build/Hearvia.zip
xcrun notarytool submit build/Hearvia.zip --keychain-profile hearvia-notary --wait
xcrun stapler staple build/export/Hearvia.app
spctl --assess --type execute --verbose build/export/Hearvia.app     # "source=Notarized Developer ID"
```

Then ship the stapled app in a zip or DMG; a DMG needs signing, notarizing and stapling too.
