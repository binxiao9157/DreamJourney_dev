# M0-B 人生地图只读展示 G0/G1

日期：2026-07-30

## 本轮完成

- 新增正式、默认关闭的 `GET /v2/vaults/{vault_id}/life-map` 产品读取合同。
- 返回体仅包含展示安全的聚合字段：`state`、故事数量、已关联故事数量，以及六个稳定维度的
  `confirmedEvidenceCount`、`coveredFacetCount`、`unfilledFacetCount` 与 `relatedStoryCount`。
- 后端明确排除 `memoryVersionId`、`sourceId`、`threadId`、`associationId`、检查点、策略数据及
  任何原始记忆/来源正文；路由为 `USER_SESSION`，风险等级为 `ownerTextCore`。
- `ownerTruthLifeMap` 是独立默认关闭 feature：后端 ReleasePolicy 与 iOS 本地 feature flag 必须
  同时放行。它不继承 `echoGuidedRecommendations` 的可见性。
- iOS 仅在既有“自然输入”页面内，在双重 gate 都满足时显示“人生地图”入口。详情页为只读六维
  浏览，不展示完成百分比、不写入访谈状态、不改变全屏 Echo、Tab 或公开默认页面。
- UIQA 使用内存预览客户端，证明展示层不请求后端且不写入持久化访谈数据；真实产品路径仍保留
  AccountLease 的请求前和提交前双重校验。

## 验证

- 后端定向 API、ReleasePolicy、认证路由、路由所有权和运行时能力测试：94 项通过。
- 后端 `scripts/verify_backend.sh`：通过，1607 项单测及既有静态/运行时 Gate 通过。
- iOS `OwnerTruthContractsTests`：104/104 通过，覆盖严格解码、默认关闭、AccountLease 异步回调
  丢弃、路径映射与产品入口显隐。
- `Scripts/QA/prd-stitch-ui/run-owner-truth-life-map-presentation-smoke.sh`：通过，实际 simulator
  UIQA 结果确认 1 次内存请求、2 条故事、6 个维度、无私有字段、无完成百分比、无后端请求、
  无持久化写入。
- iOS `generic/platform=iOS` Debug build（`CODE_SIGNING_ALLOWED=NO`）：通过。
- 后端与 iOS `git diff --check`：通过。

模拟器截图：

`tmp/visual-qa/product-v4/owner-truth-life-map-presentation-smoke/20260730-202708/01-owner-truth-life-map-presentation.png`

## 默认发布边界

- 默认公开版本不会显示入口、不会请求人生地图，也不会改变现有 Stitch 对齐后的主页面结构。
- 后端未部署，服务器 ReleasePolicy、生产 Postgres、公开 cohort、Provider 和真机均未触及。
- 该读取合同不是“人生地图完成度”或真实语义质量结论；它仅建立了一个可审计、最小化的浏览面。

## 未声明完成

- 未完成真实语义检索、跨来源关联质量、访谈 outcome summary 或人生地图公开放量。
- 未完成线上 Postgres 读取 smoke、部署验证、产品可用性验收和真机验收。
- 不改变 `WI-S1-01-06` 主 Work Item 的 Registry 顺序；本轮是 M0-B 默认关闭展示增量证据。
