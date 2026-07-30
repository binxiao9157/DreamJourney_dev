# M0-B 回顾检索只读展示 G0/G1

日期：2026-07-30

## 本轮完成

- 新增正式、默认关闭的 `POST /v2/vaults/{vault_id}/memory-search` 产品读取合同。
- 该合同仅允许 Vault Owner 读取已确认记忆的受限预览；结果最多 8 条，每条仅包含排序、预览及受控分类字段。
- 后端明确排除 `memoryVersionId`、`memoryId`、`sourceId`、`threadId`、`contentHash`、查询计划、权限纪元、投影检查点和策略数据。
- 当前检索模式明确为 `deterministicTextFallback`。它是确定性文本回顾，不是语义/向量检索，也不对检索质量作产品承诺。
- `ownerTruthMemorySearch` 是独立默认关闭 feature：后端 ReleasePolicy 与 iOS 本地 feature flag 必须同时放行。
- iOS 仅在既有“自然输入”页面的双重 Gate 内展示“回顾检索”入口；页面只读、不写访谈数据、不改变全屏 Echo、Tab 或公开默认页面。
- 客户端在请求发起和响应提交时均校验当前 AccountLease；账号切换后旧异步结果会被丢弃。
- UIQA 使用内存 fixture，证明展示层不发起后端网络请求、不写入持久化访谈数据，也不渲染任何内部标识字段。

## 验证

- 后端定向 API、ReleasePolicy、认证路由、路由所有权和运行时能力测试：95 项通过。
- 后端 `scripts/verify_backend.sh`：通过，既有单测与 Gate 全部通过。
- iOS `OwnerTruthContractsTests`：109/109 通过，覆盖严格安全解码、默认关闭、AccountLease 异步回调丢弃、路由 Gate 与产品入口显隐。
- `Scripts/QA/prd-stitch-ui/run-owner-truth-memory-search-presentation-smoke.sh`：通过，实际 simulator UIQA 结果确认 1 次内存请求、1 条结果、无私有字段渲染、无后端网络、无持久化写入。
- iOS `generic/platform=iOS` Debug build（`CODE_SIGNING_ALLOWED=NO`）：通过。
- 后端与 iOS `git diff --check`：通过。

模拟器截图：

`tmp/visual-qa/product-v4/owner-truth-memory-search-presentation-smoke/20260730-205435/01-owner-truth-memory-search-presentation.png`

## 默认发布边界

- 默认公开版本不会显示入口、不会请求回顾检索，也不会改变现有 Stitch 对齐后的主页面结构。
- 后端未部署，服务器 ReleasePolicy、生产 Postgres、公开 cohort、Provider 和真机均未触及。
- 页面不会将确定性文本回顾伪装成语义理解或完整记忆库。

## 未声明完成

- 未完成向量/语义 ranker、真实检索质量评估、跨来源关联质量或公开放量。
- 未完成线上 Postgres 读取 smoke、部署验证、产品可用性验收和真机验收。
- 不改变 `WI-S1-01-06` 主 Work Item 的 Registry 顺序；本轮是 M0-B 默认关闭展示增量证据。
