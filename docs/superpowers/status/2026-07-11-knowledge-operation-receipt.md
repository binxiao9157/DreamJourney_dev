# 知识操作凭据与冲突恢复完成状态

日期：2026-07-11

## 结论

Task 17 已完成非真机代码闭环。后端不再只按 `(userId, operationId)` 静默去重，而是用权威 operation receipt 校验稳定业务意图；iOS 不再无限重放 payload-conflict pending 或阻塞治理队列。公开 UI、Stitch 页面和 Echo 文案未改变。

## 后端合同

- `kb_operation_receipts` 独立保存 `operationKind`、schema version、canonical payload hash 和权威结果摘要。
- 指纹覆盖知识同步、V1/V2 mutation、governance action 和 Archive source delete，排除 `baseRevision`。
- 相同 kind/hash 返回 duplicate；不同 kind/hash 返回 409：

```json
{
  "detail": {
    "code": "knowledgeOperationPayloadConflict",
    "operationId": "stable-operation-id"
  }
}
```

- 新操作返回 `operationPayloadVerified=true`；legacy `kb_changes` 重放返回 `false`。
- API 和日志不返回 payload hash 或知识正文。
- Postgres receipt 与 snapshot、change、Archive delete 使用同一 transaction；账号 purge 同步清理 receipt。
- Archive 即使没有命中知识来源，也能原样幂等重放；同一 ID 不能删除另一条档案。

## iOS 恢复语义

- `BackendErrorContext` 保留稳定 `code`、`operationId` 和用户可读 detail。
- 普通知识 mutation 冲突：删除 poisoned pending，保留本地图谱，刷新权威 base 后重新计算 delta 和 operation ID。
- Governance 第一次冲突：原子替换 outbox operation ID、保留 action/identity/completion，并刷新重试。
- Governance 第二次冲突：写入 `quarantineReason=knowledgeOperationPayloadConflict`；dispatcher 跳过隔离项并继续后续动作。
- 同 operation ID/同 action 重复 enqueue 是 no-op；同 ID/不同 action 在发网前拒绝。
- 旧 outbox JSON 缺少 recovery/quarantine 字段时仍可读取。

## QA

日常 release regression 固定执行：

- `run-knowledge-governance-model-smoke.sh`
- `run-knowledge-governance-outbox-model-smoke.sh`
- `run-knowledge-governance-client-check.sh`
- `run-knowledge-governance-coordinator-check.sh`
- `knowledge-governance-release-boundary-check.swift`

跨仓完整门禁：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_BACKEND_KNOWLEDGE_GOVERNANCE_SOURCE_CASCADE_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-knowledge-governance-gate.sh
```

## 发布边界

- 本轮没有公开知识治理页面或新增 Tab。
- 本轮没有部署后端、执行线上 schema migration 或真机验证。
- 下一步生产验收是部署后在真实 Postgres 跑 receipt conflict、Archive no-cascade replay 和 purge smoke。
- Change feed pagination/compaction、历史 canonical source migration 和公开治理体验仍是后续任务。

## 本轮验证

- 后端全量：250 tests、compile、FastAPI、knowledge delta/v2/evidence smoke 通过。
- 跨仓治理：224 tests 与 iOS model/client/outbox/coordinator/merge/context checks 通过。
- Release regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task17-knowledge-operation-receipt/report.md`。
- Simulator workspace Debug build：通过。
- generic iPhoneOS arm64 build：通过，使用本地 Bundle ID override `com.yxj.dreamjourney.app`。
- Closure ledger：`L20260711-100251` 已关闭。
