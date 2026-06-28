# Profile Care Escalation Contract

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Goal

Move the hidden `立即通话` doctor-contact branch from plain placeholder copy to a structured, non-executing care-escalation draft.

## Implemented

- Added `ProfileCareEscalationDraft` as a local handoff model for hidden care escalation.
- The draft captures:
  - selected persona display name,
  - latest care risk summary,
  - non-emergency boundary,
  - non-diagnostic medical boundary,
  - explicit contract state saying real contact is not connected.
- Hidden doctor contact now renders the draft in the safety alert.
- The disabled action says `发送关怀升级草稿（未开放）`.
- The draft now exposes a backend candidate payload for future service design:
  - `schemaVersion = profileCareEscalationDraft.v1`
  - `deliveryState = draftOnly`
  - `requiresHumanReview = true`
  - `backendContractConnected = false`
  - `willContactThirdParty = false`
  - `allowsEmergencyUse = false`
  - `containsRawTranscript = false`
- UIQA can run `run-profile-care-escalation-boundary-smoke.sh` to write and validate this payload without a real backend.

## Release Boundary

- `立即通话` remains hidden behind `careDoctorContact` or `DJEnableProfileHiddenBranches`.
- The flow does not call `tel://`.
- The flow does not call `DreamJourneyBackendClient`.
- The flow does not upload or message a third party.
- It is not medical diagnosis and does not replace emergency services.
- The backend candidate payload is a contract boundary only; it is not submitted anywhere.

## Verification

```bash
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh
swift Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract/20260618-current/DerivedDataFinal CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract/20260618-current/DerivedDataFinalArm64 CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
git diff --check
```

Focused simulator smoke evidence:

- `tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract/20260618-current/01-care-escalation-draft-alert.jpg`
- `tmp/visual-qa/prd-stitch-ui/profile-care-escalation-boundary-smoke/20260618-current/profile-care-escalation-boundary-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/profile-care-escalation-boundary-smoke/20260618-current/01-profile-care-escalation-boundary.png`

Build logs:

- `tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract-build-final.log`
- `tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract-build-final-arm64.log`
