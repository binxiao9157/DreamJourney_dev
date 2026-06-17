# Group 4 Profile, Care, Settings, And Legal Review

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Scope:

- `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- `DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift`
- `DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift`
- `DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift`
- `DreamJourney/Sources/Services/UserManager.swift`
- `DreamJourney/Sources/App/FeatureFlagService.swift`

## Review Result

Status: ready for staged review after the pushed-page bottom navigation fix.

## What This Group Provides

- Keeps public profile rows to `个人资料设置`, `法律法规`, and `退出登录`.
- Keeps `家人管理`, `注销账户`, and `立即通话` hidden by default.
- Keeps hidden profile branches accessible only through feature flags or explicit UIQA launch argument `DJEnableProfileHiddenBranches`.
- Promotes `个人资料设置` to a real release-visible page with nickname editing, avatar display, masked phone display, and save confirmation.
- Promotes `法律法规` to a real release-visible page covering AI assistance, mental health boundaries, privacy/data, digital-human ethics, and emergency guidance.
- Keeps care snapshot parsing limited to signal fields and out of raw transcript/message rendering.
- Adds a safe offline/stale care snapshot fallback so backend failures show `待同步` and a non-medical local-status caption instead of only logging.
- Keeps profile nickname persistence centralized in `UserManager`.
- Keeps the profile root screen visually aligned with the floating tabbar by reserving bottom safe space.

## Fix Applied

`ProfileSettingsViewController` and `ProfileLegalViewController` now set `hidesBottomBarWhenPushed = true` during initialization. This matches `WarmTabBarController`'s pushed-page visibility contract and prevents the custom floating tabbar from remaining visible on profile second-level pages.

## Public / Hidden Boundary

Public by default:

- `心境追踪`
- `个人资料设置`
- `法律法规`
- `退出登录`

Hidden or not public by default:

- `家人管理`
- `注销账户`
- `立即通话`
- password change
- full family space

## Guard Scripts

```text
tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift
tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift
tmp/visual-qa/prd-stitch-ui/profile-care-snapshot-check.swift
tmp/visual-qa/prd-stitch-ui/profile-settings-check.swift
tmp/visual-qa/prd-stitch-ui/profile-legal-center-check.swift
```

## QA Evidence

Latest QA report:

```text
tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/report.md
```

Latest screenshots:

```text
tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/01-profile-release-root.png
tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/02-profile-settings-hidden-tabbar.png
tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/03-profile-legal-hidden-tabbar.png
```

Passed:

- Group 4 profile/care guard.
- Profile release-gating guard.
- Profile care snapshot parsing/privacy guard.
- Profile care offline fallback guard.
- Profile settings guard.
- Profile legal center guard.
- iOS Debug simulator build.
- Archive-to-echo smoke script.
- Simulator profile root and pushed settings/legal smoke.

## Remaining Notes

- Real care dashboard backend data still needs an API environment; the current branch now has a safe `待同步` fallback for backend-unavailable states.
- Family management, account deletion, and doctor contact should stay hidden until product contracts, confirmation states, and safety copy are implemented.
