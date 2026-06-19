# DreamJourney Release Feature Matrix

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Source of truth:

- Visual target: current Stitch canvas, then `htmlCode`.
- Product target: updated `《寻梦环游 产品PRD V1.0》(1).md`.
- Code target: current UIKit implementation in `DreamJourney_dev`.
- MCP screenshots are auxiliary evidence only.

## Default Public Surface

These items are available without hidden-branch launch arguments and without manual feature-flag mutation.

| Area | Public in MVP | Code guard / evidence |
| --- | --- | --- |
| App shell | `记忆档案`, `回响`, `我的` | `TabCoordinator` builds the 3-tab PRD shell. |
| Login | Stitch-aligned light login form | `LoginViewController` keeps existing auth callback behavior. |
| Archive overview | `记忆档案馆`, `相册影像`, `语音档案`, `人格设定`, `封存新记忆`, timeline list | `MemoryArchiveViewController` renders the PRD archive home. Feature cards are category/capability entries; `封存新记忆` remains the creation entry. |
| Archive creation | Text and photo only: `添加文字描述`, `选择照片` | `MemoryArchiveCreationOption.availableOptions` always starts with `.text`, `.photo`. |
| Archive persona | `人格设定` opens the persona/knowledge settings surface | `DJFeature.personaSettings` is enabled by default. |
| Echo | Voice-first interaction: `开始语音` | `EchoViewController` exposes mic interaction, not text/image input controls. |
| Profile care | Persona card, `心境追踪`, aggregate `长辈关怀` child dashboard, loading/empty/stale/failed care states, non-executing `关怀升级准备中` placeholder, doctor identity row without call action | `DJFeature.careDashboard` is enabled by default; `careDoctorContact` is not. |
| Profile settings | `个人资料设置`, `法律法规`, `退出登录` | `DJFeature.profileSettings` and `DJFeature.legalCenter` are enabled by default; logout is always appended. |
| Profile settings page | Avatar display, name/gender/region editing, masked phone, inline save states, local profile persistence, backend-ready sync fallback | `ProfileSettingsViewController`; `profile-settings-save-state-check.swift`, `profile-account-fields-check.swift`. |
| Legal center | AI assistance, psychological boundary, privacy/data, ethics, emergency guidance | `ProfileLegalViewController`. |

Default enabled feature flags must remain exactly:

```text
careDashboard
personaSettings
profileSettings
legalCenter
```

## Hidden By Default

These items must not appear in the public release surface yet.

