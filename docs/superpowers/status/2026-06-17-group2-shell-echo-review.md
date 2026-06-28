# Group 2 Shell, Login, Echo, And Prompt Context Review

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Scope:

- `DreamJourney/Sources/TabBar/WarmTabBarController.swift`
- `DreamJourney/Sources/App/AppCoordinator.swift`
- `DreamJourney/Sources/App/AuthCoordinator.swift`
- `DreamJourney/Sources/App/TabCoordinator.swift`
- `DreamJourney/Sources/Modules/Auth/LoginViewController.swift`
- `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- `DreamJourney/Sources/Modules/Echo/EchoViewModel.swift`
- `DreamJourney/Sources/Services/DialogEngineManager.swift`
- `DreamJourney/Sources/Services/MicrophonePermissionManager.swift`
- `DreamJourney/Sources/Services/UserManager.swift`

## Review Result

Status: ready for staged review after the bottom navigation overlap fix.

## What This Group Provides

- Keeps the public shell to the Stitch/PRD tabs: `记忆档案`, `回响`, `我的`.
- Keeps the root route contract explicit: logged-out users see auth, logged-in users see the PRD shell, and logout returns to auth.
- Suppresses the system `UITabBar` so only the custom floating navigation is visible and reachable.
- Aligns login copy and layout with the current Stitch direction while preserving the existing login callback.
- Keeps `回响` voice-first and does not expose text/image echo inputs.
- Refreshes archive context status when voice interaction starts and after a user turn.
- Injects archive context into the real dialog prompt and captures UIQA prompt debug evidence.
- Keeps simulator microphone permission deterministic for UIQA.
- Keeps profile nickname updates centralized in `UserManager` with update notifications.

## Root Cause Fixed

The bottom navigation overlap came from two layers being present at runtime:

- The custom `WarmTabBarView`.
- Residual system `UITabBar` accessibility/render targets underneath it.

`WarmTabBarController` now actively suppresses the system tabbar rendering, touch handling, and accessibility elements during lifecycle/layout. The custom tabbar shadow was also compacted and pinned to a single pill-shaped `shadowPath`.

## Guard Scripts

```text
Scripts/QA/prd-stitch-ui/warm-tabbar-single-layer-check.swift
Scripts/QA/prd-stitch-ui/group2-shell-echo-check.swift
```

## QA Evidence

Latest screenshot after the overlap fix:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-124045/01-archive-to-echo-completed.png
```

Finding: the duplicate lower navigation layer is gone; only the custom floating tabbar remains visible.

Runtime UI tree evidence:

- Before suppression: extra system `tab` targets were present.
- After suppression: snapshot shows custom button/text targets only; the extra system `tab` targets are no longer present.

Latest archive-to-echo smoke result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

Latest QA report:

```text
tmp/visual-qa/prd-stitch-ui/group2-shell-echo/20260617-current/report.md
```

Passed:

- Group 2 shell/echo guard.
- Root auth/main-shell route contract guard.
- Warm tabbar single-layer guard.
- Echo archive prompt smoke harness guard.
- Release feature matrix guard.
- Echo archive context status executable check.
- iOS Debug simulator build.
- Archive-to-echo smoke script.

## Remaining Notes

- Real device voice SDK behavior still needs device-level verification.
- Echo text/image inputs remain intentionally hidden until PRD release scope changes.
