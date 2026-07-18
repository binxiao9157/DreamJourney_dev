# WI-S0-07-03 Request / Operation / Attempt 分母与 Readiness Metrics

日期：2026-07-18

Work Item：`WI-S0-07-03`

状态：`INTERNAL_READY / G0_G2_VERIFIED / SHADOW_METRICS_DEPLOYED / EXTERNAL_RETENTION_OPS_REVIEW_OPEN`

Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`

Authority lock：`OPERATIONS_EVIDENCE`

Lease：`IMPLEMENTATION_DEPLOYED`（生成式 Registry 仍保持 `UNHELD/PLANNED`，不自我提升）

## 本轮完成

- 新增 append-only `operationMetric` evidence envelope，区分 request、logical operation 和 attempt；状态覆盖 `succeeded/failed/timedOut/cancelled/deduplicated/unknown/feedbackMissing`。
- 重试只在同一 logical operation 已有多次持久化 attempt 时计数；单个 `attempt=2` 不再被误报为 retry。
- 调用方传入的 request/operation 标识只接受 UUIDv4；任意文本、手机号、邮箱或业务 ID 都不会进入 evidence。所有持久化标识使用专用 HMAC，不写入原始值。
- 新增 `OPERATIONS_EVIDENCE_HMAC_KEY` 配置。未配置时只使用进程临时 HMAC，仍可 shadow 观测，但跨 API 重启不能安全关联 retry，因此不能作为上线 SLO 基线。
- 已在已登记认证路由外层接入非阻塞 shadow middleware；sink 写入失败、认证拒绝或普通路由返回均不改变原业务响应。
- InMemory 与 Postgres summary 均按最新窗口聚合，Postgres 不再错误读取最早 5,000 条样本。
- `/ops/release-policy/observations` 仅返回机器可读聚合计数，不返回 event、route 名称、request/operation 标识或原始输入。

## 验证

- request / operation / attempt 分母、同 operation retry、重复、取消、超时、unknown、missing feedback 的聚合 contract 通过。
- feedback 明确缺失时，即使 HTTP 返回 2xx，也记录为 `feedbackMissing`，不会计为成功。
- 非 UUIDv4 的外部标识不会构造可枚举摘要，也不会制造伪 retry。
- evidence sink 故障仍返回原业务 HTTP 响应；认证拒绝仍被记录为失败 attempt。
- Postgres 最新窗口、TTL 可见性、stable ordering、持久化重建 summary contract 通过。
- `PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh` 通过：后端 unittest `552` 项、credential boundary smoke、FastAPI smoke、知识库 smoke、Postgres backup contract 与 `git diff --check` 均通过。
- 后端实现已提交并部署：`DreamJourneyBackend@8b63333`。部署包含 `e2808e1` 的 shadow metrics、`15914bd` 的 Postgres event-type 兼容迁移，以及线上 smoke 脚本。
- 线上 Postgres 已应用 `0007_operation_metric_evidence`。该迁移仅扩展 `evidence_events.event_type` 约束以接受 append-only 的 `operationMetric` 事件；业务数据不回填、不删除。
- 部署后 `/ready` 健康，schema verify 到 `0007`；真实 Postgres operation metrics smoke 通过：persistent sink、configured HMAC、`feedbackMissing` 观测、无原始 client identifier 泄露，并保持 `sloClaimAllowed=false`。
- `scripts/backend-db-migration-postgres-smoke.py` 已在服务器通过，覆盖 fresh DB、旧库升级、并发 apply/skip、legacy conflict quarantine、restart persistence 和 `0007` migration head。

## 已发现并修复的部署兼容性

- 初次部署 `e2808e1` 后，旧生产 schema 的 `evidence_events_event_type_check` 不接受 `operationMetric`，导致 shadow sink 非阻塞失败而业务响应保持正常。这说明 G2 不能只看 HTTP 成功。
- `15914bd` 新增 `0007_operation_metric_evidence` 后，已用真实 Postgres migration smoke 和部署后 operation metrics smoke 验证持久化写入与 summary。该兼容性缺口已关闭。

## 未关闭边界

- 该 middleware 只覆盖已登记的认证路由。完整路由/worker 覆盖和与业务 receipt 的 production 对账，需在部署后分阶段扩大。
- 仅有近窗口 summary；没有长期 retention、Privacy/Legal 批准或 Operations owner 的生产阈值。
- `skipped/unknown/missing/expired` 均不得用于 PASS；本实现保持 `sloClaimAllowed=false`。

## 线上验证与下一步

1. 服务器私密 `.env` 已配置独立的 `OPERATIONS_EVIDENCE_HMAC_KEY`；不得复用 identity、provider、API 或 session credential。
2. 线上复验使用 `BACKEND_BASE_URL`、`BACKEND_API_TOKEN` 执行 `scripts/run-backend-operation-metrics-deployed-smoke.sh`；该脚本只输出聚合断言，不输出 token、原始 request ID 或 event 明细。
3. 先读取实际窗口的 attempt/operation/route coverage，再决定哪些低风险路由或 worker 可以扩大 shadow 覆盖；不得直接转为 enforce 或发布 gate。
4. 当前 handoff 仍保持 `WI-S0-05-01-G2`：Rights migration 已部署，但 Rights 的 concurrent/idempotency/rollback/restart/cross-account 线上生命周期 smoke 尚未闭合。
