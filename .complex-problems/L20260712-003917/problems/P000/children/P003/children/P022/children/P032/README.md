# Round 3C2 iOS、API 与 AuthZ 双轨 Rollout

## Problem

当前 iOS 直接依赖旧 route、shared/backend token、ownership shadow/fallback 和分散 feature flag；目标要求 typed `/v2`、强身份、session/principal、fail-closed AuthZ 与稳定 capability。需要设计旧/新客户端和旧/新 API 共存的兼容窗口、shadow/canary/cutover 和紧急撤回，不让旧回调、旧角色或旧凭据跨账号污染新 Authority。

## Success Criteria

- 明确支持的客户端版本矩阵、最低版本门、旧 route facade 和 `/v2` 的兼容期。
- 定义 challenge/verify/session/refresh 从 shared/anonymous 到强身份的迁移、token rotation/revoke 和失效恢复。
- 定义 AuthZ shadow compare 到 production enforce 的指标、阈值、fail-closed 条件和紧急撤回方式。
- 定义 iOS 本地 store、account generation、draft/callback/cache、feature flag 和 capability 的迁移顺序。
- 每个核心产品切片具有 shadow、canary、cutover、read fallback、自动暂停和退出证据。
- 明确旧客户端不得创建新目标 Authority 之外的第二事实源。
- 至少覆盖旧客户端写入、refresh reuse、切账号异步回调、跨 owner 404、capability 漂移和 canary 回滚等验收场景。
- 增加可自动检查的文档门禁。
