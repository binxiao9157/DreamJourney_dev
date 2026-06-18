# PRD Coverage Matrix

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Head at creation: `790f029 docs: add prd ui continuation plan`

## Source of truth

- Product: latest attached `《寻梦环游 产品PRD V1.0》(1).md`.
- Visual: current Stitch canvas and `htmlCode`.
- MCP screenshots are auxiliary, not final visual authority.
- Code: current UIKit implementation in `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`.

## Coverage Table

| PRD requirement | Current status | Public? | Evidence | Next action |
| --- | --- | --- | --- | --- |
| 回响语音输入 | implemented | yes | `EchoViewController`, archive-to-echo smoke | true-device microphone acceptance |
| 2-3轮后等待回信 | implemented ten-round/adaptive policy with persisted in-app state, local notification, deployed backend device-token registration, deployed backend delayed-reply persistence, and local backend dispatch-due contract | yes | `EchoViewModel`, `EchoDelayedReplyStore`, `EchoDelayedReplyNotificationScheduler`, `PushDeviceTokenStore`, echo delayed reply notification/push/dispatch checks, deployed run `20260618-deployed-push-device-token-contract-rerun-205018`, blocked dispatch run `20260618-deployed-echo-dispatch-contract-210536` | deploy dispatch-due route, rerun release-like backend acceptance, APNs provider delivery, true-device voice/notification acceptance |
| 档案照片 | implemented | yes | Archive photo entry smoke | true-device photo acceptance |
| 档案视频 | hidden candidate shell | no | archive media readiness guard, release matrix | picker/compression/storage/backend policy, true-device video picker acceptance |
| 档案录音 | hidden candidate | no | archive media smoke | true-device audio acceptance |
| 档案文字描述 | implemented | yes | archive smoke | maintain |
| 时间信件 | hidden candidate | no | archive media smoke | delivery policy |
| 个人资料管理 | implemented for profile fields and login password participation with selected-backend `/profile`, `/auth/login`, and `/auth/password` acceptance; password change UI remains hidden | yes for profile fields and login; no for password change | `LoginViewController`, `ProfileSettingsViewController`, `ProfilePasswordChangeViewController`, `login-password-contract-check.swift`, backend `ProfileAPITests`, backend `PasswordAPITests`, release-like backend run `20260618-selected-backend-latest-contracts-after-deploy-r2` | auth/security review, true-device acceptance, explicit password-change public release decision |
| 心境追踪 | implemented fallback and data states | yes | Profile care checks, care data states check | lifecycle policy |
| 家人管理 | hidden candidate | no | family persona smoke | product exposure decision |
| 法律法规 | implemented | yes | `ProfileLegalViewController` | legal review |
| 账号退出 | implemented | yes | `ProfileViewController` | maintain |
| 账号注销 | hidden blocked shell | no | safety check | compliance/backend contract |
| 长辈关怀 | implemented aggregate with loading/empty/stale/failed states | yes | elder dashboard check, profile care public placeholder check | real backend acceptance |
| 后端合同闭环 | partially implemented; contract gaps pinned | mixed | `2026-06-18-backend-contract-gap-matrix.md`, `backend-contract-gap-check.swift` | implement missing backend routes or keep backend-ready features hidden |
| 生死转换机制 | hidden boundary | no | mode lifecycle checks | product/legal policy |

Echo waiting reply note: PRD updated to ten-round/adaptive policy; the old third-turn default policy has been superseded. PRD now says one user speech plus one AI reply counts as one round; the default waits after 10 rounds; emotion/content signals can trigger earlier; delay is 5-10 minutes. In-app state, local notification, device-token registration, delayed-reply backend persistence, and the local `POST /echo/delayed-replies/dispatch-due` ready-for-provider contract are implemented through `EchoDelayedReplyStore`, `EchoDelayedReplyNotificationScheduler`, `PushDeviceTokenStore`, `DreamJourneyBackendClient.registerPushDeviceToken`, `DreamJourneyBackendClient.scheduleEchoDelayedReplyPush`, and backend `mark_due_echo_delayed_replies_for_dispatch`. Deployed backend acceptance run `20260618-deployed-push-device-token-contract-rerun-205018` verified `echoDelayedReplyDeviceTokenId` and `echoDelayedReplyPushProviderState=pending`; deployed dispatch acceptance run `20260618-deployed-echo-dispatch-contract-210536` is blocked by HTTP 405 for `POST /echo/delayed-replies/dispatch-due`. APNs provider delivery, deployed service-side scheduled dispatch acceptance, and true-device notification acceptance remain open.

Profile settings note: name/gender/region validation, inline save states, local persistence, and the dedicated iOS `/profile` sync contract are covered by `profile-settings-save-state-check.swift` and `profile-account-fields-check.swift`. The selected backend now accepts `POST /profile` and `GET /profile/{user_id}` in release-like run `20260618-selected-backend-latest-contracts-after-deploy-r2`. Login password participation is covered by `login-password-contract-check.swift`: the visible login password field is validated locally and sent to `/auth/login` when backend auth is configured. password change hidden shell, also tracked as Password change hidden shell for release guard evidence, and the iOS `/auth/password` client contract are covered by `profile-password-change-check.swift`; backend `PasswordAPITests` cover hashed password credentials and old-password verification; selected-backend password acceptance has passed with `passwordChangeStatus=changed`, `passwordOldLoginStatus=invalid password`, and `passwordNewLoginConfigured=true`. Password change remains hidden until auth/security review and true-device acceptance remain open, plus an explicit public-release decision.

