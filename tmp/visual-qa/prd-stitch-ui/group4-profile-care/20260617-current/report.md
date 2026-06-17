# Group 4 Profile / Care / Settings / Legal QA

Date: 2026-06-17

Scope:

```text
DreamJourney/Sources/Modules/Profile/ProfileViewController.swift
DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift
DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift
DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift
DreamJourney/Sources/Services/UserManager.swift
DreamJourney/Sources/App/FeatureFlagService.swift
```

Review:

```text
docs/superpowers/status/2026-06-17-group4-profile-care-review.md
```

Primary guard:

```text
tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift
```

## Finding

Group 4 is ready for staged review. The release profile surface stays narrow, settings/legal are real pages, and profile second-level pages now hide the floating tabbar when pushed.

Follow-up source review added an executable care snapshot guard: nested backend payloads parse into bounded signal fields, and Profile/Care code remains guarded from raw transcript/message rendering.

Care backend failure now has a safe visual fallback: `ProfileCareSnapshot.offlineFallback()` renders `待同步` and a local-status caption, so default release UI stays understandable when no backend environment is available.

## Verification

Passed:

- `swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swiftc DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift tmp/visual-qa/prd-stitch-ui/profile-care-snapshot-check.swift -o tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/profile-care-snapshot-check`
- `tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/profile-care-snapshot-check /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/profile-settings-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/profile-legal-center-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- Group 1, Group 2, Group 3, and release feature matrix guards.
- `git diff --check`
- `plutil -lint DreamJourney/Resources/Info.plist DreamJourney.xcodeproj/project.pbxproj`
- iOS Debug simulator build with `CODE_SIGNING_ALLOWED=NO`
- Archive-to-echo smoke script
- Simulator profile root smoke
- Simulator profile settings pushed-page smoke
- Simulator legal center pushed-page smoke

Build log:

```text
tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/build-care-snapshot-guard.log
```

Build note:

- Build passed. Warnings remain existing third-party and legacy project warnings, including KeychainAccess deprecations, Alamofire/Moya Swift 6 sendability warnings, AppIcon asset warnings, and older UIKit deprecation warnings in pre-existing modules.

Latest archive-to-echo smoke:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-130030/
```

Latest smoke result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

Simulator screenshots:

```text
tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/01-profile-release-root.png
tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/02-profile-settings-hidden-tabbar.png
tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/03-profile-legal-hidden-tabbar.png
```

Runtime UI tree findings:

- Profile root shows `个人资料设置`, `法律法规`, and `退出登录`.
- Profile root does not show `家人管理`, `注销账户`, or `立即通话` in release-like mode.
- Settings and legal pushed pages no longer expose the floating tabbar targets.
- Care card can display `待同步` without exposing raw conversation transcript/message data.
