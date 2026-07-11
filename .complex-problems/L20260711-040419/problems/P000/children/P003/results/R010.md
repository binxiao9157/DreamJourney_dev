# iOS 知识治理 Consumer 与同步串行化结果

## Summary

iOS 已具备完整但不公开暴露的知识治理基础设施：强类型治理合同、metadata 保真、后端 consumer、稳定 operation ID、跨重启 outbox，以及与现有三方合并同步共用的串行 coordinator。

## Done

- R006 定义 confirm/reject/correct/deleteSource action、typed correction、source/entity reference、response summary 和 governance metadata。
- 四类 KBLite 实体均保留 optional governance metadata，严格解析 schema v1 / mutation v2 权威响应。
- Backend client 接入 `/kb/governance/actions`，Archive delete 支持 URL 编码后的稳定 operation ID。
- R009 完成多项 per-user outbox、普通同步串行化、409 重试和 user/persona generation gate。
- 权威 graph 通过现有三方合并写入 KBLite，并更新 remote base、清理旧 pending mutation，之后才删除治理 outbox。
- 保持公开 UI 不变，提供后续产品治理页面可调用的 `performGovernance` 和明确错误结果。

## Verification

- P009/C006 成功，结果 R006。
- P010/C009 成功，结果 R009。
- governance model/client/outbox/coordinator、proposal、three-way merge smoke 通过。
- DreamJourney workspace Simulator Debug 构建通过。

## Known Gaps

- 治理操作暂未接入公开产品页面，符合本任务基础设施范围。
- 线上后端 smoke 和 release QA package 接入由 P004 处理。

## Artifacts

- `DreamJourney/Sources/Services/KBLiteModels.swift`
- `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- `DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift`
- `DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift`
- `Scripts/QA/prd-stitch-ui/knowledge-governance-*`
