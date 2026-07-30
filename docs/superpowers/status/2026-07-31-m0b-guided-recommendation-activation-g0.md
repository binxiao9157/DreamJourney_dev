# M0-B 正式引导推荐激活 G0

日期：2026-07-31
范围：默认关闭的正式引导推荐激活合同。
状态：`INTERNAL_READY`，本地验证完成；未推送、未部署、未开放公开发布。

## 解决的问题

引导推荐的 `question` 是策略生成的展示文案，不是 Owner 本人的叙述。点击推荐卡不能把
该问题预填或写入自然输入、访谈消息、Candidate、MemoryVersion 或 Provider 路径。

## 已实现

- 后端新增 `POST /v2/vaults/{vault_id}/guided-recommendations/activate`。
- 客户端请求严格只包含 `commandId`、`recommendationSetId` 和 `slot`；服务端拒绝
  `question`、`text`、Candidate、线程、会话、证据和 Provider 字段。
- 服务端在当前 Owner/Vault/Authority 上下文中重新规划并内部选择对象，只记录既有的
  append-only activation receipt；不会创建 Owner 叙述或触发任何 AI/Provider 副作用。
- activation receipt 新增 `guidedRecommendationSetId` 绑定。相同安全命令可重放；候选在
  后续计划中消失时，已完成的正式激活仍可幂等返回。
- iOS 点击推荐后只显示“想听你说说”和该展示问题，等待 Owner 自行输入；不再把问题写入
  输入框或自然输入命令。
- `echoGuidedRecommendations` 仍为 iOS 与后端双侧默认关闭的 feature。全屏 Echo、公开
  MVP 的视觉结构和默认路径均未修改。

## 验证

- 后端聚焦合约、认证、运行时与迁移测试：110 passed。
- iOS `OwnerTruthContractsTests`：129 passed，覆盖严格激活载荷、成功后仅显示问题、不会
  创建自然输入命令、失败保留原推荐和默认关闭状态。
- iOS 静态边界检查：
  `Scripts/QA/product-v4/owner-truth-guided-recommendation-activation-static-check.py` 通过。
- 两仓库 `git diff --check` 通过。

## 部署与发布 Gate

- 后端迁移 `0068_owner_truth_guided_recommendation_activation_binding` 必须先在目标环境执行。
- 后端部署后才可启用 iOS 的正式激活调用；目前 feature 仍默认关闭。
- 公开放行前仍需 scoped Postgres smoke、ReleasePolicy 产品决策和真实用户场景验收。
- 本项不包含推荐算法升级、候选阅读、自动发送、人生地图或真机验收。
