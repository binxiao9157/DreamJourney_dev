# WI-S1-02-09 Worker-Loss Evidence

日期：2026-07-20

## 本次 G2 子闭环

后端 `main@19bf02f` 已新增 `0028_async_effect_worker_loss_observations`，用于持久化
过期 worker lease 的 value-free 聚合证据。记录只包含过期数量、任务类型计数、最久年龄、
哈希后的 worker 数量和观察状态；不保存 job/operation/owner/vault/resource/payload/provider
坐标或原始 worker ID。

`preview_expired_leases()` 只读查询过期 `leased` 行。它不会 claim、重试、改写 attempt、
启动 worker/scheduler 或调用 Provider。观察记录为 append-only；相同 observation 可幂等
去重，不同证据复用同一 ID 会失败关闭。

## 验证与部署

本地后端：

```text
worker-loss G0/G2 contract gate: 23 tests passed
scripts/verify_backend.sh: 839 unit tests passed
FastAPI smoke / existing gates / git diff --check: passed
```

线上 `miao-server`：

```text
server checkout: main@19bf02f
migration: 0028 applied and verified
API /ready: database/schema/auth/incident ready
deployed disposable Postgres smoke: passed
```

线上 smoke 覆盖并发幂等、append-only update/delete 拒绝、重载一致性、原始坐标不泄露，
以及 job/attempt/operation/outbox/provider 状态不被观察动作改写。它创建并删除独立测试库，
不触碰生产业务行或服务器 `.env`/`.env.backup*`。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过 | dead-letter admission、owner authorization、restore fence、readiness 和 worker-loss observation 合同已存在。 |
| G2 | 范围内通过 | durable admission、inert replay authority、worker-loss evidence 均已在部署 Postgres 隔离 smoke 验证。 |
| G3 | 未开始 | Provider query/reconcile、真实 replay 和运营批准均未启用。 |

## 下一子闭环

仅进入 `WI-S1-02-09-G3-PROVIDER-QUERY-AND-OPERATIONS-BASELINE`：先定义 Provider 查询和
运营证据的无副作用合同，再讨论任何真实 replay。不得借本次 worker-loss 证据开启 worker、
Provider 或公开入口。
