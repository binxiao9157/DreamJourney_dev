# DreamJourney Release Feature Matrix

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Last synced: 2026-06-21, after the product decision to expose family phone invitation and account soft deletion while keeping high-risk media, password change, advanced family lifecycle, and intervention flows hidden.

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
| Archive creation | Text, photo, and time letter: `添加文字描述`, `选择照片`, `录入时间信件` | `MemoryArchiveCreationOption.availableOptions` starts with `.text`, `.photo` and adds `.timeLetter` when default `DJFeature.timeLetters` is enabled. |
| Archive persona | `人格设定` opens the persona/knowledge settings surface | `DJFeature.personaSettings` is enabled by default. |
| Echo | Voice-first interaction: `开始语音` | `EchoViewController` exposes mic interaction, not text/image input controls. `VoiceSDKReadinessSummary` keeps mock ASR/TTS, backend token fallback, and production SDK readiness separate. |
| Profile care | Persona card, `心境追踪`, aggregate `长辈关怀` child dashboard, loading/empty/stale/failed care states, non-executing `关怀升级准备中` placeholder, doctor identity row without call action | `DJFeature.careDashboard` is enabled by default; `careDoctorContact` is not. |
| Profile settings | `个人资料设置`, `家人管理`, `音色复刻`, `法律法规`, `退出登录`, `注销账户` | `DJFeature.profileSettings`, `DJFeature.familyManagement`, `DJFeature.familySpace`, `DJFeature.voiceCloneShell`, `DJFeature.legalCenter`, and `DJFeature.accountDeletion` are enabled by default; logout is always appended. |
| Family management | 手机号邀请家人；邀请中、已加入、失败状态；不提供删除家人操作 | `FamilyCircleViewController`, `FamilyRepository.inviteByPhone`, `/family/invite`, `/family/members/{user}/{member}/revoke` returns 409. |
| Account deletion | 二次确认；不支持数据导出；数据保留 30 天；30 天内同手机号可恢复 1 次；超期清理合同 | `ProfileViewController.showAccountDeletionConfirmation`, `DreamJourneyBackendClient.softDeleteAccount`, `/auth/delete`, `/auth/restore`, `/auth/purge-expired-deletions`. |
| Profile settings page | Avatar display, name/gender/region editing, masked phone, inline save states, local profile persistence, backend-ready sync fallback | `ProfileSettingsViewController`; `profile-settings-save-state-check.swift`, `profile-account-fields-check.swift`. |
| Profile voice clone | `音色复刻` public foundation: authorization, audio sample submission, backend training/status refresh, disable/delete contract | `ProfileVoiceCloneShellViewController`, `VoiceCloneService`, `/voice/profiles`; `voice-clone-shell-contract-check.swift`, `voice-clone-backend-contract-check.swift`. |
| Legal center | AI assistance, psychological boundary, privacy/data, ethics, emergency guidance | `ProfileLegalViewController`. |

Default enabled feature flags must remain exactly:

```text
careDashboard
accountDeletion
familyManagement
familySpace
personaSettings
profileSettings
timeLetters
legalCenter
voiceCloneShell
```

## Hidden By Default

These items must not appear in the public release surface yet.

