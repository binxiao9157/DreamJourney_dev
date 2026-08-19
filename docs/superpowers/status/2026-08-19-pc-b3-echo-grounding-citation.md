# PC-B3 Echo Grounding 与 Citation 完成记录

日期：2026-08-19

Work Item：`PC-B3`

状态：`COMPLETE`

## 1. 交付范围

- `ownerTruthMemoryProjection` 已计入 grounded 来源。
- grounded、gap 与 fallback 保持互斥；显式 fallback 不调用生成 Provider，也不伪装成正式记忆命中。
- 后端从本轮实际 Context materialization 自动生成回答与 Citation 审计，answerId 与审计记录绑定。
- Citation 保留 `contentHash`；`contextTraceId` 仅保存 SHA-256，避免原始跟踪标识进入长期审计。
- iOS Echo Evidence Bundle 升级到 schema v4，QA-only 保存脱敏的 Grounding 摘要并兼容 v3；旧 v2 数据显式清理。
- 普通 Echo UI 不展示来源编号、来源卡片、content hash 或原文入口。

## 2. 版本与部署

| 项目 | 版本/状态 |
|---|---|
| Backend 功能提交 | `873284b feat: audit grounded Echo answers` |
| Backend 验证提交 | `88d5ecb`、`559c412` |
| Backend 部署版本 | `559c412` |
| iOS 提交 | `e72eca3b feat: retain redacted Echo grounding evidence` |
| 数据库 | PostgreSQL，migration head `0099` |

## 3. 验证结果

- Backend 全量单元测试：2,174 项通过。
- PC-B3 定向 Backend 测试：42 项通过；补强后 30 项通过。
- Context Authority Gate：17 项通过。
- Context/Citation offline evaluation：3 项通过。
- production-postgres Owner Truth smoke：通过，覆盖真实 Context materialization、grounded/gap/fallback 和自动审计。
- deployed route authentication smoke：通过，222 条路由鉴权清单一致。
- iOS generic iPhoneOS test build：通过。
- iOS `EchoAnswerMemoryGroundingTests`：5 项通过。
- iOS Grounding、Evidence Bundle、Owner Isolation、Live Context parity 静态 Gate：通过。
- 模拟器 Echo QA Evidence Bundle 导出 smoke：通过，导出内容未包含原始 trace ID、Citation ref ID 或 content hash。
- `git diff --check`：通过。

模拟器截图：`tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260819-161136/01-echo-qa-evidence-bundle-export-smoke.png`。

## 4. 产品边界

- Grounding 证据只用于服务端审计和 QA 排障，不增加普通用户可见的来源卡片。
- 本项不扩大 KBLite、Legacy Archive 或 Family 私人数据的读取范围。
- 无正式记忆命中时保持 gap；检索组件故障时保持显式 fallback。
- 本项不改变 Echo 的现有 Stitch 全屏视觉和普通交互。

## 5. 证据与回滚

验收证据：`artifacts/product-confirmed/20260819-pc-b3/PC-B3/`。

回滚时分别回退 iOS `e72eca3b` 和 Backend `873284b` 相关变化并重建服务。migration `0099` 为增量审计字段，不执行破坏性 down migration；字段可保留为空。回滚不得删除已有回答、Citation 或正式记忆审计数据，完成后重新运行 `/ready`、Owner Truth deployed smoke 和公开 Echo UI 静态 Gate。