| Area | Hidden item | Current access policy |
| --- | --- | --- |
| Echo | Text input | `DJFeature.echoTextInput`; no public control. |
| Echo | Image input | `DJFeature.echoImageInput`; no public control. |
| Archive | Audio upload / `录入语音` | `DJFeature.archiveAudioUpload` or `DJEnableArchiveHiddenBranches` only. |
| Archive | Video upload / `录入视频片段` | `DJFeature.archiveVideoUpload` or `DJEnableArchiveHiddenBranches` shell only. |
| Archive | Time-letter creation / `录入时间信件` | `DJFeature.timeLetters` or `DJEnableArchiveHiddenBranches` only. |
| Archive backend | Remote archive fetch | `DJFeature.archiveRemoteFetch` only; default public app stays local-first. |
| Archive detail | Local analysis debug controls | `DJFeature.archiveLocalAnalysis`, debug/UIQA only. |
| Profile | `家人管理` | `DJFeature.familyManagement` or `DJEnableProfileHiddenBranches` only. |
| Profile | Hidden family persona switcher | `DJFeature.familySpace` or `DJEnableProfileHiddenBranches` for QA only; switches self/family `DigitalHumanContext`, still not public family management. |
| Profile / Echo | Hidden `阳光 / 星辰 / 静默` mode management | Hidden family rows expose a QA context menu only; mode is persisted locally, drives care visibility, changes Echo context/prompt boundaries, and keeps internal mode names out of visible Echo copy. |
| Profile | `注销账户` | `DJFeature.accountDeletion` or `DJEnableProfileHiddenBranches` only. |
| Profile settings | `修改密码` | `DJFeature.accountPasswordChange` or `DJEnableProfileHiddenBranches` only. |
| Profile | `声音克隆` | `DJFeature.voiceCloneShell` or `DJEnableProfileHiddenBranches` safety shell only. |
| Profile care | `立即通话` | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` only. |

## Hidden Candidate Release Decisions

No hidden PRD feature is public by default. These candidates may be available in QA-only branches or as safety shells, but they are not part of the default public MVP until the promotion criteria below are met.

| Feature | Current gate | Public in MVP | Needed before public | Test evidence |
| --- | --- | --- | --- | --- |
| archive audio upload | `DJFeature.archiveAudioUpload` or `DJEnableArchiveHiddenBranches` | no | true-device recording acceptance, storage/privacy copy, backend media policy | `archive-media-entries-smoke-check.swift`, release regression |
| time letters | `DJFeature.timeLetters` or `DJEnableArchiveHiddenBranches` | no | delivery/scheduling policy, reminder semantics, true-device notification decision | `archive-media-entries-smoke-check.swift`, release regression |
| video upload | `DJFeature.archiveVideoUpload` or `DJEnableArchiveHiddenBranches` shell only | no | PRD scope, picker/compression/storage/backend policy, true-device video picker acceptance | `archive-media-entries-smoke-check.swift`, `archive-media-release-readiness-check.swift`, release regression |
| family management public release | `DJFeature.familyManagement` or `DJEnableProfileHiddenBranches` | no | invitation/permission model, backend membership contract, privacy copy | `profile-family-persona-switcher-check.swift` |
| care dashboard expansion | aggregate `DJFeature.careDashboard` and non-executing `关怀升级准备中` placeholder are public; intervention/contact execution stays behind `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` | aggregate + placeholder only | family-facing copy, alert thresholds, backend persistence, true-device acceptance | `elder-care-dashboard-check.swift`, `profile-care-public-placeholder-check.swift`, backend acceptance |
| account deletion execution | `DJFeature.accountDeletion` or `DJEnableProfileHiddenBranches` safety shell only | no | compliance policy, cooling-off period, backend deletion/export contract | `profile-safety-flow-check.swift` |
| account password change | `DJFeature.accountPasswordChange` or `DJEnableProfileHiddenBranches` | no | backend `/auth/password` implementation, auth/security review, true-device acceptance | `profile-password-change-check.swift`, release regression |
| voice clone shell | `DJFeature.voiceCloneShell` or `DJEnableProfileHiddenBranches` | no | explicit authorization, voice sample quality policy, voiceProfileId lifecycle, deletion/disable backend contract, compliance review | `voice-clone-shell-contract-check.swift`, release regression |
| doctor contact / intervention execution | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` | no | real escalation provider, emergency disclaimers, backend submission contract | `profile-care-escalation-contract-check.swift`, `profile-care-escalation-backend-boundary-check.swift` |
| care escalation draft | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` local draft shell only | no | product decision to promote draft, backend submit contract, clinical/legal review | `profile-care-escalation-contract-check.swift`, `run-profile-care-escalation-boundary-smoke.sh` |
| sunlight/star/silent lifecycle transition controls | hidden family rows / local QA context only | no | product/legal policy for lifecycle transitions, consent copy, recovery rules | `digital-human-mode-management-check.swift`, `digital-human-mode-lifecycle-check.swift` |
| digital inheritance lifecycle | hidden lifecycle boundary only | no | inheritance trigger policy, family/legal consent, backend audit contract | `digital-human-mode-lifecycle-check.swift`, PRD coverage matrix |

## Hidden Safety Shells

These flows have hidden safety shells only. They are not public release features.

| Area | Safety boundary | Evidence |
| --- | --- | --- |
| 账号注销 | Hidden destructive confirmation shell only; it does not execute deletion until compliance, data export, cooling-off, and final confirmation are defined. | `ProfileViewController.showAccountDeletionConfirmation`, `profile-safety-flow-check.swift`. |
| 医生联系 / 关怀升级 | Public dashboard shows only a non-executing `关怀升级准备中` placeholder: no phone call, no message, no upload. Hidden doctor contact still renders a local `关怀升级草稿`; it is non-emergency, not medical diagnosis, does not call, does not upload, and the real contact contract is not connected. A backend candidate payload exists only as `draftOnly` contract evidence and is not submitted anywhere. | `ProfileElderCareDashboardViewController.makeEscalationPlaceholderCard`, `ProfileViewController.showDoctorContactSafetyNotice`, `profile-safety-flow-check.swift`, `profile-care-public-placeholder-check.swift`, `profile-care-escalation-contract-check.swift`, `profile-care-escalation-backend-boundary-check.swift`, `run-profile-care-escalation-boundary-smoke.sh`. |

## Internal QA Launch Arguments

Hidden UI branches may be exposed for visual or interaction QA only with explicit launch arguments:

```text
DJEnableArchiveHiddenBranches
DJEnableProfileHiddenBranches
```

These launch arguments must not be required for the default public smoke path.

## Release Regression Commands

Run these after changes to tabs, archive creation, profile rows, feature flags, or release gating:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-mode-management-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/elder-care-dashboard-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-care-public-placeholder-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/voice-clone-shell-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Run the full core loop smoke after changes touching archive-to-echo behavior:

```bash
tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
```

Expected result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

## Promotion Criteria

Hidden features can be moved into the public matrix only after all of the following are true:

1. The PRD explicitly includes the feature in the release scope.
2. The UI is aligned with the current Stitch canvas and `htmlCode`.
3. The user action has a real implemented flow, not only a placeholder alert.
4. Risky flows have copy and confirmation states, especially account deletion, family access, emergency guidance, and doctor contact.
5. A static check or simulator smoke protects the newly visible path.
