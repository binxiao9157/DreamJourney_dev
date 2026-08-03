# Round 4E2A1：生成 typed Execution Registry

## Problem

Roadmap 缺少可供总 checker 和 selector 读取的 13 Package / 115 Work Item typed 快照。需要新增独立生成器和确定性 JSON，在不复制产品正文的前提下固化 class、Authority lock、依赖、Gate、状态和 rank。

## Success Criteria

- 新增 `generate-product-v4-execution-registry.py` 和 `DreamJourney_V4_路线执行注册表_V1.0.json`。
- JSON 精确包含 13 Package、115 Work Item、1840 源字段计数；Package 元数据含 releaseClass/authorityLock/selectorBand/start/exit dependencies。
- Work Item 元数据含 packageId/priorityClass/releaseClass/authorityLock/lifecycle/decision/executionOwner/requiredGates/gateEvidence/directDependencies/stableRank。
- Optional 全部 default-off；MIG authority lock 仅为迁移 evidence；Owner core 不引用 Optional 为 start dependency。
- 生成器含 schema/self-test，双次输出字节与 SHA-256 一致。
