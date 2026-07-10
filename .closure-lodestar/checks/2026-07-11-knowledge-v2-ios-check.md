# iOS 知识三方合并成功检查

## Summary

R001 满足 P002 的每用户基线、三方合并、delta、隐私边界和 v1 fallback 标准；主控复核后补充的编辑/删除冲突测试也通过。

## Evidence

- `R001` 列出实现文件、模型 smoke、静态 guard 与 generic Simulator build 证据。
- 主控重新运行三方合并 model smoke 与 `knowledge-pipeline-check.swift`，均通过。
- 主控逐分支审查 Coordinator 的首次升级、pending retry、409 refresh、权威响应和 fallback 条件。

## Criteria Map

- 每用户基线与首次升级：文件 store + bootstrap/user isolation smoke 覆盖。
- 四类实体三方合并：纯模型按 type+id 执行，并覆盖单边修改、单边删除及双方冲突。
- 私有实体不上传/不误删：delta 和 remote deletion smoke 覆盖。
- v2 与 v1 兼容：BackendClient、Coordinator 选择性 fallback 及策略测试覆盖。
- QA 冲突隐私：摘要仅包含 count/type/id，并断言不含正文。

## Execution Map

- `KnowledgeThreeWayMerge.swift` 承担纯模型、基线/pending 文件和合同判定。
- `KnowledgeSyncCoordinator.swift` 保留原用户 generation/revision 流程，并接入 v2 delta。
- `DreamJourneyBackendClient.swift` 只新增 additive v2 方法，不改公开 UI。

## Stress Test

- 首次升级本地/远端同 ID 时不制造历史冲突且不误删远端独有项。
- 本地编辑对远端删除、以及本地删除对远端编辑均 local-wins，并产生冲突证据。
- localOnly/无 metadata 与远端同 ID 冲突时仍留在本地。
- 400 一般 v2 校验错误不会被误判为旧后端而静默 fallback。

## Residual Risk

- 实体级 local-wins 会牺牲远端同实体字段级修改；这是本任务明确的 v1 策略，QA 冲突摘要可追踪。
- 跨仓库组合 gate 与线上 Postgres 验证属于 P003。

## Result IDs

- R001
