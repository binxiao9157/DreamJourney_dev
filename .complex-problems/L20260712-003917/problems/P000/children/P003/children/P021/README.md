# Round 3B：数据、API、授权、任务与 provider 合同

## Problem

目标领域仍需落为 typed relational schema、API command/query、工作授权、Outbox/Job、对象存储和 provider ports，同时保留开放 Decision 的扩展点。

## Success Criteria

- 核心表/对象具有 ID、owner/persona、version/state、evidence、policy、timestamps 和约束。
- `/v2` API 明确 command/query、认证上下文、错误码、幂等、并发、分页、取消和兼容策略。
- ProcessingBasis/Consent、AccessGrant、WorkAuthorization、DataRightsAuthorization、RetentionHold 和 machine principal 可执行。
- Job/Outbox 使用事务、去重、lease/heartbeat、retry/backoff、terminal receipt 和最小权限。
- 对象存储和 OCR/ASR/LLM/Voice/DH provider 通过 ports 隔离，凭据和长期资产不下发客户端。
- Publication/Visitor 与 Family/Care/TimeLetter 可选模块不污染 Owner 核心表。
- 该问题属于 T017，因为它把产品 authority 变成可实现且可验收的工程合同。
