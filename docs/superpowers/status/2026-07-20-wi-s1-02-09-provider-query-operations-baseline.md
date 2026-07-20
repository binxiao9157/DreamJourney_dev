# WI-S1-02-09 Provider 查询运维基线

日期：2026-07-20

## 本次闭环

后端 `main@1d87023` 已完成 `WI-S1-02-09` 的内部 Provider 查询运维基线。

新增的只读报告会按 `provider + capability` 聚合 effective state 仍为 `unknown` 的
Provider effect，并区分：待查询、人工复核和冲突复核。输出不包含 effect/operation、
owner、vault、resource、请求正文、上游 request ID、媒体、receipt 原值或 credential。

默认关闭的 async-effect worker `shadow_once` 也会消费这一摘要；报告中固定声明：

- `providerQueryExecutionEnabled=false`
- `automaticReconciliationEnabled=false`
- `replayEnabled=false`

因此它只能帮助运营识别待处理分母，不能查询 Provider、重放 effect、领取 job 或改变
receipt/projection。

## 验证与部署

本地后端：

```text
provider-query operations G0 gate: 27 tests passed
scripts/verify_backend.sh: 844 unit tests passed
FastAPI smoke / existing gates / git diff --check: passed
```

线上 `miao-server`：

```text
server checkout: main@1d87023
migration head: 0028 applied and verified (no new migration)
API /ready: database/schema/auth/incident ready
deployed disposable Postgres smoke: passed
```

线上 smoke 使用独立测试库插入两个 synthetic unknown receipt，读取运维摘要后确认
effect、receipt 和 reconciliation projection 计数未改变；不调用真实 Provider，不触碰
生产业务行或服务器 `.env`/`.env.backup*`。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 范围内通过 | 只读合同、redaction、disabled execution、worker shadow 和单元测试已验证。 |
| G2 | 范围内通过 | 部署 API 容器的 disposable Postgres smoke 已验证只读行为。 |
| G3 | 外部门阻断 | 尚无真实 Provider query adapter、受保护 lookup reference、查询 credential、授权/审计/rollout 批准和控制台回执。 |

`WI-S1-02-09` 不因 G3 外部门而声称生产完成。真实查询或 replay 仍必须另行通过 Provider
和 Operations gate；当前任务自动转入不依赖该外部门的 `WI-S1-02-10` 静态盘点子切片。
