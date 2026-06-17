# Profile Legal Center QA

Date: 2026-06-17

Scope: make `法律法规` a real release-visible Profile flow.

## Rule

`法律法规` is low-risk and does not depend on backend state, so it is promoted to a default release feature. Other unfinished Profile actions remain hidden by default.

## Verification

- Source gate check:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-legal-center-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

- Profile release-gating check:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

- Regular iOS simulator build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileLegalReal CODE_SIGNING_ALLOWED=NO build
```

- UIQA simulator build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileLegalUIQA CODE_SIGNING_ALLOWED=NO SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

## Release-Like Default

Launch args:

```text
DJSeedPendingArchiveAnalysis
```

Profile screenshot:

```text
tmp/visual-qa/prd-stitch-ui/profile-legal-center/20260617-current/01-profile-release-legal-row.jpg
```

Runtime snapshot confirmed:

- Visible actions: `个人资料设置`, `法律法规`, `退出登录`.
- Hidden actions: `家人管理`, `注销账户`, `立即通话`.

Legal center screenshot:

```text
tmp/visual-qa/prd-stitch-ui/profile-legal-center/20260617-current/02-profile-legal-center.jpg
```

Runtime snapshot confirmed the page includes:

- `AI 辅助说明`
- `心理支持边界`
- `隐私与数据`
- `数字人与伦理`
- `紧急情况`
- `不是医疗诊断`
- `不展示聊天原文`
