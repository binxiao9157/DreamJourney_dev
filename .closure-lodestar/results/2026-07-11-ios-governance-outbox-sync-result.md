# iOS Governance Outbox 与同步协调结果

## Summary

P011 与 P012 已共同完成 iOS 显式知识治理动作的可靠提交闭环：多项 per-user outbox 可跨重启恢复，`KnowledgeSyncCoordinator` 负责串行网络提交、revision conflict 重放、权威图谱合并与 user/persona generation 防污染。

## Done

- R007 完成 Codable outbox item、用户隔离文件、原子写入、有序读取、operation 去重、删除与损坏拒绝。
- R008 完成 coordinator 串行提交，治理与普通 graph sync 不并发。
- 409 先刷新远端基线，再使用持久化的同一 operation ID 重试。
- 成功响应先三方合并并保存权威 base，再移除 outbox；失败保留待重试项。
- user 切换失效 generation；persona 切换后不直接应用旧 persona 响应，改走 change feed 收敛。
- QA 覆盖 outbox round-trip/隔离/损坏和 coordinator 的提交顺序、冲突、身份 gate。

## Verification

- P011 检查 C007 成功，结果 R007。
- P012 检查 C008 成功，结果 R008。
- governance model/client/outbox/coordinator 与 three-way merge smoke 全部通过。
- DreamJourney workspace Simulator Debug 完整构建通过。

## Known Gaps

- 部署后端网络 smoke、release regression 集成和交付文档由 P004 处理。
- 当前只提供服务层入口，不在公开 UI 暴露治理操作。

## Artifacts

- `DreamJourney/Sources/Services/KBLiteModels.swift`
- `DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift`
- `DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift`
- `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- `Scripts/QA/prd-stitch-ui/knowledge-governance-*.swift`
- `Scripts/QA/prd-stitch-ui/run-knowledge-governance-*.sh`
