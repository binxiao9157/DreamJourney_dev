# Context Packet 驱动真实 Echo 生成成功检查

## Summary

P003 已在非真机范围内闭环。后端 generation context 与 iOS turn-scoped RAG 形成单一知识注入路径，超时降级、旧回调隔离和现有 Echo 状态兼容均有实现与回归证据。

## Evidence

- P005 已通过后端合同测试证明 selected context 可形成受隐私约束、长度可控、哈希稳定的生成文本。
- P006 已通过 iOS 静态门与构建证明当前 turn 能提交 ChatRagText，并具备 query-scoped fallback 和 stale callback guard。
- 全量 release regression 报告通过，Archive -> Echo smoke 明确返回 `containsArchiveContext=true`。
- 后端 182 个单元测试、FastAPI smoke 和 knowledge delta smoke 通过。

## Criteria Map

- generation/turn token 绑定：由 Echo turn gate、turn ID 与 lifecycle generation 覆盖。
- selected context 进入回复生成：由 `generationContext` 和 `submitTurnKnowledgeContext` 覆盖。
- 超时/失败本地降级：由 0.9 秒 timeout 与 query-scoped KBLite 覆盖。
- 避免双重注入：由 turn-scoped 启动参数抑制旧 local recent summary 覆盖。
- Echo 既有合同兼容：由 release regression、延迟回信 smoke、数字人静态门与通用设备构建覆盖。
- backend/local/stale 可区分：由来源字段、UIQA 记录和 trace guard 覆盖。

## Execution Map

- R004 汇总 P005/R002 与 P006/R003 的实现和验证结果。
- 生成筛选职责留在后端，iOS 只消费合同并管理当前 turn，不复制权限策略。

## Stress Test

- 后端慢响应时 fallback 先提交，迟到 backend context 不会形成第二次注入。
- 页面、用户或 turn 切换后，旧异步响应不会污染新对话。
- 后端返回空或旧版本合同，会明确降级而不是阻塞回复。

## Residual Risk

- 真实火山线上回答是否按预期吸收 ChatRagText 仍需真机语义验收；这属于 provider 行为证据，不影响本轮代码合同和非真机闭环判定。

## Result IDs

- R004