Backend contract note: iOS/backend parity is tracked in `docs/superpowers/status/2026-06-18-backend-contract-gap-matrix.md`. `/profile`, `/auth/login`, `/auth/password`, archive persona visibility fields, care snapshot state fixtures, `/devices/push-token`, and delayed reply `deviceTokenId` persistence are accepted on the selected release-like backend with runs `20260618-selected-backend-latest-contracts-after-deploy-r2` and `20260618-deployed-push-device-token-contract-rerun-205018`. `/auth/password` still needs security review before public exposure. `/echo/delayed-replies/dispatch-due` is implemented and tested locally, but the deployed run `20260618-deployed-echo-dispatch-contract-210536` returned HTTP 405; deploy this static POST route and rerun release-like backend acceptance before claiming service-side scheduled dispatch acceptance. `/echo/delayed-replies` still needs APNs provider delivery and true-device notification acceptance before remote push can be called complete.

## External Acceptance Boundary

- 本地 FastAPI 后端 smoke：accepted
- release-like FastAPI/Postgres 后端验收：accepted
- 线上/公网后端验收：accepted for simulator release-like scope
- 真机验收：not accepted
- 语音 SDK 生产质量验收：not accepted
- App Store / TestFlight 签名链路验收：not accepted

These are not product failures. They are external acceptance gates that require user-provided environment or physical-device operation.

## Release Gating Policy

No hidden PRD feature is public by default.

Default public surface remains:

- `记忆档案`
- `回响`
- `我的`
- text/photo archive creation
- voice-first Echo
- profile settings
- legal center
- logout
- aggregate `心境追踪` / `长辈关怀`

Hidden or blocked by default:

- archive audio upload
- time letters
- video upload
- persona settings
- family management public release
- account deletion execution
- doctor contact / intervention execution
- sunlight/star/silent lifecycle transition controls
- digital inheritance lifecycle

## Hidden Candidate Release Matrix

Detailed release decisions live in `docs/superpowers/status/2026-06-17-release-feature-matrix.md`.

The PRD items below are intentionally not public MVP features yet. They may have partial implementation, QA-only UI, local safety shells, or backend contract drafts, but they still require explicit promotion before appearing in default release mode.

| Hidden PRD candidate | Release interpretation | Public in MVP | Release matrix row |
| --- | --- | --- | --- |
| archive audio upload | QA-only archive media branch; true-device recording and media policy still required | no | archive audio upload |
| time letters | QA-only archive creation branch; delivery and scheduling semantics still required | no | time letters |
| video upload | hidden shell only; PRD scope and media backend contract still required | no | video upload |
| persona settings | QA-only archive/profile-adjacent branch; ownership and prompt-safety policy still required | no | persona settings |
| family management public release | QA-only profile branch; invitation, permission, and membership backend are not public | no | family management public release |
| care dashboard expansion | aggregate care dashboard and non-executing `关怀升级准备中` placeholder are public; intervention/contact execution is not | aggregate + placeholder only | care dashboard expansion |
| account deletion execution | hidden safety shell only; destructive deletion is not connected | no | account deletion execution |
| doctor contact / intervention execution | public placeholder plus hidden safety shell only; no real call, provider, or intervention submission | no | doctor contact / intervention execution |
| care escalation draft | public placeholder is informational only; hidden local draft shell exists, backend submission and clinical/legal review still required | no | care escalation draft |
| sunlight/star/silent lifecycle transition controls | hidden local QA controls only; lifecycle policy is not public | no | sunlight/star/silent lifecycle transition controls |
| digital inheritance lifecycle | hidden boundary only; inheritance trigger and legal consent model are not public | no | digital inheritance lifecycle |

## Blockers

- release-like FastAPI/Postgres and simulator remote-backend acceptance passed with `20260618-deployed-postgres-acceptance-after-deploy`, latest selected contract run `20260618-selected-backend-latest-contracts-after-deploy-r2`, and latest deployed push-token contract run `20260618-deployed-push-device-token-contract-rerun-205018`.
- 后续如有后端合同变化，需要 rerun `run-release-like-backend-acceptance.sh`; deployed push-token registration and delayed-reply `deviceTokenId` persistence are accepted, while dispatch-due route deployment, APNs provider delivery, and true-device notification arrival are still external gates.
- 需要真机、签名和设备操作 before true-device acceptance can run.
- 需要产品/合规确认 before account deletion, doctor contact, intervention, and inheritance flows can execute.
- 需要明确发布范围 before audio, time-letter, video, and public family management can move from hidden candidate to public feature.

## Current Interpretation

The current app is a simulator-validated MVP candidate for the core loop:

```text
记忆档案 -> 回响 -> 心境追踪 / 关怀
```

It is not yet a fully accepted real-device release candidate.

The safest next implementation work is still:

1. refresh final Stitch visual QA,
2. add one-command release regression,
3. harden hidden candidates one feature at a time,
4. run true-device acceptance when signing and device conditions exist.
