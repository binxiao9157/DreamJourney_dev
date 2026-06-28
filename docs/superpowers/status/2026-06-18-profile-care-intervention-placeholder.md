# Profile Care Intervention Placeholder

Date: 2026-06-18

## Scope

This pass promotes a public MVP placeholder for care escalation inside `我的 -> 长辈关怀`.

The placeholder is informational only:

- title: `关怀升级准备中`
- body: `当前仅提供聚合信号与趋势解释，不会拨打电话或发送消息。`

## Product Boundary

The public MVP may show aggregate care signals, trend explanation, data-state copy, risk reminders, privacy boundaries, and this non-executing placeholder.

The public MVP must not:

- dial a doctor or third party
- send messages
- upload escalation drafts
- submit intervention payloads to the backend
- claim medical diagnosis or emergency support

## Hidden Branch Boundary

`DJFeature.careDoctorContact` and `DJEnableProfileHiddenBranches` still gate the hidden local `关怀升级草稿` safety shell.

That shell remains draft-only and non-executing until product, clinical/legal, and backend contracts are explicit.

## Verification

```bash
swift Scripts/QA/prd-stitch-ui/profile-care-public-placeholder-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```
