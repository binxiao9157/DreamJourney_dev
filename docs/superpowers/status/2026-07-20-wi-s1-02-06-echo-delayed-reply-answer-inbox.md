# WI-S1-02-06 Echo 延迟回信 Answer、Inbox 与 Receipt G0 证据

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

后端本地提交：`de6bc7d feat(v4): close delayed Echo reply receipt contract`。

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

结果：`86` 项相关测试通过，覆盖：

- V4 immutable envelope 与稳定目标键；
- 不到期不生成效果；
- 本地/legacy dispatcher 双路径隔离；
- Answer 正文不进入 Inbox、receipt 或 value-free trace；
- 上下文变更、epoch/generation/row version 变化和过期时 fail-closed；
- 重复完成只有一个 Answer、Inbox 和 receipt；
- Answer、Inbox、final CAS 任一失败时事务回滚；
- legacy API 对 V4 envelope 的显式拒绝；
- migration `0024` 元数据和 Python 编译。

完整后端验证也已通过：`783` 项单测、FastAPI smoke、凭据边界、知识库、Provider redaction/cost 和备份合同 smoke，以及 `git diff --check`。

## 尚未声明完成

- 未运行实际 Postgres 原子并发 smoke：当前本地 shell 未配置 `DATABASE_URL`。脚本会创建并清理隔离临时数据库，待 G2 部署/运维阶段执行。
- 未启用 typed scheduler/worker、Provider generation、accepted/query/unknown reconcile；这属于 `WI-S1-02-07` 及其后续 worker gate。
- 未实现 iOS 的 server Answer 拉取、重启后的已读/归档/点击回响闭环，属于本工作项 G1。
- 未推送或部署后端，因此不能表述为线上回信完成。

## 后续顺序

1. 在不改变公开 UI 的前提下进入 G1：iOS 只消费服务端 Answer/receipt，处理重启、已读、归档与点击回响。
2. 进入 G2 前，先推送 `de6bc7d`，部署 migration `0024`，再运行隔离 Postgres smoke：

```bash
DATABASE_URL='...' \
scripts/run-backend-echo-delayed-reply-atomic-completion-postgres-smoke.sh
```

3. Provider 真实调用仍必须通过 `WI-S1-02-07` 的 stable request/unknown reconcile，禁止在当前服务中直接重试或把通知当作业务完成。
