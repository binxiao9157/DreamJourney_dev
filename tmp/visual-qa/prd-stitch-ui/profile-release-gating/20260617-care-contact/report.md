# Profile Care Contact Gating QA

Date: 2026-06-17

Scope: `我的` / `心境追踪` doctor contact action.

## Rule

`立即通话` is not a complete release flow yet, so it must not appear in the default release-like surface. It remains available for Stitch/internal visual QA through `DJEnableProfileHiddenBranches`, and can later be promoted with `DJFeature.careDoctorContact` after a real contact flow exists.

## Verification

- Source gate check:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

- Regular iOS simulator build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileCareContactReal CODE_SIGNING_ALLOWED=NO build
```

- UIQA simulator build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileCareContactUIQA CODE_SIGNING_ALLOWED=NO SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

## Release-Like Default

Launch args:

```text
DJSeedPendingArchiveAnalysis
```

Screenshot:

```text
tmp/visual-qa/prd-stitch-ui/profile-release-gating/20260617-care-contact/01-profile-release-no-call.jpg
```

Runtime snapshot confirmed `李医生` remains visible and `立即通话` is absent.

## Stitch / Internal QA Alignment

Launch args:

```text
DJSeedPendingArchiveAnalysis DJEnableProfileHiddenBranches
```

Screenshot:

```text
tmp/visual-qa/prd-stitch-ui/profile-release-gating/20260617-care-contact/02-profile-stitch-qa-call.jpg
```

Runtime snapshot confirmed `立即通话` is visible with the full Stitch settings list.
