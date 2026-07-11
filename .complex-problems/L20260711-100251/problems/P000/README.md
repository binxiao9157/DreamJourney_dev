# Task 17：P1 Knowledge Operation Receipt 与冲突恢复

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_17_p1-knowledge-operation-payload-hash.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 17：P1 Knowledge Operation Receipt 与冲突恢复

## 目标

为知识同步、知识治理和 Archive 来源级联建立服务端权威的 operation receipt，禁止同一用户下同一 `operationId` 被不同语义 payload 静默复用；iOS 对普通 mutation 可恢复，对治理冲突进入可审计隔离态且不阻塞后续队列。

## 产品与兼容边界

- receipt 只用于幂等、审计和故障恢复，不保存 Echo 文本或用户可见正文。
- payload hash 由后端根据规范化语义生成，iOS 不上传、不展示 hash。
- 指纹覆盖 `operationKind + schemaVersion + normalizedPayload`，排除 `baseRevision`，允许 revision conflict 后原业务请求稳定重试。
- 新操作持久化 operation kind、payload hash、结果摘要和 revision；相同 kind/hash 重放为 duplicate，不同 kind/hash 返回稳定 409。
- 旧 `kb_changes` 没有可信原始 payload，继续保持 legacy duplicate 兼容并返回 `operationPayloadVerified=false`，不伪造历史 hash。
- Archive 无知识级联删除也必须有 receipt，保证原样重试幂等，并禁止同一 operation ID 删除另一条档案。
- 不改变公开 Stitch UI，不做真机、线上部署、历史 hash 回填或 change-feed compaction。

## 后端实现

- 新增 canonical JSON、SHA-256 operation fingerprint 和 `KnowledgeOperationPayloadConflict`。
- Memory/Postgres 增加独立 `kb_operation_receipts`，与 snapshot、change feed、Archive 删除保持同一事务边界。
- 覆盖 operation kind：
  - `knowledgeSyncV1`
  - `knowledgeMutationV1`
  - `knowledgeMutationV2`
  - `knowledgeGovernanceV1`
  - `archiveSourceDeleteV1`
- `/kb/sync`、`/kb/mutations`、`/kb/governance/actions` 和 Archive delete 统一映射冲突为：

```json
{
  "code": "knowledgeOperationPayloadConflict",
  "operationId": "..."
}
```

- 响应只公开 `operationPayloadVerified`，不公开 payload hash。
- Governance 在依赖 snapshot 构造 mutation 前先检查规范化 action receipt，保证 `deleteSource` 原样重放不会退化成 404。
- 账号 purge 同步清理 receipt。

## iOS 实现

- Backend client 结构化识别 `knowledgeRevisionConflict` 与 `knowledgeOperationPayloadConflict`，Coordinator 不再依赖模糊字符串分支。
- 普通 mutation payload conflict：删除 poisoned pending，保留本地图谱意图，刷新权威 change feed，并用新 operation ID 重建 delta。
- Governance payload conflict：第一次旋转 operation ID 并刷新重试；再次冲突进入 quarantine，停止自动重放，但不阻塞后续治理动作。
- Governance outbox 增加向后兼容的 recovery/quarantine 元数据与原子 replace；相同 ID、不同 action 在发网前本地拒绝。
- operation ID 在写入、查找和删除时统一规范化。
- 仅增加 QA/日志证据，不改变公开产品界面。

## 验收清单

- [ ] 后端 fingerprint helper、错误类型与 operation receipt。
- [ ] Memory/Postgres 新记录、legacy 兼容、事务回滚和 purge。
- [ ] 相同 payload 重放、不同 payload/schema/kind 冲突、仅 baseRevision 改变仍幂等。
- [ ] Governance 原 action 重放与不同 action 冲突。
- [ ] Archive 无级联删除原样重放与不同 item 冲突。
- [ ] iOS 结构化错误消费和普通 mutation 恢复。
- [ ] Governance rotate/quarantine，且后续队列可继续。
- [ ] Outbox Codable 向后兼容和 operation ID 规范化。
- [ ] QA gate、release regression、知识架构与状态文档更新。
- [ ] 后端全量测试、`git diff --check`、iOS Simulator/generic iPhoneOS 构建通过。
- [ ] 后端和 iOS 分仓提交，不推送、不部署。

## 非目标

- 历史 operation hash 离线回填。
- change feed 压缩和服务端长期归档。
- 公开治理 UI。
- 真机验证、线上部署和生产数据库迁移执行。

## 成功标准

- 新 operation ID 不会把不同 kind/payload 静默当成 duplicate。
- 相同语义 payload 即使 base revision 改变也能安全重放。
- legacy 操作继续兼容，但明确为未验证。
- iOS 不会永久重放 poisoned item，治理隔离项不阻塞后续队列。
- 现有知识、治理、release QA 与非真机构建全部通过。


## Success Criteria

- 新 operation ID 不会把不同 kind/payload 静默当成 duplicate。
- 相同语义 payload 即使 base revision 改变也能安全重放。
- legacy 操作继续兼容，但明确为未验证。
- iOS 不会永久重放 poisoned item，治理隔离项不阻塞后续队列。
- 现有知识、治理、release QA 与非真机构建全部通过。
