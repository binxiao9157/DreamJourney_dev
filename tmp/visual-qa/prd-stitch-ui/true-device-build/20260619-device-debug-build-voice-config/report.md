# True-device Voice-configured Debug Build Report

Run ID: `20260619-device-debug-build-voice-config`

Date: 2026-06-19

Status: passed

## Root Cause

The previous true-device build was created with the project default build settings:

- `VOLCENGINE_APP_ID = YOUR_VOLCENGINE_APP_ID`
- `VOLCENGINE_APP_KEY = YOUR_VOLCENGINE_APP_KEY`
- `VOLCENGINE_APP_TOKEN = REDACTED

`DialogEngineManager` reads `VolcEngineAppID`, `VolcEngineAppKey`, and `VolcEngineAppToken` from the app `Info.plist`. Because the previous build still contained placeholder values, the app correctly showed:

```text
生产语音服务尚未完成配置，请先注入火山语音 AppID、AppKey 和 Token
```

## Fix Applied For This Build

- Generated a temporary private xcconfig from the existing local private config.
- Injected VolcEngine AppID, AppKey, AppToken, backend base URL, and backend API token into this one true-device build.
- Deleted the temporary xcconfig after build.
- Redacted local build log so private values are not persisted in logs.

No source code was changed.

## Verification

The built app `Info.plist` was checked without printing secret values:

```text
VolcEngineAppID: configured=True
VolcEngineAppKey: configured=True
VolcEngineAppToken: REDACTED
DreamJourneyBackendBaseURL: configured=True
DreamJourneyBackendAPIToken: REDACTED
```

Private values were also checked against the build log and were not present after redaction.

## Build / Install / Launch

- Build: passed
- Install: passed
- Launch: passed
- App path: `tmp/visual-qa/prd-stitch-ui/true-device-build/20260619-device-debug-build-voice-config/DerivedData/Build/Products/Debug-iphoneos/DreamJourney.app`
- Build log: `tmp/visual-qa/prd-stitch-ui/true-device-build/20260619-device-debug-build-voice-config/build.log`
- Install JSON: `tmp/visual-qa/prd-stitch-ui/true-device-build/20260619-device-debug-build-voice-config/install.json`
- Launch JSON: `tmp/visual-qa/prd-stitch-ui/true-device-build/20260619-device-debug-build-voice-config/launch.json`

## Next Manual Check

On the physical iPhone, tap the Echo microphone again.

Expected result:

- The previous configuration-missing toast should not appear.

If a new error appears, it should be treated as the next layer:

- microphone permission,
- SDK initialization,
- network access,
- VolcEngine credential validity,
- ASR/TTS runtime behavior.

## Follow-up True-device Issue: Archived Photo Placeholder

After this voice-configured build, a separate true-device issue was observed in Archive Detail:

- `相册影像` detail showed the placeholder image instead of the previously sealed photo.
- The page still showed `本地已保存`.
- Device container inspection confirmed the original JPG files still existed under `Documents/archive-images`.

Root cause:

- Archive items persisted an absolute `localPath` containing the old iOS app data-container UUID.
- After reinstall / overwrite install, the app data-container UUID changed.
- The old absolute path no longer resolved, even though the same JPG filename still existed in the current `Documents/archive-images` directory.

Fix:

- Commit: `17cd86e fix: recover archive local media paths`
- `MemoryArchiveItem` now resolves stale local media paths by filename against current archive media directories.
- `MemoryArchiveRepository` migrates recovered paths back into local persistence on read.
- Archive list/detail rendering, photo retry analysis, audio playback, and video thumbnails now use the recovered readable path.
- `本地已保存` now depends on a readable recovered file path, not merely `localPath != nil`.

Verification:

- Added guard: `tmp/visual-qa/prd-stitch-ui/archive-local-file-path-recovery-check.swift`
- Guard passed.
- `release-qa-package-check.swift` passed.
- `git diff --check` passed.
- iOS simulator Debug build passed.
- True-device Debug build with private config passed, installed, and launched.
- Device Preferences before fix pointed archive photos to old container `00F86A9C-...`.
- Device Preferences after app launch migrated the same archive photo filenames to current container `1AE68982-...`.

Evidence:

- Photo path debug run: `tmp/visual-qa/prd-stitch-ui/true-device-build/20260619-photo-path-debug/`
- Consolidated issue doc: `docs/superpowers/status/2026-06-19-true-device-test-issues.md`
