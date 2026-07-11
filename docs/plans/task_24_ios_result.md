# iOS snapshot fallback 实现结果

## Summary

iOS 已能严格识别结构化 compacted 410，并在当前 pull session 内最多执行一次权威 snapshot 恢复；成功后复用现有三方合并/CAS 并继续推送本地变化，失败不单独修改 base 或 pending。

## Done

- 新增 `KnowledgeSnapshotResponse` 与 `KnowledgeChangeFeedRecoveryPolicy`。
- 新增 typed `fetchKnowledgeSnapshot`。
- Coordinator 新增单次 fallback、user/generation/pull-session 保护和完成后的本地 push。
- 保持分页格式错误、网络错误和 404/405 legacy fallback 原语义。
- 兼容历史缺少部分实体数组的合法 snapshot，同时拒绝类型错误集合。

## Verification

- 跨仓库 knowledge change-feed gate 通过。
- model smoke 与 coordinator static check 通过。
- worker Simulator Debug build 成功。
- `git diff --check` 在清理 Lodestar 尾部空行后通过待最终复核。

## Known Gaps

- generic iPhoneOS、默认 release regression 和部署后真实 Postgres 合同由 P003 统一执行。

## Artifacts

- `DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift`
- `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- `DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift`
- `Scripts/QA/prd-stitch-ui/knowledge-change-feed-pagination-model-smoke.swift`
- `Scripts/QA/prd-stitch-ui/knowledge-change-feed-pagination-coordinator-check.swift`
