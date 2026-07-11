# PRD Coverage Matrix

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Head at creation: `790f029 docs: add prd ui continuation plan`

Last synced: 2026-06-21, after the product decision to expose family phone invitation and account soft deletion.

## Source of truth

- Product: latest attached `《寻梦环游 产品PRD V1.0》(1).md`.
- Visual: current Stitch canvas and `htmlCode`.
- MCP screenshots are auxiliary, not final visual authority.
- Code: current UIKit implementation in `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`.

## Coverage Table

| PRD requirement | Current status | Public? | Evidence | Next action |
| --- | --- | --- | --- | --- |
| 回响语音输入 | implemented with production voice SDK configuration gate and explicit readiness boundary | yes | `EchoViewController`, `DialogEngineManager`, `VoiceSDKReadinessSummary`, archive-to-echo smoke, `true-device-voice-readiness-check.swift`, `voice-sdk-readiness-boundary-check.swift`, `run-true-device-voice-preflight.sh`, `docs/superpowers/status/2026-06-19-production-voice-sdk-readiness-boundary.md` | 外部验收：populate true-device voice evidence package, then accept production SDK ASR/TTS quality |
| 2-3轮后等待回信 | implemented ten-round/adaptive policy with persisted in-app state, local notification, deployed backend device-token registration, deployed backend delayed-reply persistence, and deployed backend dispatch-due contract | yes | `EchoViewModel`, `EchoDelayedReplyStore`, `EchoDelayedReplyNotificationScheduler`, `PushDeviceTokenStore`, echo delayed reply notification/push/dispatch checks, deployed run `20260618-deployed-push-device-token-contract-rerun-205018`, accepted dispatch run `20260618-deployed-echo-dispatch-contract-accepted-211732` | APNs provider delivery, true-device voice/notification acceptance |
| 档案照片 | implemented with sync error recovery | yes | Archive photo entry smoke, `archive-sync-error-recovery-check.swift` | true-device photo acceptance |
| 档案视频 | hidden readiness shell implemented with mock detail/list state, thumbnail placeholder, upload/analysis failed/retry states, runtime media capability, upload intent, and backend hidden-media sync gate | hidden | `archive-video-hidden-readiness-check.swift`, `archive-hidden-media-detail-ui-check.swift`, `archive-hidden-media-combo-gate-check.swift`, `archive-media-upload-intent-contract-check.swift`, `archive-media-provider-switch-contract-check.swift`, `docs/superpowers/status/2026-06-19-archive-video-hidden-readiness.md` | 产品决策 + 外部验收：decide public scope, then implement real picker/compression/object-storage provider and true-device video picker acceptance |
| 档案录音 | hidden candidate with non-true-device lifecycle, backend media contract, upload intent, transcription/status shell, Echo context rules, and true-device evidence package prepared | hidden | `archive-audio-lifecycle-smoke-check.swift`, `archive-audio-ia-release-check.swift`, `archive-media-backend-contract-check.swift`, `archive-media-echo-context-polish-check.swift`, `true-device-archive-audio-acceptance-check.swift`, `true-device-acceptance-evidence-package-check.swift` | 外部验收：run physical-device recording, permission recovery, playback route, audio quality, and foreground/background evidence package |
| 档案文字描述 | implemented with sync error recovery | yes | archive smoke, `archive-sync-error-recovery-check.swift` | maintain |
| 时间信件 | public delivery foundation implemented with text + image creation, open time, family/self recipients, draft/edit/seal/detail UI, sealed delete protection, local notification scheduling, in-app reminder entry, and backend metadata lifecycle | yes | `archive-hidden-media-timeletter-shell-check.swift`, `archive-time-letter-backend-lifecycle-check.swift`, `time-letter-delivery-policy-shell-check.swift`, `docs/superpowers/status/2026-06-21-time-letter-public-delivery.md` | 外部验收：true-device local notification arrival, cross-account recipient reminder delivery, APNs/provider notification evidence |
| 个人资料管理 | implemented for profile fields and login password participation with selected-backend `/profile`, `/auth/login`, and `/auth/password` acceptance; password change UI remains hidden | yes for profile fields and login; no for password change | `LoginViewController`, `ProfileSettingsViewController`, `ProfilePasswordChangeViewController`, `login-password-contract-check.swift`, backend `ProfileAPITests`, backend `PasswordAPITests`, release-like backend run `20260618-selected-backend-latest-contracts-after-deploy-r2` | auth/security review, true-device acceptance, explicit password-change public release decision |
| 登录会话与数据 ownership | opaque access/refresh token、hash-only persistence、refresh rotation、防重放、logout revoke、legacy backend-token compatibility、ownership shadow 和跨账号授权矩阵已实现；关怀/时间信件/邀请敏感路由已绑定 bearer principal，生产全局 enforce 未开启 | yes for login/session; policy diagnostics are QA-only | `BackendAuthSessionStore`, `DreamJourneyBackendClient`, backend `CrossAccountAuthorizationPolicy` / `AuthSessionAPITests`, `auth-session-ownership-shadow-check.swift`, `cross-account-authorization-policy-check.swift`, `backend-cross-account-authorization-shadow-smoke.py`, ledgers `L20260710-165434` / `L20260710-193743` | 部署后跑线上 Postgres auth + cross-account shadow smoke；补 SMS identity proof 和部署 shadow 证据后再评估全局 enforce |
| 知识库 Widget 派生隐私 | schema v2 最小摘要、显式 `summaryAllowed`、owner digest、generation 防旧写、登出/切换清理和 Widget timeline reload 已实现；旧/损坏/身份不匹配快照 fail closed | system Widget shell; knowledge content defaults to denied | `KnowledgeWidgetPrivacyPolicy`, `KnowledgeWidgetSnapshotStore`, `WidgetKnowledgeSnapshotReader`, `knowledge-widget-privacy-lifecycle-check.swift`, three Widget model smokes, Task 21 ledger `L20260711-145625-21` | 外部验收：在 Apple Developer Portal 注册 App Group、刷新主/扩展 provisioning，并真机验证 Widget Gallery、账号切换和锁屏隐私；产品决定公开授权入口前保持默认 deny |
| 心境追踪 | implemented fallback and data states | yes | Profile care checks, care data states check | lifecycle policy |
| 家人管理 | implemented public phone invitation foundation with pending/joined/failed states and no delete operation; backend accepted invitation is the only production authority, KBPerson remains a non-authorized candidate, repository/overrides are account-scoped, Echo family context is revalidated, and unsigned full-graph import is rejected. Runtime freshness, request/persona generations and coordinator authorization epoch reject stale refresh/extraction/governance callbacks; revoked context persists back to self | yes for phone invite/profile entry; KB candidates and legacy full-graph sharing are not public; exit/unlink/advanced lifecycle hidden | `FamilyRelationshipAuthorizationPolicy`, `FamilyRepository`, `DigitalHumanContextStore`, `KnowledgeSyncAuthorizationScope`, `KnowledgeAuthorizationEpochState`, `family-digital-human-hidden-contract-check.swift`, `backend-family-voice-contract-smoke-check.swift`, `ios-family-voice-consumer-contract-check.swift`, `ios-family-voice-hidden-uiqa-smoke-check.swift`, `profile-family-account-lifecycle-check.swift`, Task 22 freshness/snapshot/reconciliation/epoch gates, existing backend pending/accepted Context tests, final8 release regression | 产品决策：candidate-to-invite UX, exit/unlink relationship policy, advanced lifecycle transition policy, consent copy, recovery rules; future full-graph sharing requires a signed backend grant |
| 法律法规 | implemented | yes | `ProfileLegalViewController` | legal review |
| 账号退出 | implemented | yes | `ProfileViewController` | maintain |
| 账号注销 | implemented public soft-delete foundation with two confirmations, no data export, 30-day retention, same-phone restore within 30 days, one restore opportunity, and purge-expired contract | yes for soft-delete contract; production purge operations/legal review external | `ProfileViewController.showAccountDeletionConfirmation`, `DreamJourneyBackendClient.softDeleteAccount`, backend `AccountDeletionAPITests`, `/auth/delete`, `/auth/restore`, `/auth/purge-expired-deletions`, `profile-family-account-lifecycle-check.swift`, `backend-family-account-lifecycle-smoke.py` | 外部/合规验收：deploy backend, run deployed smoke, confirm production purge schedule and customer support restore policy |
| 长辈关怀 | implemented aggregate with loading/empty/stale/failed states | yes | elder dashboard check, profile care public placeholder check | real backend acceptance |
| 后端合同闭环 | partially implemented; contract gaps pinned | mixed | `2026-06-18-backend-contract-gap-matrix.md`, `backend-contract-gap-check.swift` | implement missing backend routes or keep backend-ready features hidden |
| 生死转换机制 | hidden boundary | no | mode lifecycle checks | product/legal policy |
| 声音克隆 | public foundation with backend lifecycle contract, explicit authorization, audio sample submission, status refresh, disable/delete actions, VolcEngine Voice Clone V3 backend provider proxy, and backend-proxied cloned-voice TTS synthesis | yes for foundation; production quality external | `ProfileVoiceCloneShellViewController`, `VoiceCloneService`, `voice-clone-shell-contract-check.swift`, `voice-clone-backend-contract-check.swift`, `backend-family-voice-contract-smoke-check.swift`, `ios-family-voice-consumer-contract-check.swift`, `2026-06-19-volcengine-voice-clone-v3-provider.md` | 外部/合规验收：sample quality policy, real voice sample QA, real trained-voice synthesis acceptance, provider-side disable/delete verification, consent audit |

