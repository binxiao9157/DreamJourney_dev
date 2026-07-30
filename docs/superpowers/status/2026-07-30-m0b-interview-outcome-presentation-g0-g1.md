# M0-B 访谈回顾只读展示 G0/G1

日期：2026-07-30

## 本轮完成

- 新增正式、默认关闭的 `GET /v2/vaults/{vault_id}/interview-sessions/{session_id}/outcome` 产品读取合同。
- 该合同只返回展示安全的回顾摘要：`state`、本次已确认记忆数量、待确认批次数、是否可以后继续以及可用续谈线索数量。
- 后端明确排除 `sessionId`、`threadId`、`memoryVersionId`、`sourceId`、Candidate、消息正文、review batch 明细、authority epoch 与策略数据。
- 若确认投影仍在重建，合同只返回中性的 `rebuilding` 状态和零计数，避免把旧投影误说成当前已确认事实。
- `ownerTruthInterviewOutcome` 是独立默认关闭 feature：后端 ReleasePolicy 与 iOS 本地 feature flag 必须同时放行。
- iOS 只在既有“自然输入”页面的双重 Gate 内显示“本次回顾”入口。页面只呈现“本次补充”和“以后可续”，不把 AI 推测当作事实，不写入访谈状态，也不改变全屏 Echo、Tab 或公开默认页面。
- 客户端在请求发起和响应提交时均校验当前 AccountLease；账号切换后的旧异步结果会被丢弃。
- UIQA 使用内存 fixture，证明展示层不发起后端网络请求、不写入持久化访谈数据，也不渲染内部标识字段。

## 验证

- 后端定向 API、ReleasePolicy、认证路由、路由所有权和运行时能力测试：95 项通过。
- 后端 `scripts/verify_backend.sh`：通过，既有单测与 Gate 全部通过。
- iOS `OwnerTruthContractsTests`：113/113 通过，覆盖严格安全解码、默认关闭、AccountLease 异步回调丢弃、路径 Gate 与产品入口显隐。
- `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-outcome-presentation-smoke.sh`：通过，实际 simulator UIQA 结果确认 1 次内存请求、2 条已确认记忆、1 个待确认批次、1 条可续线索、无私有字段渲染、无后端网络、无持久化写入。
- iOS `generic/platform=iOS` Debug build（`CODE_SIGNING_ALLOWED=NO`）：通过。
- 后端与 iOS `git diff --check`：通过。

模拟器截图：

`tmp/visual-qa/product-v4/owner-truth-interview-outcome-presentation-smoke/20260730-211851/01-owner-truth-interview-outcome-presentation.png`

UIQA 结果：

`tmp/visual-qa/product-v4/owner-truth-interview-outcome-presentation-smoke/20260730-211851/owner-truth-interview-outcome-presentation-smoke-result.json`

## 默认发布边界

- 默认公开版本不会显示入口、不会请求访谈回顾，也不会改变现有 Stitch 对齐后的主页面结构。
- 后端未部署，服务器 ReleasePolicy、生产 Postgres、公开 cohort、Provider 和真机均未触及。
- 页面不是访谈完成度、语义质量或完整记忆库的结论；它只建立了一个最小化、可审计的回顾面。

## 未声明完成

- 未完成真实线上 Postgres 读取 smoke、部署验证、公开放量、产品可用性验收和真机验收。
- 未生成主题正文或自动补充建议；后续若需要，应作为独立、受 policy 约束的读取合同，不能从本摘要推导或编造。
- 不改变 `WI-S1-01-06` 主 Work Item 的 Registry 顺序；本轮是 M0-B 默认关闭展示增量证据。
