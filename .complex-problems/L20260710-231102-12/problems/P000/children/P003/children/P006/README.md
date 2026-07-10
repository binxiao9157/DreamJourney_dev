# iOS 每轮 Echo RAG 注入

## Problem

iOS 目前只记录 Context Packet trace，真实火山 Dialog 回复仍使用启动时旧摘要，无法利用本轮 query 的后端筛选结果，且旧摘要可能重复注入。

## Success Criteria

- 最终 ASR 后将当前 Context Packet 的 `generationContext.text` 通过 `SEDirectiveEventChatRagText` 提交给当前 turn，且每轮最多一次。
- 后端失败或短超时后按当前 query 使用当前用户 KBLite 降级。
- lifecycle、turn 或用户变化时旧异步回调不会提交 RAG。
- Echo 使用 turn-scoped RAG 时，会话启动不再重复注入旧 KBLite/档案摘要。
- 现有 trace/evidence、延迟回信、数字人音频 owner 与公开 UI 不回归。
