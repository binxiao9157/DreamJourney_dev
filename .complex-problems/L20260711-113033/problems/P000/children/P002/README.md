# iOS canonical 来源生成与 typed audit consumer

## Problem

iOS quick extraction 和后端 request 继续生成 `conversationSession`，对话照片继续生成 `archiveImageAnalysis`，与后端 canonical 合同不一致。

## Success Criteria

- 新文本实体按 session/turn 生成 conversationTurn refs。
- 对话照片使用稳定、无绝对路径的 conversationPhoto ref。
- extraction request 不再声明模糊 source ref。
- typed audit consumer 与 pure/static smoke 完成。
- 不自动迁移旧本地 graph，不改变公开 UI。
