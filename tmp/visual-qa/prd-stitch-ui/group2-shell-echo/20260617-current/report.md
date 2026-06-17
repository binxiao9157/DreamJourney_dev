# Group 2 Shell / Login / Echo QA

Date: 2026-06-17

Scope:

```text
DreamJourney/Sources/TabBar/WarmTabBarController.swift
DreamJourney/Sources/App/AppCoordinator.swift
DreamJourney/Sources/App/AuthCoordinator.swift
DreamJourney/Sources/App/TabCoordinator.swift
DreamJourney/Sources/Modules/Auth/LoginViewController.swift
DreamJourney/Sources/Modules/Echo/EchoViewController.swift
DreamJourney/Sources/Modules/Echo/EchoViewModel.swift
DreamJourney/Sources/Services/DialogEngineManager.swift
DreamJourney/Sources/Services/MicrophonePermissionManager.swift
DreamJourney/Sources/Services/UserManager.swift
```

Review:

```text
docs/superpowers/status/2026-06-17-group2-shell-echo-review.md
```

Guards:

```text
tmp/visual-qa/prd-stitch-ui/warm-tabbar-single-layer-check.swift
tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift
```

## Finding

Group 2 is ready for staged review. The bottom navigation overlap is fixed by suppressing the residual system `UITabBar` and compacting the custom tabbar shadow. `回响` remains voice-first, and archive context remains connected to the prompt path.

Follow-up source review added a guard for the root route contract: auth remains the logged-out root, the PRD three-tab shell remains the logged-in root, login completion enters the shell, and logout returns to auth.

## Latest Visual Evidence

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-124045/01-archive-to-echo-completed.png
```

The duplicate lower navigation layer is gone in the latest simulator screenshot.

## Verification

Passed:

- `swift tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/warm-tabbar-single-layer-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/echo-archive-prompt-smoke-harness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swiftc DreamJourney/Sources/Modules/Echo/EchoViewModel.swift tmp/visual-qa/prd-stitch-ui/echo-archive-context-status-check.swift -o tmp/visual-qa/prd-stitch-ui/group2-shell-echo/20260617-current/echo-archive-context-status-check`
- `tmp/visual-qa/prd-stitch-ui/group2-shell-echo/20260617-current/echo-archive-context-status-check`
- iOS Debug simulator build with `CODE_SIGNING_ALLOWED=NO`
- Archive-to-echo smoke script

Build log:

```text
tmp/visual-qa/prd-stitch-ui/group2-shell-echo/20260617-current/build-route-contract.log
```

Build note:

- Build passed. Warnings remain existing third-party and legacy project warnings, including KeychainAccess deprecations, Alamofire/Moya Swift 6 sendability warnings, AppIcon asset warnings, and older UIKit deprecation warnings in pre-existing modules.

Latest smoke evidence:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-124045/
```

Latest smoke result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```
