# iOS 知识三方合并与 Delta 同步结果

## Summary

iOS 已从 UserDefaults revision/fingerprint 全量同步升级为每用户远端基线、Mutation V2 delta 与实体级三方合并，同时保留旧后端 v1 降级路径。

## Done

- 新增纯 Foundation 合并引擎，按实体类型和 ID 处理首次升级、单边修改、远端/本地删除及双方冲突；双方冲突确定性 local-wins。
- `localOnly` 与缺失同步 metadata 的实体只留本地，不上传、不生成 tombstone，也不被远端缺失删除。
- 每用户远端 base 与 pending mutation 使用 Application Support 独立 JSON 文件持久化；重试复用 operationId、baseRevision、deletedAt 和 payload。
- BackendClient 新增 v2 mutation 请求，Coordinator 消费权威 v2 graph/change metadata，并仅在明确旧合同错误时降级 v1。
- 新文件显式加入 Xcode target，局部知识管线 guard 已更新。

## Verification

- 独立三方合并 model smoke 通过，覆盖首次升级、单边修改/删除、编辑与删除冲突、tombstone、私有实体保护、用户隔离和 fallback 判定。
- `knowledge-pipeline-check.swift` 通过。
- 模型以 `swiftc -warnings-as-errors` 编译通过。
- iOS Debug generic Simulator build 由执行 agent 验证为 `BUILD SUCCEEDED`。
- P002 文件范围 `git diff --check` 通过。

## Known Gaps

- 冲突策略是实体级 local-wins，不是字段级 CRDT；冲突只写 QA 类型/ID 摘要。
- 旧后端 v1 fallback 无法表达精确 tombstone，这是兼容路径的固有限制。
- release 总 gate、部署态 v2 smoke 和状态文档由后续 P003 完成。

## Artifacts

- `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift`
- `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift`
- `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/Scripts/QA/prd-stitch-ui/knowledge-three-way-merge-model-smoke.swift`