| Area | Hidden item | Current access policy |
| --- | --- | --- |
| Echo | Text input | `DJFeature.echoTextInput`; no public control. |
| Echo | Image input | `DJFeature.echoImageInput`; no public control. |
| Echo / QA | Voice SDK readiness preview | `DJShowVoiceSDKReadinessPreview` only; hidden UIQA shows readiness boundary and must not appear in public release. |
| Archive | Audio upload / `录入语音` | `DJFeature.archiveAudioUpload` or `DJEnableArchiveHiddenBranches` only. |
| Archive | Video upload / `录入视频片段` | `DJFeature.archiveVideoUpload` or `DJEnableArchiveHiddenBranches` mock-file shell only. |
| Archive backend | Remote archive fetch | `DJFeature.archiveRemoteFetch` only; default public app stays local-first. |
| Archive detail | Local analysis debug controls | `DJFeature.archiveLocalAnalysis`, debug/UIQA only. |
| Profile / Echo | Hidden `阳光 / 星辰 / 静默` mode management | Hidden family rows expose a QA context menu only; mode is persisted locally, drives care visibility, changes Echo context/prompt boundaries, and keeps internal mode names out of visible Echo copy. |
| Backend / Profile | Hidden family digital-human backend contract | `family-digital-human-hidden-contract-check.swift` guards mock persistence for `personaScope`, `digitalHumanId`, and `阳光 / 星辰 / 静默` without exposing public family management. |
| Backend / Profile | Deployed family + voice contract smoke | `backend-family-voice-contract-smoke-check.swift` guards the deployed `family digital-human` three-state contract and `voice profile lifecycle`; run with `RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE=1` after backend redeploy. |
| iOS / Profile | Family + voice deployed contract consumer | `ios-family-voice-consumer-contract-check.swift` guards typed iOS parsing for `digitalHumanMode`, `familyPersonaContractVersion`, and backend `voiceProfileId/sampleStatus` snapshots. |
| iOS / Profile UIQA | Hidden family + voice UIQA consumer | `ios-family-voice-hidden-uiqa-smoke-check.swift` remains historical QA evidence for backend-derived family/voice fields; the voice clone entry is now public. |
| Profile settings | `修改密码` | `DJFeature.accountPasswordChange` or `DJEnableProfileHiddenBranches` only. |
| Profile care | `立即通话` | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` only. |

## 2026-06-19 Completed Hidden/Acceptance Guards

These are now implemented as guarded contracts or QA evidence packages. They do not expand the default public release surface:

- Hidden Family / Voice UIQA Consumer Gate: backend-derived `digitalHumanMode`, `familyPersonaContractVersion`, `voiceProfileId`, and `sampleStatus` are parsed and consumed in hidden QA.
- 时间信件公开投递闭环: draft/sealed time letters persist `openAt` / `recipients` / `sealedAt` / `deliveryStatus`; sealed letters reject deletion and schedule local + in-app reminders.
- 视频档案 Hidden Readiness: mock video cards/details show thumbnail placeholder, file size, upload status, failed/retry analysis state, and runtime media capability.
- 真机验收包强化: true-device voice and archive-audio preflight scripts now generate evidence manifests, screenshot names, logs, and manual QA notes.
- 生产语音 SDK readiness 边界: mock ASR/TTS, backend token fallback, production SDK needs true-device QA, and future verified state are explicitly separated.

## Hidden Candidate Release Decisions

No remaining hidden PRD feature is public by default. Family phone invitation, time-letter foundation, voice-clone foundation, and account soft deletion are no longer hidden candidates after the latest PRD clarification. The candidates below may be available in QA-only branches or as safety shells, but they are not part of the default public MVP until the promotion criteria are met.

| Feature | Current gate | Public in MVP | Needed before public | Test evidence |
| --- | --- | --- | --- | --- |
| archive audio upload | `DJFeature.archiveAudioUpload` or `DJEnableArchiveHiddenBranches` | no | true-device recording acceptance, storage/privacy copy, backend media policy | `archive-audio-lifecycle-smoke-check.swift`, `archive-audio-ia-release-check.swift`, `true-device-archive-audio-acceptance-check.swift`, `true-device-acceptance-evidence-package-check.swift`, release regression |
| video upload | `DJFeature.archiveVideoUpload` or `DJEnableArchiveHiddenBranches` mock-file shell only | no | PRD public scope, real picker/compression/storage/backend provider policy, true-device video picker acceptance | `archive-video-hidden-readiness-check.swift`, `archive-hidden-media-detail-ui-check.swift`, `archive-hidden-media-combo-gate-check.swift`, `archive-media-upload-intent-contract-check.swift`, `archive-media-provider-switch-contract-check.swift`, release regression |
| family advanced lifecycle controls | base phone invite is public; hidden family rows / local QA context only cover advanced lifecycle | no | product/legal policy for exit/unlink/lifecycle transitions, consent copy, recovery rules | `digital-human-mode-management-check.swift`, `digital-human-mode-lifecycle-check.swift` |
| care dashboard expansion | aggregate `DJFeature.careDashboard` and non-executing `关怀升级准备中` placeholder are public; intervention/contact execution stays behind `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` | aggregate + placeholder only | family-facing copy, alert thresholds, backend persistence, true-device acceptance | `elder-care-dashboard-check.swift`, `profile-care-public-placeholder-check.swift`, backend acceptance |
| account password change | `DJFeature.accountPasswordChange` or `DJEnableProfileHiddenBranches` | no | backend `/auth/password` implementation, auth/security review, true-device acceptance | `profile-password-change-check.swift`, release regression |
| doctor contact / intervention execution | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` | no | real escalation provider, emergency disclaimers, backend submission contract | `profile-care-escalation-contract-check.swift`, `profile-care-escalation-backend-boundary-check.swift` |
| care escalation draft | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` local draft shell only | no | product decision to promote draft, backend submit contract, clinical/legal review | `profile-care-escalation-contract-check.swift`, `run-profile-care-escalation-boundary-smoke.sh` |
| digital inheritance lifecycle | hidden lifecycle boundary only | no | inheritance trigger policy, family/legal consent, backend audit contract | `digital-human-mode-lifecycle-check.swift`, PRD coverage matrix |

## Risky Public Contracts

These flows are public only after the latest PRD made their safety policy explicit. They still require backend deployment and release regression evidence before production handoff.

| Area | Safety boundary | Evidence |
| --- | --- | --- |
| 账号注销 | Public soft-delete contract only: two confirmations, no data export, 30-day retention, same-phone restore once, irreversible purge contract after deadline. | `ProfileViewController.showAccountDeletionConfirmation`, `DreamJourneyBackendClient.softDeleteAccount`, backend `AccountDeletionAPITests`, `profile-family-account-lifecycle-check.swift`, `backend-family-account-lifecycle-smoke.py`. |
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
swift tmp/visual-qa/prd-stitch-ui/profile-family-account-lifecycle-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-mode-management-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-care-escalation-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/elder-care-dashboard-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-care-public-placeholder-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/voice-clone-shell-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/voice-clone-backend-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/voice-sdk-readiness-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/ios-family-voice-consumer-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/ios-family-voice-hidden-uiqa-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/time-letter-delivery-policy-shell-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/archive-video-hidden-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/true-device-acceptance-evidence-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

After backend deployment, run the optional deployed family/account lifecycle gate:

```bash
RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE=1 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
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

## Remaining Gates By Type

Public MVP gates:

- True-device Echo voice, photo archive, foreground/background, playback route, screenshots, and logs.
- Production voice SDK ASR/TTS quality and recovery evidence.
- Final Stitch visual QA after each design update.

Hidden gates:

- Audio/video real media behavior and delivery rules.
- Family exit/unlink/advanced lifecycle controls and permission recovery rules.

External gates:

- APNs provider delivery and true-device notification arrival.
- Paid Apple Developer Team capability if push is promoted.
- Real object-storage provider for media upload.
- Production voice clone provider quality acceptance and real trained-voice synthesis evidence.

Product/compliance gates:

- Account deletion production legal review, purge scheduling operations, and restore support process.
- Doctor contact or intervention execution.
- Voice clone authorization copy, sample quality policy, and consent audit review.
- Digital inheritance and lifecycle transitions.
