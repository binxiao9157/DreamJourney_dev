# WI-S0-07-02 Append-Only Evidence Sink 与 Retention Class

日期：2026-07-16  
Work Item：`WI-S0-07-02`  
状态：`INTERNAL_READY / SHADOW_WRITER_READY / G2_PARTIAL / EXTERNAL_BLOCKED`  
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

## 未关闭边界

- 当前项目还没有 `WI-S0-04` 统一 versioned migrator；本轮只能使用现有 `init_schema` 做 additive 建表，不能宣称正式 migration/rollback gate 完成。
- 真实 Postgres 写入/读取和 API 重启连续性必须部署后取得 G2 回执。
- backup/isolated restore/replay 依赖 `WI-S0-04`，本轮不伪造。
- `EVIDENCE_ROLLOUT_RETENTION_DAYS=30` 是可配置的临时技术基线，不代表 Privacy/Legal 已批准正式 retention policy。
- 只有 ReleasePolicy shadow writer 接入；credential rotation、delete/cutover 等高风险 mandatory writer 要等 sink failure denominator 和 S0-04 readiness 完成。
- iOS Echo evidence 继续是 AccountLease 隔离的短期 QA cache，不上传、不成为长期 Authority。

## 下一步

1. 分别提交后端和 iOS QA/状态变更。
2. 部署后端，在生产 Postgres 运行 before-restart smoke。
3. 重启 API 后用 baseline 运行 after-restart smoke。
4. 更新本 manifest 的 G2 部署回执；保持 `EXTERNAL_BLOCKED`，直到 S0-04 backup/restore 和 Privacy/Legal retention 批准完成。
