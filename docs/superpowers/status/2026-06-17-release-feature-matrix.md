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
| Archive overview | `记忆档案馆`, `相册影像`, `封存新记忆`, timeline list | `MemoryArchiveViewController` renders the archive home. |
| Archive creation | Text and photo only: `添加文字描述`, `选择照片` | `MemoryArchiveCreationOption.availableOptions` always starts with `.text`, `.photo`. |
| Echo | Voice-first interaction: `开始语音` | `EchoViewController` exposes mic interaction, not text/image input controls. |
| Profile care | Persona card, `心境追踪`, aggregate `长辈关怀` child dashboard, doctor identity row without call action | `DJFeature.careDashboard` is enabled by default; `careDoctorContact` is not. |
| Profile settings | `个人资料设置`, `法律法规`, `退出登录` | `DJFeature.profileSettings` and `DJFeature.legalCenter` are enabled by default; logout is always appended. |
| Profile settings page | Avatar display, nickname editing, masked phone, save confirmation | `ProfileSettingsViewController`. |
| Legal center | AI assistance, psychological boundary, privacy/data, ethics, emergency guidance | `ProfileLegalViewController`. |

Default enabled feature flags must remain exactly:

```text
careDashboard
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
| Archive | Time-letter creation / `录入时间信件` | `DJFeature.timeLetters` or `DJEnableArchiveHiddenBranches` only. |
| Archive | Persona settings / `人格设定` | `DJFeature.personaSettings` or `DJEnableArchiveHiddenBranches` only. |
| Archive backend | Remote archive fetch | `DJFeature.archiveRemoteFetch` only; default public app stays local-first. |
| Archive detail | Local analysis debug controls | `DJFeature.archiveLocalAnalysis`, debug/UIQA only. |
| Profile | `家人管理` | `DJFeature.familyManagement` or `DJEnableProfileHiddenBranches` only. |
| Profile | Hidden family persona switcher | `DJFeature.familySpace` or `DJEnableProfileHiddenBranches` for QA only; switches self/family `DigitalHumanContext`, still not public family management. |
| Profile / Echo | Hidden `阳光 / 星辰 / 静默` mode management | Hidden family rows expose a QA context menu only; mode is persisted locally, drives care visibility, changes Echo context/prompt boundaries, and keeps internal mode names out of visible Echo copy. |
| Profile | `注销账户` | `DJFeature.accountDeletion` or `DJEnableProfileHiddenBranches` only. |
| Profile care | `立即通话` | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` only. |
| Profile settings | Password change | Not exposed until an implemented credential flow exists. |

## Hidden Safety Shells

These flows have hidden safety shells only. They are not public release features.

| Area | Safety boundary | Evidence |
| --- | --- | --- |
| 账号注销 | Hidden destructive confirmation shell only; it does not execute deletion until compliance, data export, cooling-off, and final confirmation are defined. | `ProfileViewController.showAccountDeletionConfirmation`, `profile-safety-flow-check.swift`. |
| 医生联系 | Hidden safety notice only; it is non-emergency, not medical diagnosis, and the real contact contract is not connected. | `ProfileViewController.showDoctorContactSafetyNotice`, `profile-safety-flow-check.swift`. |

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
swift tmp/visual-qa/prd-stitch-ui/elder-care-dashboard-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
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