## 2026-06-19 Phase 0 Sync Notes

The following items were completed after the original matrix was created and should no longer be treated as unimplemented engineering gaps:

- Hidden Family / Voice UIQA Consumer Gate: iOS consumes backend-derived `digitalHumanMode`, `familyPersonaContractVersion`, `voiceProfileId`, and `sampleStatus`; the voice clone entry has since been promoted to a public foundation while advanced family/voice QA evidence remains useful.
- 时间信件公开投递闭环: draft/sealed states now persist `openAt` / `recipients` / `sealedAt` / `deliveryStatus`, schedule local + in-app reminders, and reject deletion after sealing.
- 视频档案 Hidden Readiness: mock video detail/list state, thumbnail placeholder, file size, upload status, failed/retry analysis UI, runtime capability, and hidden media combo gate are implemented.
- 真机验收包强化: true-device voice and archive-audio scripts now produce fixed evidence manifests, screenshot names, logs, and manual QA notes.
- 生产语音 SDK readiness 边界: `VoiceSDKReadinessSummary` prevents mock ASR/TTS, backend-token fallback, and SDK initialization from being mistaken for production voice completion.
- 家庭成员规则: phone invite is now the public foundation; pending/accepted/failed states are modeled, selected-recipient lists use accepted family members only, and the public backend revoke route returns 409 because deleting family members is not supported by PRD.
- 账号注销规则: two-step iOS confirmation and backend soft-delete/restore/purge contract are implemented with `deletedAt`, `purgeAfter`, `restoreDeadline`, `restoreCount <= 1`, no data export, and 30-day restore window.

