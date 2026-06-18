# PRD Full Feature Closure Decisions

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Purpose

This document turns the current PRD coverage and release feature matrix into a product-decision checklist for the full DreamJourney feature loop.

Goal:

```text
登录 / 注册 -> 记忆档案 -> 回响 -> 我的 / 心境追踪 / 长辈关怀 -> 家庭协作与安全闭环
```

The current app is already a simulator-validated MVP candidate for the core loop, but it is not yet a full PRD completion state. The remaining work splits into:

1. Public features that are already visible but not fully complete.
2. PRD features that exist only as hidden candidates or safety shells.
3. Product / PRD decisions that must be made before engineering should expose the feature.
4. External acceptance gates such as true-device, signing, microphone, photo library, and production voice quality.

## Source Of Truth

- Product: latest attached `《寻梦环游 产品PRD V1.0》(1).md`.
- Visual: current Stitch canvas and downloaded `htmlCode`.
- Code: current UIKit implementation in `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`.
- Release policy: `docs/superpowers/status/2026-06-17-release-feature-matrix.md`.
- Coverage policy: `docs/superpowers/status/2026-06-18-prd-coverage-matrix.md`.
- MCP screenshots are auxiliary evidence only.

## Current Public MVP Surface

These are visible by default and should continue toward full completion:

| Area | Current public state | Remaining gap |
| --- | --- | --- |
| App shell | `记忆档案`, `回响`, `我的` | Keep stable unless Stitch / PRD explicitly changes IA. |
| Login | Light Stitch-aligned login form | Final auth error handling, account recovery, production backend behavior. |
| Archive text/photo | `添加文字描述`, `选择照片`, timeline list | True-device photo permission, backend persistence, media privacy copy. |
| Echo voice | Voice-first `开始语音` flow | True-device microphone acceptance, production voice SDK quality, 2-3 round reply policy. |
| Profile settings | Avatar display, nickname edit, masked phone, save confirmation | Avatar edit/upload, password or account-security scope, backend persistence. |
| Legal center | AI, privacy, care, emergency, ethics copy | Legal review and product approval. |
| Mind / care dashboard | Aggregate `心境追踪` / `长辈关怀` signals | Thresholds, alert severity, backend source, family-facing privacy policy. |

## Public Features Still Not Fully Implemented

These are already public or should remain public for MVP, so they are the safest next engineering targets.

### 1. Echo 2-3 Round Waiting Reply

Current status: partially implemented.

Needs engineering:

- Define deterministic state transitions in `EchoViewModel`.
- Cover idle, listening, waiting, replied, and failure states.
- Add regression checks for the 2-3 round wait behavior.

Needs PRD decision:

- Whether "2-3 rounds" means user turns, assistant turns, or complete exchanges.
- Exact wait trigger: after the second round, after the third round, or adaptive.
- Expected wait duration and copy.
- Whether waiting reply requires push notification, local notification, or in-app-only state.
- Whether this feature is part of public MVP or a later emotional pacing layer.

### 2. Profile Settings Completion

Current status: partially implemented.

Needs engineering:

- Avatar edit/upload or keep avatar read-only.
- Persist nickname/avatar changes to backend when available.
- Decide whether phone number is editable, read-only, or managed by auth provider.
- Add validation and recovery states for failed save.

Needs PRD decision:

- Whether password change is required in-app for full PRD.
- Whether profile is personal-only or family/persona-aware.
- Whether avatar is user profile avatar, digital human avatar, or both.
- What fields are required for MVP versus full account center.

### 3. Archive Photo/Text Production Readiness

Current status: implemented, public.

Needs engineering:

- True-device photo library permission acceptance.
- Backend persistence verification for uploaded archive items.
- Error recovery for failed upload/sync.
- Privacy copy around family-visible media.

Needs PRD decision:

- Whether archive media is private by default or shareable with family.
- Retention and deletion policy for uploaded memory items.
- Whether media analysis is local-only, backend-assisted, or AI-assisted.

### 4. Mind Tracking / Elder Care Aggregate

Current status: implemented aggregate/fallback, public.

Needs engineering:

- Real backend persistence and retrieval for care metrics.
- Clear empty, loading, stale-data, and failed-data states.
- Regression for public aggregate visibility without exposing private chat content.

Needs PRD decision:

- Exact metric definitions: mood, cognition, sleep, loneliness, risk.
- Alert thresholds and severity labels.
- Family visibility rules.
- Whether children see only aggregate signals or also trend explanations.
- Whether doctor/intervention escalation belongs in the first full release.

## Hidden PRD Features That Need Product Decision Before Opening

These should not be exposed by default until the decision items are resolved.

