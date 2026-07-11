# Task 19：P1 Canonical Knowledge Source Identity 与历史来源审计

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_19_p1-canonical-knowledge-source-identity.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 19：P1 Canonical Knowledge Source Identity 与历史来源审计

## 目标

停止继续生成含义模糊的知识来源引用，并让后端能只读审计历史来源状态。新对话知识必须引用精确的用户 turn，新对话照片必须引用独立照片来源，档案来源继续使用 `memoryArchiveItem + archiveItem.id`。历史记录本轮只分类和预览，不自动改写生产数据。

## 审计结论

- 旧 `archiveImageAnalysis + session-*` 来自 `AIRecordingViewController` 的对话照片，不是记忆档案馆条目，不能迁成 `memoryArchiveItem`。
- 当前 iOS 本地提取使用 `conversationSession + session-*`，而后端 proposal、privacy redaction 和测试使用 `conversationTurn`，来源口径不一致。
- Archive 新照片分析只更新 `MemoryArchiveItem`，Echo 直接消费档案合同；当前没有把该分析结果写入 KBLite，因此不能凭 session 猜测 Archive item ID。

## Canonical 合同

- 对话文字证据：`conversationTurn + session-{sessionId}:turn-{turnIndex}`。
- 对话照片证据：`conversationPhoto + photo-{stableAssetId}`，只使用文件名中的稳定 UUID，不上传本地绝对路径。
- 记忆档案馆证据：`memoryArchiveItem + archiveItem.id`。
- 旧 `conversationSession`、`archiveImageAnalysis` 保持可读，但标记为 legacy/ambiguous；本轮不自动升级。
- source title 由服务端/iOS canonical 表生成，客户端自带 title 不作为可信正文。

## 后端实现

- V2 proposal 按经过证据校验的 `sessionId + sourceTurnIndices` 为每个实体生成精确 `conversationTurn` refs，不复用请求级模糊 ref。
- 新增纯 `KnowledgeSourceRefAudit`，统计 canonical、legacy、unknown、可确定迁移和歧义数量，不记录实体正文。
- 新增 owner-bound 只读 audit/preview API；返回 revision、计数和建议策略，不返回 graph 或 source ID。
- privacy、proposal、Context/QA 的 source kind/title 口径统一。
- 不新增 apply migration API，不执行生产数据改写。

## iOS 实现

- 本地 quick extraction 按实体 `sourceTurnIndices` 生成精确 `conversationTurn` refs。
- 后端 extraction request 声明 canonical source contract，不再发送 `conversationSession` 作为权威证据。
- 对话照片 ingest 接收稳定 photo asset ID，生成 `conversationPhoto` ref；不再新增 `archiveImageAnalysis`。
- 增加 source audit typed consumer/纯模型检查；不改变公开 UI。
- 旧本地 graph 本轮不自动迁移，只在 QA 检查中报告。

## 验收清单

- [ ] 后端 proposal 为不同 source turn 生成不同 canonical refs。
- [ ] 非用户 turn、越界 turn 仍被 evidence policy 拒绝。
- [ ] iOS quick extraction 和后端 request 不再新增 `conversationSession`。
- [ ] 对话照片不再新增 `archiveImageAnalysis`，且 source ID 不含绝对路径。
- [ ] Source audit 只返回计数/策略，不返回实体正文或 source ID。
- [ ] Archive delete 仍只匹配 `memoryArchiveItem`，legacy 对话照片不会误级联。
- [ ] 后端全量、知识组合 gate、Simulator/generic iPhoneOS build 和 release regression 通过。
- [ ] 分仓提交推送；需要后端合同变更时部署并跑线上 audit smoke；不做真机。

## 非目标

- 自动改写本地或生产历史 graph。
- 猜测 legacy session 与 Archive item 的映射。
- 删除历史来源、change-feed compaction、公开治理 UI。
- 真机验证。


## Success Criteria

- Recursive ledger reaches next_action=none.
- Relevant implementation and verification evidence is recorded.
- A compact status checkpoint is synced back to Lodestar progress.md.
