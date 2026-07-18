# WI-S0-01-04 AccountLease 异步副作用清单

## 执行边界

- Work Item：`WI-S0-01-04 AccountLease 全异步检查点`
- 目标：同一 operation 在 `request / commit / ui / timer / runtime` 副作用前复核创建它的 `AccountLease`。
- 失效策略：drop/cancel；不得在 callback 执行时重新读取当前账号并把旧数据归给新账号。
- 保留现有 guard：owner、persona、requestId、local generation 和 provider runtime identity 继续生效；AccountLease 是额外的账号/会话/authority fence。
- 非目标：不重写 `EchoViewController`，不迁移 UIKit，不在本项解决 owner-scoped store schema。

## 中央合同

| Surface | Checkpoint | 当前状态 | 证据 |
|---|---|---|---|
| Account session transition | lifecycle | ENFORCED | `AccountSessionActor` publish active session；非 active 状态撤销 lease |
| Recovery policy | authority epoch | ENFORCED | App 启动恢复 epoch；runtime policy 变化立即更新 epoch |
| Authenticated backend request | request | ENFORCED | `DreamJourneyBackendClient.requestJSON` 同时校验 backend session lease 与 AccountLease |
| Backend response | commit | ENFORCED | response、refresh retry、recovery retry 延用原 lease |
| Main-thread completion | ui | ENFORCED | `deliverRequestResult` 在主线程 apply 前复核原 lease |
| Logout / private suspension | lifecycle | ENFORCED | 通知处理入口同步撤销 lease，再异步推进 actor transition |

## Surface Rollout

| Cohort | 关键 writer/callback | 必需 checkpoint | 状态 |
|---|---|---|---|
| Widget | snapshot file、active owner digest、timeline reload | commit/runtime | ENFORCED |
| Digital-human context | queued setter、family reconciliation、persona notification | commit/ui | ENFORCED (`8e4bdab`) |
| Family | startup refresh timer、refresh/invite callback、authorization notification | timer/commit/ui | ENFORCED (`eb7031b`) |
| KnowledgeSync | debounce、pull/push callback、base/pending/outbox commit | timer/request/commit | ENFORCED (`a1f703c`) |
| KBLite | extraction callback、graph CAS、graph file、Widget publish | commit/ui | ENFORCED (`8ae8849`) |
| Archive metadata/mailbox | list/detail/save/archive/post callback | request/commit/ui | ENFORCED (`025988e`) |
| Media capture/import | permission/picker/delegate、staging/final file、analysis callback | request/commit/ui | ENFORCED (`19dad88` + 本轮录音入口收敛) |
| Message/notification | delayed reply store、authorization/add/remove、push job | commit/timer/ui | ENFORCED (`7016625`) |
| Voice clone | train/query callback、poll timer、profile persistence/completion | request/timer/commit/ui | ENFORCED (`80046ea`) |
| Memoir TTS | synthesis callback、audio/metadata write/delete、preview runtime | commit/runtime/ui | ENFORCED (`854393b`) |
| Echo/Digital Human | session create/open/heartbeat/release、PCM chunk/audio owner | request/timer/runtime/ui | INTERNAL_READY / G4_OPEN（本轮） |
| DialogEngine | retry/silence timer、SDK delegate provenance | timer/runtime/ui | INTERNAL_READY / G4_OPEN（本轮） |

## 必测竞态

1. A → B、A → logout、A → B → A。
2. 同 subject 新 generation、同 generation token refresh、authority epoch 变化。
3. picker/权限/public capability 返回前切号，不产生目标账号文件、UI 或后端请求。
4. Knowledge CAS 前、内存 apply 后、base/outbox 写前后切号。
5. Family 重叠 refresh/invite 及 stale failure，不写入当前新 owner。
6. notification authorization/add 与 push registration 返回前切号。
7. Voice poll、TTS failure delete、PCM chunk 和 DH heartbeat 在切号后停止。
8. Widget publish 中 lease 失效，最终文件撤销且不 reload stale timeline。

## Gate 口径

- G0 已覆盖中央合同、全部 surface 静态门禁、AccountLease 竞态模型和 recovery authority epoch 变化。
- G1 已覆盖 Echo 数字人 lifecycle smoke 与 Archive -> Echo 上下文 smoke；模拟器结果未发现 stale UI/runtime apply。
- Echo/Voice/Digital Human 的真实 Provider、真机音频和权限证据仍属于 G4，保留为 `EXTERNAL_BLOCKED`，不把 `INTERNAL_READY` 误报为生产完成。
- 腾讯数智人延迟 release 队列只在进程内持有；App 被系统终止时依赖后端 session TTL/reconciliation 回收，不把该行为包装成客户端可靠队列。
- 如果 `/digital-human/sessions` 已在服务端成功、但账号切换使客户端在解码前拒绝响应，客户端无法取得 `sessionId` 执行补偿 release；该边界明确依赖服务端 TTL 回收，属于已知的短时配额占用，不允许把旧响应交给新账号。

## 审查后收敛

1. DialogEngine 在上一 provider session 停止后轮换 engine callback generation；旧 `SessionFinished` 不能终止新 operation。
2. Echo 在账号或 authority epoch 重绑时清空旧转录、pending reply 和 turn gate，并恢复到当前账号可操作状态。
3. Echo 所有共享 DialogEngine 停止、打断、恢复和知识注入入口均验证 exact binding owner。
4. AIRecording 离屏时停止自己的录音并释放 exact binding；离屏 controller 不响应前台通知重新抢占引擎。
5. account/authority 通知统一回到主线程；Echo 在新 binding 生效后重新应用音频路由，普通 Echo 不继承旧数字人 `enablePlayer=false` 状态。

## 本轮验证证据

- `bash Scripts/QA/product-v4/run-account-lease-runtime-gate.sh`
- `swift Scripts/QA/product-v4/dialog-engine-provider-operation-model-smoke.swift`
- `python3 Scripts/QA/product-v4/product-v4-recovery-runtime-client-check.py`
- `swift Scripts/QA/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift`
- `swift Scripts/QA/prd-stitch-ui/echo-audio-owner-lifecycle-guard-check.swift`
- Echo lifecycle smoke：`tmp/visual-qa/prd-stitch-ui/echo-digital-human-lifecycle-smoke/20260718-094109/echo-digital-human-lifecycle-smoke-result.json`
- Archive -> Echo smoke：`tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260718-093239/archive-to-echo-smoke-result.json`
- `xcodebuild` generic iPhoneOS Debug（`CODE_SIGNING_ALLOWED=NO`）
- `git diff --check`

结论：`WI-S0-01-04` 的 G0/G1 内部门达到 `INTERNAL_READY`；G4 外部门保持开放，后续进入 `WI-S0-01-05` 时不得删除该外部验收项。
