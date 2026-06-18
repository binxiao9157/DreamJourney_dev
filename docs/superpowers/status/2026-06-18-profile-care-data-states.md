# Profile Care Data States

Date: 2026-06-18

## Scope

This pass hardens the public `我的 -> 心境追踪 / 长辈关怀` aggregate dashboard without exposing hidden intervention features.

## Public States

The care dashboard now models and displays:

- `loading`: `正在同步关怀信号`
- `empty`: `暂无可用关怀信号`
- `stale`: `数据可能不是最新`
- `failed`: `关怀信号加载失败`

These states are public MVP states under the existing `careDashboard` surface. They do not enable `立即通话`, doctor contact, escalation submission, family management, or account deletion.

## Implementation Boundary

- `ProfileCareDataState` owns state copy and fallback semantics.
- `ProfileViewController` uses explicit loading, empty, failed, and stale snapshots.
- `ProfileElderCareDashboardViewController` renders a state card for non-available states.
- Raw chat transcript/message data remains out of the Profile/Care models and UI.

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-care-public-placeholder-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swiftc DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift tmp/visual-qa/prd-stitch-ui/profile-care-snapshot-check.swift -o /tmp/profile-care-snapshot-check
/tmp/profile-care-snapshot-check /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/elder-care-dashboard-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```
