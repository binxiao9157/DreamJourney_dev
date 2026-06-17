# Profile Release Gating QA

Date: 2026-06-17

Scope: `我的` / `长辈关怀` profile surface, release-like visibility of unfinished setting flows.

## Source Of Truth

- Visual target: current Stitch canvas and `tmp/stitch/profile.html`.
- Product target: latest PRD section `5.3 设置管理` and `5.4 长辈关怀`.
- Release rule: unfinished secondary flows can remain compiled, but should not be visible by default.

## Checks

- Source gate check:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

- Regular iOS simulator build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileReleaseReal CODE_SIGNING_ALLOWED=NO build
```

- UIQA simulator build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileReleaseUIQA CODE_SIGNING_ALLOWED=NO SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

## Release-Like Default

Launch args:

```text
DJSeedPendingArchiveAnalysis
```

Screenshot:

```text
tmp/visual-qa/prd-stitch-ui/profile-release-gating/20260617-current/01-profile-release-default.jpg
```

Runtime snapshot confirmed:

- Visible: `外面世界很美好`, `心境追踪`, `李医生`, `个人资料设置`, `法律法规`, `退出登录`, tab labels.
- Hidden: `立即通话`.
- Hidden: `家人管理`, `注销账户`.

## Stitch / Internal QA Alignment

Launch args:

```text
DJSeedPendingArchiveAnalysis DJEnableProfileHiddenBranches
```

Screenshot:

```text
tmp/visual-qa/prd-stitch-ui/profile-release-gating/20260617-current/02-profile-stitch-qa-hidden-branches.jpg
```

Runtime snapshot confirmed the Stitch settings list is still available for internal visual QA:

- `个人资料设置`
- `家人管理`
- `法律法规`
- `退出登录`
- `注销账户`

## Result

Profile secondary flows are now release-gated. The default app surface keeps the PRD care card and stable logout action, while Stitch's full settings list can still be reviewed with the explicit `DJEnableProfileHiddenBranches` UIQA argument.

`法律法规` has been promoted to a real release-visible flow:

- Profile screenshot with legal row: `tmp/visual-qa/prd-stitch-ui/profile-legal-center/20260617-current/01-profile-release-legal-row.jpg`
- Legal center screenshot: `tmp/visual-qa/prd-stitch-ui/profile-legal-center/20260617-current/02-profile-legal-center.jpg`

`个人资料设置` has been promoted to a narrow real release-visible flow:

- Profile screenshot with settings row: `tmp/visual-qa/prd-stitch-ui/profile-settings/20260617-current/01-profile-release-settings-row.jpg`
- Settings page screenshot: `tmp/visual-qa/prd-stitch-ui/profile-settings/20260617-current/02-profile-settings-page.jpg`

The care card contact action has also been release-gated:

- Default screenshot without call action: `tmp/visual-qa/prd-stitch-ui/profile-release-gating/20260617-care-contact/01-profile-release-no-call.jpg`
- Stitch/internal QA screenshot with call action: `tmp/visual-qa/prd-stitch-ui/profile-release-gating/20260617-care-contact/02-profile-stitch-qa-call.jpg`
