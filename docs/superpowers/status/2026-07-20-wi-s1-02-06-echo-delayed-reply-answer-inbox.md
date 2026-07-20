# WI-S1-02-06 Echo 延迟回信 Answer、Inbox 与 Receipt G0/G1/G2 证据

日期：2026-07-20

## 已实现边界

本轮为默认关闭的 Echo 延迟回信 V4 协议建立了真实结果的原子持久化合同；没有启用 worker、Provider 调用、公开 UI 或线上路由切换。

后端以 `vaultId + conversationId + requestId + contextHash` 生成稳定业务目标键。对于带有 `deliveryProtocolVersion=echo-delayed-reply-v1` 的已到期记录，完成服务会在同一个 Postgres Unit of Work 中：

1. 锁定并重读延迟回信聚合；
2. 执行 Owner、vault、authority epoch、reply generation、context hash/version、policy version、row version 和 context expiry 重验；
3. 只在私有 `echo_delayed_reply_answers` 表中持久化 Answer 正文及 citation/provider 哈希；
4. 写入不含 Answer 正文的 owner Inbox 指针；
5. 写入通用 Consumer Inbox 与 business completion receipt；
6. 使用 row-version CAS 将延迟回信更新为 `completed`，或将失效上下文更新为诚实的 `blocked` 终态。

任一写入失败都会回滚 Answer、Inbox、receipt 和 aggregate 更新。重复完成返回已有终态，不产生第二条 Answer 或 Inbox。

## 默认关闭与旧路径隔离

- 旧 `scheduled -> readyForProvider` dispatcher 显式排除 `echo-delayed-reply-v1`，不会与新路径竞争。
- 旧 `POST /echo/delayed-replies` 路由显式拒绝 V4 协议标识，返回 `409 echo_delayed_reply_v4_disabled`；不会把未来 V4 客户端静默降级为 legacy 记录。
- iOS 已在提交 `29e8a9e` 中停止用本地到期时间伪造“回信已抵达”；本地 notification 仍只是提醒/刷新触发。
- 新协议没有由公开创建路径写入，因此公开 MVP 行为不变。

## 代码与提交

后端本地提交：

- `de6bc7d feat(v4): close delayed Echo reply receipt contract`
- `53b420c feat(v4): add delayed Echo reply answer read contract`

关键入口：

- `app/services/echo_delayed_reply_effects.py`
- `app/services/echo_delayed_reply_service.py`
- `app/services/postgres_store.py`
- `db/migrations/0024_echo_delayed_reply_answer_completion.sql`
- `scripts/run-backend-echo-delayed-reply-answer-inbox-contract-gate.sh`
- `scripts/run-backend-echo-delayed-reply-atomic-completion-postgres-smoke.sh`

## G0 验证证据

本地聚焦 gate：

```bash
PYTHON_BIN=.venv/bin/python \
scripts/run-backend-echo-delayed-reply-answer-inbox-contract-gate.sh
```

结果：`88` 项相关测试通过，覆盖：

- V4 immutable envelope 与稳定目标键；
- 不到期不生成效果；
- 本地/legacy dispatcher 双路径隔离；
- Answer 正文不进入 Inbox、receipt 或 value-free trace；
- 上下文变更、epoch/generation/row version 变化和过期时 fail-closed；
- 重复完成只有一个 Answer、Inbox 和 receipt；
- Answer、Inbox、final CAS 任一失败时事务回滚；
- legacy API 对 V4 envelope 的显式拒绝；
- migration `0024` 元数据和 Python 编译。

完整后端验证也已通过：`785` 项单测、FastAPI smoke、凭据边界、知识库、Provider redaction/cost 和备份合同 smoke，以及 `git diff --check`。

## G1 服务端 Answer 收据读取合同

在不改变公开 Echo 页面、不开启 V4 worker 和不将 Answer 正文复制进 Inbox 的前提下，后端新增 Owner-only 读取接口：

```text
GET /echo/delayed-replies/{userId}/{delayedReplyId}/answer
```

该接口仅从延迟回信聚合与私有 `echo_delayed_reply_answers` 读取结果；Inbox 继续只保存 `sourceAnswerId` 指针。它返回：

