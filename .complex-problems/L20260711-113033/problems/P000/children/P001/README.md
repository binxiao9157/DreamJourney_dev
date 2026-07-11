# 后端 canonical 来源与只读审计

## Problem

V2 proposal 仍继承请求级模糊来源，privacy/title 表只识别部分 source kind，生产历史 graph 缺少不泄露正文的来源审计能力。

## Success Criteria

- 按 validated sessionId/sourceTurnIndices 派生精确 conversationTurn refs。
- conversationPhoto/memoryArchiveItem/legacy/unknown 分类和 title 统一。
- owner-bound audit preview 只返回 revision/计数/策略，不返回正文或 source ID。
- 不提供 apply migration，不改历史 graph。
- 后端测试和 smoke 通过。
