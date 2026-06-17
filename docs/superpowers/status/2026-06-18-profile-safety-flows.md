# Profile Safety Flows

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Scope

This slice adds safety shells for hidden profile risk flows and makes care dashboard visibility explicit.

## What Changed

- `ProfileViewController.shouldShowCareDashboard(context:)` now centralizes care dashboard visibility.
- `careDashboard` feature flag is still required.
- Default self assistant still shows `心境追踪`, preserving the current Stitch/profile surface.
- Non-self family persona shows `心境追踪` only when `context.mode == .star`.
- Hidden `注销账户` now opens `showAccountDeletionConfirmation()`.
- Hidden `立即通话` now opens `showDoctorContactSafetyNotice()`.

## Release Boundary

Default release flags remain:

```text
careDashboard
profileSettings
legalCenter
```

Still hidden by default:

- `accountDeletion`
- `careDoctorContact`
- `familyManagement`
- `familySpace`

## Account Deletion Boundary

The account deletion shell is intentionally non-executing:

- It shows a destructive confirmation shell.
- It explains the current version will not delete data.
- It says full compliance flow is required.
- The destructive action is disabled.
- It does not call logout, local data deletion, or backend deletion.

## Doctor Contact Boundary

The doctor contact shell is intentionally non-executing:

- It says the feature is non-emergency.
- It says the app is not medical diagnosis.
- It points emergency cases to local emergency services.
- It says the real contact contract is not connected.
- It does not launch a phone call.

## Verification

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```