Echo waiting reply note: PRD updated to ten-round/adaptive policy; the old third-turn default policy has been superseded. PRD now says one user speech plus one AI reply counts as one round; the default waits after 10 rounds; emotion/content signals can trigger earlier; delay is 5-10 minutes. In-app state, local notification, device-token registration, delayed-reply backend persistence, and the `POST /echo/delayed-replies/dispatch-due` ready-for-provider contract are implemented through `EchoDelayedReplyStore`, `EchoDelayedReplyNotificationScheduler`, `PushDeviceTokenStore`, `DreamJourneyBackendClient.registerPushDeviceToken`, `DreamJourneyBackendClient.scheduleEchoDelayedReplyPush`, and backend `mark_due_echo_delayed_replies_for_dispatch`. Deployed backend acceptance run `20260618-deployed-push-device-token-contract-rerun-205018` verified `echoDelayedReplyDeviceTokenId` and `echoDelayedReplyPushProviderState=pending`; deployed dispatch acceptance run `20260618-deployed-echo-dispatch-contract-accepted-211732` verified `echoDelayedReplyDispatchState=readyForProvider` and `echoDelayedReplyProviderDeliveryAttempted=false`. Earlier dispatch attempts `20260618-deployed-echo-dispatch-contract-210536` and `20260618-deployed-echo-dispatch-contract-rerun-report-211438` were blocked by HTTP 405 before the backend redeploy and are retained as recovered deployment-drift evidence. APNs provider delivery and true-device notification acceptance remain open.

