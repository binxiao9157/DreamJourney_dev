# Profile Settings QA

Date: 2026-06-17

Scope: make `个人资料设置` a real release-visible Profile flow.

## Rule

`个人资料设置` is promoted to the default release surface with a narrow MVP scope:

- Show current avatar as a read-only system symbol.
- Allow nickname editing through `UserManager.updateProfile(nickname:)`.
- Show masked phone as read-only account context.
- Keep password and higher-risk account actions hidden until implemented.

## Verification

- Source check:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-settings-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

- Profile release-gating check:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

- Regular iOS simulator build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileSettingsReal CODE_SIGNING_ALLOWED=NO build
```

- UIQA simulator build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileSettingsUIQA CODE_SIGNING_ALLOWED=NO SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

## Release-Like Default

Launch args:

```text
DJSeedPendingArchiveAnalysis
```

Profile screenshot:

```text
tmp/visual-qa/prd-stitch-ui/profile-settings/20260617-current/01-profile-release-settings-row.jpg
```

Runtime snapshot confirmed:

- Visible actions: `个人资料设置`, `法律法规`, `退出登录`.
- Hidden actions: `家人管理`, `注销账户`, `立即通话`.

Settings screenshot:

```text
tmp/visual-qa/prd-stitch-ui/profile-settings/20260617-current/02-profile-settings-page.jpg
```

Runtime snapshot confirmed the page includes:

- `头像`
- `昵称`
- `手机号`
- `保存`

Manual smoke:

- Edited nickname in the simulator.
- Tapped `保存`.
- Confirmed success alert text `已保存 / 个人资料已更新。`