- `200 completed`：Answer 正文、稳定 answer ID、conversation/request/generation 与 context/citation/policy 收据；
- `409 echo_delayed_reply_answer_not_ready`：服务端尚未完成；
- `409 echo_delayed_reply_answer_reconcile_required`：聚合已完成但 Answer 缺失或不一致，必须进入诚实的 reconcile；
- `409 echo_delayed_reply_answer_legacy_unavailable`：旧协议记录不能伪装为 V4 结果；
- `404 echo_delayed_reply_not_found`：当前 Owner 没有该记录。

路径 Owner 校验、路由认证清单和真实 Postgres 左连接映射均有覆盖。读取合同不会启动本地时钟完成、Provider、通知或公开功能；iOS 仍保持本地 pending 状态，直到后续显式拉到已持久化的 Answer。

验证：Answer/Inbox 本地 gate `88` 项通过；完整后端验证 `785` 项通过。G2 隔离 Postgres smoke 已在部署后的容器镜像中执行并通过，详见下文。

## G1 iOS QA-only Answer 对账

iOS 已增加一个默认关闭的、只用于 Debug/UIQA 的服务端 Answer 对账路径。它不改变公开 Echo UI，也不会让本地到期时间、通知或 Inbox 指针伪造业务完成。

- 仅当启动参数包含 `DJEnableEchoDelayedReplyAnswerReconciliationQA` 时启用；Release 编译恒为关闭。
- 客户端通过 Owner-only `GET /echo/delayed-replies/{userId}/{delayedReplyId}/answer` 读取；本地会校验 ISO-8601 完成时间、`completed` 状态、reply generation、私有 Answer 正文、匹配的 receipt，以及 Inbox projection 必须保持 redacted。
- 只处理当前 account lease、resource owner、role context 和 operation ID 均匹配的 `.awaitingReplyDelivery` 记录；同一条待处理记录有单飞保护，生命周期重复触发不会发起并发对账。
- 对账成功时，先保存仅含 `sourceAnswerId` 的 Inbox 指针；只有保存成功后才清除本地 pending 记录。若本地 retire 失败，会回滚刚写入的 Inbox 指针。Answer 正文只进入当前对话记忆和 transcript，不复制到 Inbox。
- `409 echo_delayed_reply_answer_not_ready`、`409 echo_delayed_reply_answer_reconcile_required` 或其他读失败都会保留 `.awaitingReplyDelivery` 和本地 pending，不写 Inbox、不取消重试机会。
- 触发点仅限 QA 下的页面恢复、前台恢复、account scope 重新绑定和数字人上下文变更；日志只记录 privacy-safe 的延迟状态和 Answer ID，不记录正文。

相关 iOS 代码提交：

- `6671000 feat(v4): reconcile delayed Echo answers in QA`
- 本地 QA 开关补丁将在本状态证据提交中一并固化，避免单独检出 `6671000` 时丢失默认关闭边界。

验证：