Profile settings note: name/gender/region validation, inline save states, local persistence, and the dedicated iOS `/profile` sync contract are covered by `profile-settings-save-state-check.swift` and `profile-account-fields-check.swift`. The selected backend now accepts `POST /profile` and `GET /profile/{user_id}` in release-like run `20260618-selected-backend-latest-contracts-after-deploy-r2`. Login password participation is covered by `login-password-contract-check.swift`: the visible login password field is validated locally and sent to `/auth/login` when backend auth is configured. password change hidden shell, also tracked as Password change hidden shell for release guard evidence, and the iOS `/auth/password` client contract are covered by `profile-password-change-check.swift`; backend `PasswordAPITests` cover hashed password credentials and old-password verification; selected-backend password acceptance has passed with `passwordChangeStatus=changed`, `passwordOldLoginStatus=invalid password`, and `passwordNewLoginConfigured=true`. Password change remains hidden until auth/security review and true-device acceptance remain open, plus an explicit public-release decision.

Backend contract note: iOS/backend parity is tracked in `docs/superpowers/status/2026-06-18-backend-contract-gap-matrix.md`. `/profile`, `/auth/login`, `/auth/password`, archive persona visibility fields, care snapshot state fixtures, `/devices/push-token`, delayed reply `deviceTokenId` persistence, and `/echo/delayed-replies/dispatch-due` are accepted on the selected release-like backend with runs `20260618-selected-backend-latest-contracts-after-deploy-r2`, `20260618-deployed-push-device-token-contract-rerun-205018`, and `20260618-deployed-echo-dispatch-contract-accepted-211732`. `/auth/password` still needs security review before public exposure. Earlier deployed runs `20260618-deployed-echo-dispatch-contract-210536` and `20260618-deployed-echo-dispatch-contract-rerun-report-211438` returned HTTP 405 for dispatch-due before the latest backend redeploy and are retained as recovered deployment-drift evidence. `/echo/delayed-replies` still needs APNs provider delivery and true-device notification acceptance before remote push can be called complete.

Production voice SDK note: 生产语音 SDK key now resolves through build settings (`VOLCENGINE_APP_ID`, `VOLCENGINE_APP_KEY`, `VOLCENGINE_APP_TOKEN`) instead of hard-coded plist placeholders. `DialogEngineManager` fails early when production credentials are missing or still placeholders, and `run-true-device-voice-preflight.sh` is the entrypoint before true-device voice acceptance. On 2026-06-18, iPhoneOS no-sign compile, signed physical-device build, install, and launch passed on the connected iPhone after restoring the missing local provisioning profile file. True-device console output shows `SpeechEngineToB` SDK initialization and `[DialogEngine] ✅ 引擎初始化成功`. `VoiceSDKReadinessSummary` now separates `mockASRTTS`, `backendTokenFallback`, `productionSDKNeedsTrueDeviceQA`, and future `productionSDKVerified`; production voice quality is still not accepted until a human-operated device run captures microphone permission, ASR, TTS, playback route, foreground/background, and SDK error-recovery evidence.

Archive sync note: 档案文字 / 照片同步失败恢复 is implemented for public MVP text/photo archive items. Local saves are retained when backend writes fail, item metadata tracks `pending` / `synced` / `failed`, the archive list and detail surfaces show the cloud state, and the hidden remote-fetch QA path retries failed or pending public items before the next remote refresh. Hidden audio, time-letter, and video candidates remain outside default public sync recovery.

## External Acceptance Boundary

- 本地 FastAPI 后端 smoke：accepted
- release-like FastAPI/Postgres 后端验收：accepted
- 线上/公网后端验收：accepted for simulator release-like scope
- 真机验收：partially accepted; signed build, install, launch, and process evidence passed; true-device evidence package format is fixed, but permission prompts, archive photo picker, voice conversation, foreground/background, playback route, logs, and screenshot evidence remain open
- 语音 SDK 生产质量验收：partially accepted; true-device SDK initialization passed and readiness boundary is guarded, but full ASR/TTS conversation quality and recovery evidence remain required
- App Store / TestFlight 签名链路验收：not accepted; local development install passed, distribution signing is separate
- APNs provider delivery / 真机通知到达：not accepted; app now skips APNs registration when `aps-environment` is absent so Personal Team builds no longer emit a system registration failure, verified by true-device run `20260618-apns-gated-registration-launch`. Paid-Team Push capability, APNs token return, backend registration, provider delivery, and true-device notification arrival still need acceptance

These are not product failures. They are external acceptance gates that require user-provided environment or physical-device operation.

