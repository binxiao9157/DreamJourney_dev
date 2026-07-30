# M0-B 引导推荐反馈闭环 G0

日期：2026-07-30

## 本轮完成

- 正式展示接口升级为
  `GET /v2/vaults/{vault_id}/guided-recommendations` v2：在已有展示字段外，仅增加
  不透明的 `recommendationSetId`，用于绑定本次反馈；不向 iOS 传递候选、证据、排序、
  知识维度、线程、会话或记忆正文。
- 新增正式反馈接口
  `POST /v2/vaults/{vault_id}/guided-recommendations/feedback`。请求只接受
  `commandId`、`recommendationSetId`、`slot`、`feedbackAction`、`feedbackReason`；
  响应只返回 `created` 或 `deduplicated`。
- 后端在 Owner/Vault/Authority 上下文中重新计算当前计划，校验不透明推荐集，拒绝
  陈旧集；相同 `commandId` 和相同安全载荷重放为幂等结果。
- iOS 在现有“自然输入” Sheet 的每条引导问题旁增加“调整引导问题”菜单：
  `换一个问题` 与 `不想聊这个方向`。成功后刷新问题；失败时保留原问题并给出简短可重试提示。
- `echoGuidedRecommendations` 仍默认关闭。未显式放行时不请求、不展示问题或菜单，
  全屏 Echo、导航和公开 MVP 视觉均未改变。

## 验证

- 后端聚焦合约、认证、运行时测试：111 passed。
- 后端 `scripts/verify_backend.sh`：通过，1604 项单测及现有静态 Gate 通过。
- iOS `OwnerTruthContractsTests`：98 passed，覆盖严格摘要、反馈成功刷新、失败保留、
  默认关闭和注入式产品 Sheet 的问题/操作按钮渲染。
- iOS `generic/platform=iOS` Debug build：通过。
- 本地检查：两个仓库 `git diff --check` 通过。

## 边界与未完成项

- 未部署后端、未调整服务器 ReleasePolicy、未打开任何公开入口。
- 未做生产 Postgres、真实用户、Provider 或真机验收。
- 本轮不引入新推荐算法、人生地图、语义检索、候选审核或自动发送行为。

## 后续 Gate

在公开放行前，仍需完成 scoped Postgres 验收、产品 ReleasePolicy 决策和真实用户场景
验证；本轮 G0 只证明默认关闭的正式读/反馈合同与 iOS 局部交互闭环。
