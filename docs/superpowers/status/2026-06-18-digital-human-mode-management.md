# Digital Human Mode Management

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Goal

Close the next hidden PRD slice for `阳光 / 星辰 / 静默` digital-human mode management without exposing unfinished family-management UI in the public release surface.

## Implemented

- `FamilyMember` now stores `digitalHumanMode`, defaulting old and new records to `.sunlight`.
- `FamilyRepository` persists per-member mode overrides in `UserDefaults` and reapplies them to seeded and KB-synced family members.
- Hidden family persona rows show a small mode label for QA visibility.
- Hidden long-press context menu on family rows can mark a member as `阳光`, `星辰`, or `静默`.
- Selecting a family persona now writes the member's stored mode into `DigitalHumanContextStore` instead of forcing every family member to `.star`.
- If the currently selected family persona's mode changes, the active digital-human context is updated immediately so profile care visibility reacts to the new mode.
- Follow-up lifecycle effects are documented in `2026-06-18-digital-human-mode-lifecycle.md`.

## Release Boundary

- Public profile surface still does not expose family management by default.
- `家人管理` remains behind `familyManagement` / `familySpace` flags or explicit UIQA hidden-branch launch arguments.
- `心境追踪` remains limited to star-mode family personas through the existing profile visibility helper.
- Echo visible copy does not expose internal lifecycle mode names.
- This slice does not implement public lifecycle policy, inheritance confirmation, account deletion, or doctor escalation.

## Verification

```bash
swift Scripts/QA/prd-stitch-ui/digital-human-mode-management-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

iOS Debug simulator build remains required before committing this slice.
