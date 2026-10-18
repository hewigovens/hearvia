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

## API keys in TestFlight builds

Decided 2026-10-15: TestFlight builds ship with no key and rely on bring-your-own-key. Release builds compile `DevSecrets` out, so a fresh install starts on the on-device translator; testers who want a cloud translator paste their own OpenAI or Gemini key in Settings → Translators (Keychain, this device only). Never hand out the team's keys. A Gemini free-tier key works for testing, but Google may use free-tier traffic to improve its products, so testers should know that. A paid tier (token server plus In-App Purchase) is deferred; see `TODO.md`.

## Privacy manifest

`Apps/iOS/PrivacyInfo.xcprivacy` and `Apps/macOS/PrivacyInfo.xcprivacy` (identical) declare:

- **Tracking:** none; no tracking domains.
- **Required-reason APIs** (app and HearviaKit, which is linked statically):
  - `UserDefaults` → `CA92.1` (the app's own settings and translation preferences).
  - System boot time (`ProcessInfo.systemUptime`) → `35F9.1` (time between in-app events: subtitle lag, audio stats, log timestamps). Nothing leaves the device.
  - No file timestamp, disk space or active keyboard APIs are used. Re-audit when adding code: `grep -rnE "systemUptime|mach_absolute_time|UserDefaults|AppStorage|creationDate|modificationDate|attributesOfItem|volumeAvailableCapacity|statfs|activeInputModes" Apps HearviaKit/Sources`.
- **Collected data:** Audio Data, not linked to the user, not used for tracking, purpose App Functionality. See the judgment call below.

## App Store privacy answers

- **Privacy policy URL:** https://hewigovens.github.io/hearvia/privacy.html (`docs/privacy.html`; GitHub Pages serves `docs/` from `main`, and `docs/.nojekyll` publishes the files as they are).
- **Do you or your third-party partners collect data from this app?** Yes, Audio Data only:
  - When the user chooses a cloud translator (OpenAI Realtime or Gemini Live), captured speech audio is streamed to OpenAI or Google with the user's own API key to produce subtitles. It isn't stored by Hearvia, sent anywhere else, or linked to an identity by Hearvia.
  - The on-device translator sends nothing off the device.
  - Declaring it is the conservative reading: the providers' APIs retain inputs for a limited time for abuse monitoring (and Google may use free-tier Gemini traffic to improve its products), which goes beyond "processed only in real time". If the declaration changes, change both privacy manifests to match.
- **Linked to identity:** No. **Used for tracking:** No. **Purpose:** App Functionality.
- **Everything else** (contact info, identifiers, usage data, diagnostics, location, and so on): not collected. There are no analytics or crash-reporting SDKs. The API key stays in the device Keychain.

## TestFlight uploads

`scripts/testflight.sh` (ported from the AnyTime repo) archives with the Release configuration, exports with `scripts/ExportOptions-AppStore.plist` (App Store Connect, automatic signing) into `build/testflight/<platform>/`, and uploads:

```sh
just testflight-auth            # check the API key; writes a repo-local .asc/config.json (gitignored)
just testflight-build ios       # archive and export only; also `macos`
just testflight                 # iOS: upload the .ipa with asc
just testflight-macos           # Mac: upload the .pkg with altool, then asc for processing and distribution
```

- `.env` (gitignored) holds `ASC_APP_ID` (the app's App Store Connect ID) and the App Store Connect API key: `APP_STORE_CONNECT_KEY_NAME`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_PATH` (a `.p8` outside the repo, shared with the AnyTime and Inspect repos). Never print or commit them.
- Optional: `TESTFLIGHT_GROUP` (group name or ID; the build is added to it and the script waits for processing), `TESTFLIGHT_NOTES` ("What to Test"), `TESTFLIGHT_NOTIFY`, `TESTFLIGHT_WAIT`, `TESTFLIGHT_TIMEOUT`, `TESTFLIGHT_BUILD_NUMBER`.
- An internal group with access to all builds (like "Internal") receives every processed build by itself; the script doesn't try to add builds to it.
- Build numbers count up within each `MARKETING_VERSION`, one sequence shared by iOS and Mac (the next number after the highest uploaded for either), so a new version starts at 1. Version 0.1 used timestamps (`yyyyMMddHHmm`), so its numbers stay that long. `TESTFLIGHT_BUILD_NUMBER` overrides it.
- Before uploading, check the iOS archive has no key: `strings build/testflight/ios/Hearvia.xcarchive/Products/Applications/Hearvia.app/Hearvia | grep -c "sk-"` should print 0.

## macOS: hardened runtime, sandbox, notarization

### Hardened runtime (done)

`ENABLE_HARDENED_RUNTIME = YES` with `Apps/macOS/Hearvia.entitlements`:

- `com.apple.security.device.audio-input`: microphone input under the hardened runtime.
- The Core Audio process tap needs only `NSAudioCaptureUsageDescription` (already in Info.plist) plus the user's consent in the system prompt. No extra hardened-runtime exception is needed.
- No JIT, unsigned memory, library validation or DYLD exceptions are needed: the app loads only system frameworks and the statically linked HearviaKit.

Still to check on a real run: start capture from system audio and from the microphone in a hardened Release build, since the entitlement problems this setting can cause only show up at runtime.

### App Sandbox (enabled 2026-10-16)

`Apps/macOS/Hearvia.entitlements`: `com.apple.security.app-sandbox`, `com.apple.security.device.audio-input`, `com.apple.security.network.client`. Core Audio taps need no temporary exception: the tap, the process list and the private aggregate device are all calls to the Core Audio system object, and the system asks for the audio-capture permission itself.

Checked with the sandboxed Debug build (`--autostart`, `--source=`, logs on stdout):

| Feature | Result |
|---|---|
| All system audio (process tap) + on-device translation | Works |
| One app's audio (`--source=<pid>`, process list and PID lookup) | Works |
| Gemini Live WebSocket (`network.client`) | Works |
| Microphone | Starts; not confirmed with speech (the test Mac played into headphones) |
| Saving a key in Settings (Keychain) | Not tested yet (the key field couldn't be filled by automation) |

The only sandbox denials logged were disk-space probes (`system-info vfs.disk-space`) and one NVMe user client, neither affecting capture. Moving into the sandbox gives the app a container: settings, transcripts and Keychain items from unsandboxed builds don't carry over.

### Notarization checklist (Developer ID, outside the App Store)

Credentials needed:

- A **Developer ID Application** certificate for the team in `project.local.yml` in the login keychain (the project currently signs with Apple Development).
- An app-specific password for the Apple ID, or an App Store Connect API key (key ID, issuer ID, `.p8` file), stored once with `xcrun notarytool store-credentials hearvia-notary ...`.

Steps:

```sh
xcodegen generate
xcodebuild -project Hearvia.xcodeproj -scheme HearviaMac -configuration Release \
  -archivePath build/HearviaMac.xcarchive archive
# ExportOptions.plist: method developer-id, teamID <your team>, signingStyle automatic
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
