# M0-B 引导推荐“以后再聊”反馈闭环 G0

日期：2026-07-30

## 本轮完成

- 正式且默认关闭的
  `POST /v2/vaults/{vault_id}/guided-recommendations/feedback` 新增唯一可改变时机的
  组合：`feedbackAction=defer` 与 `feedbackReason=timing`。
- 客户端仍只提交 `commandId`、不透明 `recommendationSetId`、`slot`、动作和原因；不接受
  `threadId`、`sessionId`、`memoryVersionId`、候选、证据、文本、冷却时长或任何 Provider 数据。
- 后端在当前 Owner/Vault/Authority 上下文中重新规划并校验推荐集，再从已确认的证据中选择一个
  续聊锚点；在同一 Postgres Unit of Work 中依次写入值最小的反馈 receipt、既有
  saved-continuation cue 和既有 cooldown 边界。
- 反馈 receipt 必须在 interview session 仍为 `active/open` 时落库，保留 0045 的数据库
  触发器授权约束；0066 仅扩展 receipt action/reason/scope 校验，不改写历史记录、外键、
  append-only trigger 或其他权限约束。
- 通用 QA-only `knowledge-recommendations/feedback` 服务明确拒绝 `defer/timing`，不能绕过
  正式展示集和服务端重规划进入 cooldown。
- iOS 仅在已经受 `echoGuidedRecommendations` 控制的自然输入 Sheet 菜单中新增“以后再聊”；
  成功后沿用已有刷新，失败仍保留原提示和重试状态。全屏 Echo、导航和默认公开 UI 未改变。

## 验证

- 定向后端 API、反馈、发布策略、路由认证和迁移合约：81 passed。
- 新增 API 回归覆盖：拒绝注入的 `threadId`、创建冷却和 continuation cue、值最小响应、
  command 重放去重、旧推荐集的新 command 返回 stale。
- 后端 `scripts/verify_backend.sh`：通过，1606 项单测及现有静态/运行时 Gate 通过。
- iOS `OwnerTruthContractsTests`：99/99 通过，覆盖 `defer/timing` 的精确 payload 和成功刷新。
- iOS `generic/platform=iOS` Debug build：通过。
- 两仓库 `git diff --check`：通过。

## 默认发布边界

- `echoGuidedRecommendations` 仍由 iOS feature flag 和后端 ReleasePolicy 双重默认关闭。
- 未显式放行时，不会请求引导推荐、不会出现其操作菜单，更不会写入 cooldown 或 continuation。
- 本轮没有部署后端、修改服务器 ReleasePolicy、开启公开 cohort、执行生产 Postgres、Provider
  或真机验收。

## 未声明完成

- 未完成 M0-B 的人生地图公开浏览、真实语义检索、正式 session outcome summary 或产品放行决策。
- 0066 尚未在线上 Postgres 应用；部署后需补 scoped migration/replay/cooldown smoke。
- 本轮不是公开功能发布，也不是对实际用户的“以后再聊”体验验收。
