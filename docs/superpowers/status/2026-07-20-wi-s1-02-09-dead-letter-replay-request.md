# WI-S1-02-09 Dead-Letter Replay Request 证据

日期：2026-07-20

## 本次 G2 子闭环

后端 `main@9ade1ab` 已新增 `0027_async_effect_dead_letter_replay_requests` 与
`PostgresAsyncEffectDeadLetterReplayRequestRepository`。它只持久化经过 owner
授权、恢复 checkpoint 围栏和新 recovery receipt 校验的 replay request 证据。

请求记录为 append-only，且同一个 dead letter 最多一条。重复相同请求返回
`deduplicated`；更换授权 receipt、restore checkpoint 或 owner/vault/epoch 时失败
关闭。记录仅保存 opaque ID 和 hash，不保存 payload、原始 authorization receipt
或 restore ID。

## 明确未做的事情

- 不把终态 `failed/unknown/blocked` job 重新入队；
- 不新增 worker attempt、outbox 或 Provider effect；
- 不启用 worker、scheduler、API/UI 或公开开关；
- 不把恢复前的授权直接用于恢复后的重放。

因此本次是“重放 authority evidence 已可持久化”，不是“真实 replay 已可执行”。

## 验证与部署

本地后端：

```text
replay-request contract gate: 14 tests passed
scripts/verify_backend.sh: 830 unit tests passed
FastAPI smoke / existing gates / git diff --check: passed
```

线上 `miao-server`：

```text
server checkout: main@9ade1ab
migration: 0027 applied and verified
API /ready: database/schema/auth/incident ready
deployed disposable Postgres smoke: passed
```

线上 smoke 覆盖并发幂等、变更授权拒绝、旧 recovery receipt 拒绝、append-only
触发器、重载一致性，以及 terminal job/attempt 不被 request 改写。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过 | dead-letter admission、owner authorization、restore fence、readiness/evidence 合同已存在。 |
| G2 | 部分通过 | admission 与 inert replay request 均已在部署 Postgres 隔离 smoke 验证；worker-loss durable evidence 仍待完成。 |
| G3 | 未开始 | Provider query/reconcile 与真实 replay 没有启用。 |

## 下一子闭环

补 worker-loss 的只读、value-free 观察与持久化证据；仅报告过期 lease，不自动认领、
重试、执行或调用 Provider。
