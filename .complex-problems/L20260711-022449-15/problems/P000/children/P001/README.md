# 后端结构化证据提取

## Problem

`/kb/extract` 目前接收普通 transcript，provider 结果没有校验来源 turn，AI 回复、无来源或错误索引可能成为持久知识。

## Success Criteria

- additive 支持 extraction schema v2、userEvidenceOnly 和 indexed turns，同时保留 v1 兼容。
- 服务端校验 role、index、长度，并只接受引用有效 user turn 的实体。
- response 返回不含正文的 evidencePolicy 摘要，provider prompt 明确禁止 assistant 作为事实来源。
- 后端单测和 evidence smoke 覆盖 assistant-only、无来源、越界来源及合法来源。
