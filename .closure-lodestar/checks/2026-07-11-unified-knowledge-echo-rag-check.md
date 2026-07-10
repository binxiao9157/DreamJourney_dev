# iOS 每轮 Echo RAG 注入成功检查

## Summary

本轮实现满足 P006 的代码合同与非真机验收范围：Echo 在最终 ASR 后优先使用后端 `generationContext`，超时或失败时按当前 query 使用当前用户 KBLite 降级，并通过 turn、用户和生命周期门禁避免旧异步结果污染当前轮次。

## Evidence

- `DialogEngineManager.submitTurnKnowledgeContext` 在真实 Dialog 路径发送 `SEDirectiveEventChatRagText`，UIQA 路径保留可断言的来源和长度。
- `EchoTurnKnowledgeContextGate` 保证同一 turn 最多提交一次，并在 0.9 秒后执行 query-scoped KBLite fallback。
- Echo 启动时启用 turn-scoped knowledge context，避免旧 KBLite/档案摘要与本轮上下文重复注入。
- `knowledge-pipeline-check.swift`、`context-packet-v1-check.swift`、`dialog-archive-context-integration-check.swift` 均通过。
- 2026-07-11 全量 release regression 通过，包含模拟器构建、通用 iPhoneOS 构建、Archive -> Echo smoke 与延迟回信通知 smoke。

## Criteria Map

- 当前 turn 注入且每轮最多一次：由 turn gate、提交标记和 ChatRagText 调用覆盖。
- 后端失败或超时降级：由 0.9 秒 timeout 与当前 query KBLite fallback 覆盖。
- 生命周期、turn、用户变化隔离：由 lifecycle generation、turn ID、user ID 与 latest-trace guard 覆盖。
- 不重复注入旧摘要：由 `usesTurnScopedKnowledgeContext` 抑制启动期旧知识摘要覆盖。
- trace、延迟回信、数字人和公开 UI 不回归：由静态门、release regression 和两条模拟器 smoke 覆盖。

## Execution Map

- Result R003 实现 iOS 解析、Dialog RAG 指令、Echo turn gate 和降级策略。
- 后端 generation context 由 P005 提供；P006 只消费稳定合同，不复制筛选逻辑。
- 全量回归报告位于 `tmp/visual-qa/prd-stitch-ui/release-regression/20260711-002316-release-regression/report.md`。

## Stress Test

- 后端上下文请求超过 0.9 秒时，本地 fallback 抢占提交权；迟到的后端结果因单次提交门禁被忽略。
- 用户、页面生命周期或 turn 在请求期间变化时，旧回调不再提交 RAG，也不覆盖最新 trace。
- 延迟回信路径只记录 trace，不向已结束的实时 Dialog turn 注入内容。

## Residual Risk

- 火山线上 ChatRagText 是否始终落在 provider 当前 query 的接收窗口内，仍需后续真机日志和回答内容验收；该项不阻塞本轮明确的非真机代码合同闭环。

## Result IDs

- R003
