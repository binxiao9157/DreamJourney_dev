# WI-S0-07-02 Append-Only Evidence Sink 与 Retention Class

日期：2026-07-16  
Work Item：`WI-S0-07-02`  
状态：`INTERNAL_READY / SHADOW_WRITER_DEPLOYED / G2_POSTGRES_VERIFIED / EXTERNAL_BLOCKED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`  
Authority lock：`OPERATIONS_EVIDENCE`  
Lease：`ACTIVE`

## 已实现

- 后端新增 `evidence_events` additive schema：event/operation/type/time 索引、16KB payload 上限、schema version、payload hash、retention class、expiry 和 legal hold。
- 数据库 trigger 禁止事件 `UPDATE`；唯一 `eventId` 的相同 hash 重放返回 deduplicated，不同 hash/retention metadata 视为篡改并拒绝。
- retention class 固定为 `rolloutObservation/operationalTemporary/rightsAudit/incidentAudit/providerCost/legalHold`，不允许业务临时造自由文本类型。
- 专用 retention 方法只删除已到期且非 hold 事件，并返回不含原始 ID 的哈希回执；普通账号 purge 不访问 evidence 表。
- InMemory 与 Postgres store 都提供 append/query/retention port。
- ReleasePolicy 作为首个低风险 shadow writer；`/ops/release-policy/observations` 保持 system-only/no-store，并优先读取持久化 summary。
- 新增两阶段 deployed smoke：先写 anchor，再重启 API，用 baseline 验证 event denominator 与 window start 未重置。
- release handoff 新增 `RUN_BACKEND_EVIDENCE_PERSISTENCE_SMOKE=1`，默认普通回归不访问线上环境。

## 验证

- append、duplicate、tamper、未知 retention、无时区 expiry、TTL/hold、账号 purge 隔离通过。
- Postgres SQL contract、repository 重建读取和 aggregate summary 通过。
- ReleasePolicy recorder 重建后从 store 恢复 typed/legacy 计数通过。
- 后端 `STORE_BACKEND=memory` 全量 `352` 项测试通过。
- backend smoke Python compile、shell syntax、iOS release QA package 与 `git diff --check` 通过。
- 后端提交 `39dc469` 已推送并部署，服务器运行 `production/postgres`。
- before-restart smoke：event count `1`，window start `2026-07-16T12:27:40.735577Z`，sink/source failure 均为 `0`。
- API 重启后的 after-restart smoke：event count `2`，原 anchor 仍可查询，window start 未变化。
- 真实 Postgres 直接 `UPDATE evidence_events` 被 `evidence_events_no_update` trigger 拒绝。
- ReleasePolicy deployed smoke 在 persistent source 下通过，常驻 canary 仍为 `familyManagement`，kill switch 为空。

## 未关闭边界

- 当前项目还没有 `WI-S0-04` 统一 versioned migrator；本轮只能使用现有 `init_schema` 做 additive 建表，不能宣称正式 migration/rollback gate 完成。
- backup/isolated restore/replay 依赖 `WI-S0-04`，本轮不伪造。
- `EVIDENCE_ROLLOUT_RETENTION_DAYS=30` 是可配置的临时技术基线，不代表 Privacy/Legal 已批准正式 retention policy。
- 只有 ReleasePolicy shadow writer 接入；credential rotation、delete/cutover 等高风险 mandatory writer 要等 sink failure denominator 和 S0-04 readiness 完成。
- iOS Echo evidence 继续是 AccountLease 隔离的短期 QA cache，不上传、不成为长期 Authority。

## 下一步

1. 保持 ReleasePolicy shadow writer 运行，`WI-S0-06-08` 的 168 小时零使用窗口从持久化起点重新计算。
2. 进入 `WI-S0-07-03` 前先核对 S0-04 readiness；可先做不切 Authority 的 request/operation/attempt schema 与 shadow denominator。
3. 保持 `EXTERNAL_BLOCKED`，直到 S0-04 backup/isolated restore 和 Privacy/Legal retention 批准完成。