```bash
git diff --check
xcodebuild -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build-for-testing
xcodebuild -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

以上静态检查、模拟器 `build-for-testing` 和无签名 iPhoneOS build 已通过。新增的 Answer contract / reconciliation 单测已随测试目标编译；实际 `xcodebuild test` 被现有 Scheme 的 simulator destination 解析为 generic placeholder 而无法启动，属于测试运行环境限制，不计作已执行的测试证据。

## G1 iOS Inbox 私有 Answer 读取与消息状态闭环

在提交 `272a1b5 feat(v4): read delayed Echo answers from inbox` 中，已将 G1 的 Inbox 指针读取收敛为下列边界：

- `EchoReplyMessageStore` 到达记录只新增 `sourceAnswerId`，不保存 Answer 正文；`InAppMessage.fromEchoReply` 显式标记 `metadataOnly=true`、`contentRedacted=true`。
- 重建同一 owner/account scoped store 后，Inbox 仍可恢复 `delayedReplyId + sourceAnswerId` 指针；错误账号、失效 lease、缺失指针或缺失 Answer ID 都 fail-closed。
- `EchoDelayedReplyInboxAnswerReader` 仅在 QA gate 启用时调用 Owner-only Answer 接口，并要求本地指针、服务端 Answer ID 和 receipt `sourceAnswerId` 三者完全一致；不一致不会把别的 Answer 展示为当前回信。
- 消息中心点击带 V4 指针的 Echo 回信时，QA 模式读取并展示私有 Answer；默认发布态、未配置后端或 legacy 指针仍沿用原有“进入回响”行为。读取失败只提示稍后重试，不以本地内容降级伪造答案。
- 既有 `MemoryArchiveRepository` 的非时间信件 read/archive 分支继续使用 account-scoped local message state，因此 Echo 指针的已读和归档状态会跨页面/重启恢复，且不会修改服务端 Answer 正文。

新增 gate：

```bash
Scripts/QA/product-v4/run-echo-delayed-reply-answer-inbox-gate.sh
```

它检查 source Answer pointer、正文脱敏、lease/owner fence、receipt 匹配、QA-only 打开路径、普通 Echo fallback、已读/归档持久化分支和对应测试名称。结果通过。

验证补充：模拟器 `build-for-testing` 和无签名 iPhoneOS build 通过，`git diff --check` 通过。由于 Scheme 只暴露 generic simulator placeholder，实际 XCTest/UIQA 运行未能启动，仍不能作为 UI 交互运行证据。

## G2 生产部署与隔离 Postgres 证据

后端已推送并部署到服务器，部署代码基线为：

```text
main@53b420c feat(v4): add delayed Echo reply answer read contract
```

部署只包含 additive migration `0024_echo_delayed_reply_answer_completion`：新增私有 Answer 表及索引，不包含删表、数据重写或公开功能开关。服务器执行结果：

1. `migrate_db.py --dry-run --build-id 53b420c`：仅发现 `0024` 待执行；
2. `migrate_db.py --apply --build-id 53b420c`：成功应用 `0024`；
3. `migrate_db.py --verify --build-id 53b420c`：schema head 为 `0024`、状态 `ready`；
4. 重新创建 API 容器后，容器 health 为 `healthy`；
5. 公网 `https://dreamjourney-api.liftora.cn/ready` 返回 `ready`，database/schema/auth 组件均为 `ready`；
6. 在部署镜像中运行 `scripts/run-backend-echo-delayed-reply-atomic-completion-postgres-smoke.sh`：通过。

该 smoke 每次创建并清理独立临时数据库，覆盖：

- 两个并发完成者只有一个 `completed`、一个 `already_terminal`；
- 恰有一份私有 Answer、一份 owner Inbox 投影和一份 business receipt；
- Inbox 与 receipt 不保存 Answer 正文；
- legacy dispatcher 不会认领 V4 reply；
- mailbox 写入失败时，Answer、Inbox 和 aggregate 变化整体回滚。

这证明的是迁移、持久化和原子完成合同已经部署；它不证明 worker 已启用、模型 Provider 已生成真实答案、用户已在真机完成 QA 流程，默认发布态仍保持关闭。

## 尚未声明完成

- typed scheduler/worker、真实 Provider generation、accepted/query/unknown reconcile 尚未启用；这些属于 `WI-S1-02-07` 及后续 worker gate。
- iOS 已完成 QA-only 的 server Answer 拉取、本地 pending 对账、Inbox private Answer pointer、已读/归档持久化复用和点击读取；可重复的 simulator 交互运行证据仍受当前 Scheme destination 环境阻断。
- G3 真实模型 Provider 质量/可用性与 G4 产品/真机验收均未关闭；不能表述为“线上延迟回信已公开完成”。

## 后续顺序

1. 保持 `WI-S1-02-06` default-off 和 QA-only 边界，不启用 worker 或 Provider 生成。
2. 进入 `WI-S1-02-07` 的 G0：盘点现有模型、Voice/TTS、Digital Human、对象与通知 Provider 调用，建立 stable request / accepted / unknown / query-reconcile 的最小合同。
3. 等 iOS Scheme 暴露可运行 simulator destination 后，补充真实 Inbox 点击/UIQA 证据；这不阻塞下一项 G0 合同工作。
