# Digital Human Mode Lifecycle Effects

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Goal

Connect the hidden `阳光 / 星辰 / 静默` digital-human modes to Echo and Profile behavior without exposing internal mode names on the public Echo surface.

## Implemented

- Echo archive context status now carries the selected digital-human mode.
- Echo hides the archive-context indicator when the selected persona is in silent/non-public mode.
- Echo uses care-oriented visible copy for star-mode context without showing the internal mode name.
- Dialog prompt now appends a selected-mode policy:
  - ordinary companionship for sunlight,
  - psychological-care safety boundaries for star,
  - non-public display and archive-context suppression for silent.
- Dialog prompt no longer appends archive material, historical conversation memory, or KBLite person/family context when the selected persona is silent.
- Dialog opening greeting no longer uses historical memory or KBLite hints when the selected persona is silent.
- Profile persona subtitle now shows a non-public display boundary for silent family personas.
- Profile persona status dot now reflects selected lifecycle state while keeping default public profile behavior unchanged.

## Release Boundary

- Family mode management remains hidden behind family/Profile QA gates.
- Echo visible copy does not expose internal `星辰` or `静默` mode names.
- Star-mode guidance remains explicitly non-diagnostic and does not replace professional care.
- Silent mode suppresses archive, memory, and KBLite context exposure but does not implement legal inheritance or public lifecycle policy.

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swiftc -parse-as-library tmp/visual-qa/prd-stitch-ui/echo-archive-context-status-check.swift DreamJourney/Sources/Modules/Echo/EchoViewModel.swift -o /tmp/echo-archive-context-status-check && /tmp/echo-archive-context-status-check
swift tmp/visual-qa/prd-stitch-ui/echo-archive-context-indicator-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/dialog-archive-context-integration-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle/20260618-current/DerivedDataFinal CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle/20260618-current/DerivedDataFinalArm64 CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
git diff --check
```

Focused simulator smoke evidence:

- `tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle/20260618-current/01-profile-silent-boundary.jpg`
- `tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle/20260618-current/02-profile-silent-boundary-final.jpg`

Build log:

- `tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle-build-final.log`
- `tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle-build-final-arm64.log`
