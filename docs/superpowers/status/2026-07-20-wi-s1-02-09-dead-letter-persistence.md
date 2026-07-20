# WI-S1-02-09 Dead-Letter 持久化证据

日期：2026-07-20

## 本次 G2 子闭环

本次完成 `WI-S1-02-09` 的首个 G2 子闭环：将已通过 G0 的 value-free
dead-letter admission 写入 Postgres，同时不改变终态 job，也不启动 worker、
scheduler 或 Provider replay。

后端提交：

```text
main@fe43577 feat(v4): persist async effect dead letters
```

核心实现：

1. additive migration `0026` 为 `async_effects.dead_letters` 增加
   `last_receipt_hash`，补齐恢复 admission 所需的最后一条 value-free receipt
   坐标。
2. `PostgresAsyncEffectDeadLetterRepository` 必须在当前 UoW 内锁定并核验
   job、operation、outbox 的 owner/vault/resource/epoch/stable key/payload hash、
   attempt 与 `max_attempts`。
3. 仅终态 `failed`、`unknown`、`blocked` 且 admission 为 `open` 时可写入；同一
   `(job_id, attempt)` 重复写入只返回 `deduplicated`，证据不允许覆盖。
4. 持久化不会把 job 改回 `pending/retryWait`，不会新增 attempt/outbox，不会执行
   replay，也不会调用 Provider。

## 验证与部署

本地：

```text
dead-letter persistence G2 contract gate: 8 tests passed
scripts/verify_backend.sh: 825 unit tests passed
FastAPI smoke / existing contract gates / git diff --check: passed
```

服务器：

```text
server checkout: main@fe43577
migration: 0026 applied and verified, schema status=ready
API /ready: database/schema/auth/incident all ready
deployed disposable Postgres smoke: passed
```

隔离 smoke 只创建并删除临时数据库，覆盖 terminal blocked job admission、并发
幂等、证据冲突拒绝、UoW rollback，以及“不重新入队/不新增 attempt”。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过 | admission、授权/恢复 replay、readiness/evidence mapping 的合同已存在。 |
| G2 | 部分通过 | dead-letter admission 已持久化并完成线上隔离 Postgres 验证。授权 replay request、worker-loss/rolling deploy 与恢复演练仍未完成。 |
| G3 | 未开始 | Provider query/reconcile 与真实执行仍未启用。 |

## 下一子闭环

实现 inert 的 durable replay-request 记录与 worker-loss 证据：它只能保存已授权、
已恢复校验的请求，不得修改终态 job 或执行重放；实际 worker/Provider 仍保持关闭。