## Release Gating Policy

No remaining hidden PRD feature is public by default. Family phone invitation, time-letter foundation, voice-clone foundation, and account soft deletion are public after explicit PRD decisions.

Default public surface remains:

- `记忆档案`
- `回响`
- `我的`
- text/photo archive creation
- voice-first Echo
- profile settings
- family phone invitation
- account soft deletion
- legal center
- logout
- aggregate `心境追踪` / `长辈关怀`

Hidden or blocked by default:

- archive audio upload
- video upload
- family advanced lifecycle controls
- doctor contact / intervention execution
- sunlight/star/silent lifecycle transition controls
- digital inheritance lifecycle

## Remaining Work By Decision Type

Public MVP engineering remains:

- Populate true-device evidence for Echo voice, photo archive import, foreground/background recovery, and care/profile sanity checks.
- Run production voice SDK ASR/TTS quality acceptance on a physical device.
- Keep public archive text/photo, Echo, profile, legal, and care regression gates green after any Stitch UI refresh.

Hidden engineering remains:

- Audio/video real-media behavior should stay behind hidden flags until promoted.
- Audio/video real-media behavior, password change, doctor contact, and lifecycle controls stay hidden or safety-shell only.

External acceptance remains:

- APNs provider delivery and true-device notification arrival.
- Paid Apple Developer Team / distribution signing chain if push or TestFlight release is required.
- Real object-storage provider for media upload if video/audio are promoted.

Product / compliance decisions remain:

- Time-letter delivery rules and recipient semantics.
- Family invitation, consent, role, and visibility model.
- Voice clone authorization and quality policy.
- Doctor/intervention provider responsibility and emergency copy.
- Account deletion/export/cooling-off policy.
- Digital inheritance trigger, proof, consent, audit, and recovery policy.

## Hidden Candidate Release Matrix

Detailed release decisions live in `docs/superpowers/status/2026-06-17-release-feature-matrix.md`.

The PRD items below are intentionally not public MVP features yet. They may have partial implementation, QA-only UI, local safety shells, or backend contract drafts, but they still require explicit promotion before appearing in default release mode.

| Hidden PRD candidate | Release interpretation | Public in MVP | Release matrix row |
| --- | --- | --- | --- |
| archive audio upload | QA-only archive media branch; true-device recording and media policy still required | no | archive audio upload |
| video upload | hidden shell only; PRD scope and media backend contract still required | no | video upload |
| persona settings | QA-only archive/profile-adjacent branch; ownership and prompt-safety policy still required | no | persona settings |
| family advanced lifecycle controls | phone invite foundation is public; exit/unlink and advanced lifecycle transition controls remain QA/local-policy only | no | family advanced lifecycle controls |
| care dashboard expansion | aggregate care dashboard and non-executing `关怀升级准备中` placeholder are public; intervention/contact execution is not | aggregate + placeholder only | care dashboard expansion |
| doctor contact / intervention execution | public placeholder plus hidden safety shell only; no real call, provider, or intervention submission | no | doctor contact / intervention execution |
| care escalation draft | public placeholder is informational only; hidden local draft shell exists, backend submission and clinical/legal review still required | no | care escalation draft |
| sunlight/star/silent lifecycle transition controls | hidden local QA controls only; lifecycle policy is not public | no | sunlight/star/silent lifecycle transition controls |
| digital inheritance lifecycle | hidden boundary only; inheritance trigger and legal consent model are not public | no | digital inheritance lifecycle |

## Blockers

- release-like FastAPI/Postgres and simulator remote-backend acceptance passed with `20260618-deployed-postgres-acceptance-after-deploy`, latest selected contract run `20260618-selected-backend-latest-contracts-after-deploy-r2`, and latest deployed push-token contract run `20260618-deployed-push-device-token-contract-rerun-205018`.
- 后续如有后端合同变化，需要 rerun `run-release-like-backend-acceptance.sh`; deployed push-token registration, delayed-reply `deviceTokenId` persistence, and dispatch-due route parity are accepted by `20260618-deployed-echo-dispatch-contract-accepted-211732`. APNs provider delivery and true-device notification arrival remain external gates.
- 需要真机、签名和设备操作 before true-device acceptance can run.
- 需要产品/合规确认 before production purge operations, doctor contact, intervention, and inheritance flows can execute.
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