| Feature | Current state | Current gate | PRD decision required before public |
| --- | --- | --- | --- |
| 语音档案 / archive audio upload | Hidden candidate, QA branch exists | `DJFeature.archiveAudioUpload` or `DJEnableArchiveHiddenBranches` | Is audio archive part of public full release? Recording length, transcription, storage, privacy, true-device mic acceptance. |
| 时间信件 | Hidden candidate, QA branch exists | `DJFeature.timeLetters` or `DJEnableArchiveHiddenBranches` | Delivery timing, edit/cancel rules, notification policy, recipient rules, failure/retry behavior. |
| 档案视频 | Not implemented | No implemented public gate yet | Whether video is in full PRD scope; size limits, compression, preview, backend storage, privacy. |
| 人格设定 | Hidden candidate | `DJFeature.personaSettings` or `DJEnableArchiveHiddenBranches` | Who can edit persona, what fields exist, AI safety boundaries, audit/revert behavior. |
| 家人管理 | Hidden candidate | `DJFeature.familyManagement` or `DJEnableProfileHiddenBranches` | Invite model, roles, permissions, consent, backend membership contract, family data visibility. |
| 账号注销执行 | Hidden safety shell only | `DJFeature.accountDeletion` or `DJEnableProfileHiddenBranches` | Compliance policy, data export, cooling-off period, final confirmation, backend deletion contract. |
| 医生联系 / 干预执行 | Hidden safety shell only | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` | Whether real provider/contact exists, emergency disclaimers, escalation ownership, backend submission. |
| 关怀升级草稿发送 | Local draft shell only | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` | Whether draft becomes sendable, who receives it, review/edit rules, clinical/legal wording. |
| 阳光 / 星辰 / 静默 生命周期切换 | Hidden local QA control | Hidden family rows / local context | Whether users can switch modes, who is authorized, recovery rules, visible copy. |
| 数字人继承生命周期 | Hidden boundary only | Lifecycle checks only | Trigger policy, death/inactivity proof, family/legal consent, audit trail, rollback policy. |
| Echo 文字 / 图片输入 | Not publicly wired | `DJFeature.echoTextInput`, `DJFeature.echoImageInput` | Whether Echo remains voice-first or becomes multimodal; UI impact and safety policy. |

## Full Feature Closure Phases

### Phase A: Public MVP Completion

Target: make the already-public experience complete enough for real testing.

Recommended order:

1. Echo 2-3 round waiting reply.
2. Profile settings completion.
3. Archive text/photo production readiness.
4. Care dashboard aggregate backend hardening.
5. True-device microphone/photo acceptance.

No new hidden PRD feature should be exposed in this phase.

### Phase B: Media Archive Expansion

Target: expand archive beyond text/photo after PRD decisions.

Candidate order:

1. 语音档案.
2. 时间信件.
3. 视频档案.

Required product decisions:

- Media privacy and retention.
- Backend storage and sync policy.
- True-device permission and error states.
- Whether these entries feed Echo immediately or only after analysis.

### Phase C: Family / Care Expansion

Target: turn `我的 / 长辈关怀` into a real family collaboration loop.

Candidate order:

1. 家人管理.
2. Family permission model.
3. Care dashboard thresholds and alerts.
4. 关怀升级草稿 promotion.
5. Real doctor/contact/intervention execution only after compliance.

Required product decisions:

- Family roles.
- Consent model.
- What children can see.
- What remains private between user and digital human.
- Whether emergency or medical-adjacent features are in product scope.

### Phase D: Digital Human Lifecycle

Target: complete the high-risk "digital human lifecycle" side of the PRD.

Candidate order:

1. Persona settings.
2. Lifecycle mode policy.
3. Inheritance trigger and consent model.
4. Legal/audit backend contract.

Required product decisions:

- Whether lifecycle modes are visible to users.
- Who controls mode transitions.
- What evidence triggers inheritance state.
- How to recover from mistakes.
- What legal copy must be accepted.

## Product Decisions Needed

These are the highest-impact PRD decisions that block full feature closure.

| Decision | Blocks | Recommended owner |
| --- | --- | --- |
| Echo waiting reply policy | 2-3 round waiting reply, voice pacing QA | Product |
| Voice-first vs multimodal Echo | Echo text/image input, UI structure | Product + Design |
| Archive media release scope | Audio, video, time letters | Product |
| Media privacy and retention | Archive upload, family visibility, deletion | Product + Legal |
| Profile account center scope | Avatar, password, phone, account security | Product + Backend |
| Family roles and permissions | 家人管理, family dashboard, persona switching | Product + Backend |
| Care metric definitions and thresholds | 心境追踪, 长辈关怀, alerts | Product |
| Doctor/contact escalation policy | 立即通话, 干预执行, 关怀升级草稿 | Product + Legal |
| Account deletion compliance | 账号注销执行 | Legal + Backend |
| Digital human lifecycle policy | 阳光/星辰/静默, 继承生命周期 | Product + Legal |
| True-device acceptance scope | Microphone, photo library, notification, signing | Product + QA |

## Engineering Guardrails

- Keep hidden candidates behind feature flags until the relevant PRD decision is made.
- Do not expose new tabs or rename `我的` unless current Stitch canvas and PRD explicitly require it.
- Treat `长辈关怀` as content under `我的`, not as the third tab.
- For every newly opened feature, add a static guard or simulator smoke before exposing it by default.
- After any UI or release-scope change, run:

```bash
RUN_ID=<run-id> tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

## Definition Of Full Feature Closure

The product can be treated as full PRD closure only when all of the following are true:

1. Every PRD row is either implemented and public, or explicitly descoped in PRD.
2. Hidden candidates have product decisions and promotion criteria.
3. Public UI matches current Stitch canvas and `htmlCode`.
4. Backend persistence works for archive, care, profile, and family flows.
5. Risky flows have legal/product-approved copy and confirmation states.
6. True-device microphone, photo library, notification, and signing acceptance pass.
7. Release regression passes with the selected public feature set.

## Recommended Next Product-Engineering Target

Start with public features that are already visible:

1. Echo 2-3 round waiting reply policy and implementation.
2. Profile settings completion.
3. Archive text/photo true-device and backend persistence.

After that, choose one hidden candidate to promote. The lowest-risk promotion is likely `语音档案`; the highest-risk promotions are `账号注销执行`, `医生联系 / 干预执行`, and `数字人继承生命周期`.
