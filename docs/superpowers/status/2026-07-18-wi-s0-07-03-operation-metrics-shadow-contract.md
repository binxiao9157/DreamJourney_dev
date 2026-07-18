# WI-S0-07-03 Request / Operation / Attempt 分母与 Readiness Metrics

日期：2026-07-18

Work Item：`WI-S0-07-03`

状态：`INTERNAL_READY / G0_VERIFIED / SHADOW_METRICS_NOT_DEPLOYED / G2_MISSING / EXTERNAL_BLOCKED`

Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`

Authority lock：`OPERATIONS_EVIDENCE`

Lease：`LOCAL_IMPLEMENTATION_ONLY`（生成式 Registry 仍保持 `UNHELD/PLANNED`，不自我提升）

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
- `PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh` 通过：后端 unittest `551` 项、credential boundary smoke、FastAPI smoke、知识库 smoke、Postgres backup contract 与 `git diff --check` 均通过。
- 后端实现已提交：`DreamJourneyBackend@e2808e1`（尚待线上部署）。

## 未关闭边界

- 尚未部署到线上 Postgres，`G2` 仍为 `MISSING`；不能据此声明生产分母、覆盖率、容量或 SLO 达标。
- 该 middleware 只覆盖已登记的认证路由。完整路由/worker 覆盖和与业务 receipt 的 production 对账，需在部署后分阶段扩大。
- 仅有近窗口 summary；没有长期 retention、Privacy/Legal 批准或 Operations owner 的生产阈值。
- `skipped/unknown/missing/expired` 均不得用于 PASS；本实现保持 `sloClaimAllowed=false`。

## 部署前配置与下一步

1. 在服务器私密 `.env` 写入独立、随机、至少 32 字节的 `OPERATIONS_EVIDENCE_HMAC_KEY`；不得复用 identity、provider、API 或 session credential。
2. 推送后端提交并按正式 Docker Compose runbook 重建 API，再执行线上 Postgres shadow smoke。
3. 先读取实际窗口的 attempt/operation/route coverage，再决定哪些低风险路由或 worker 可以扩大 shadow 覆盖；不得直接转为 enforce 或发布 gate。
4. 保持当前 handoff 的 `WI-S0-05-01-G2` 不变，直到 rights migration 的线上部署证据完成。
