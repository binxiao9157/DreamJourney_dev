# PC-B1 正式记忆总览与二次确认编辑

日期：2026-08-19
状态：`COMPLETE`

## 完成内容

- Backend 提供 Owner-only 正式记忆列表、详情和修订合同。
- 列表只返回 current MemoryVersion，支持分页、kind、关键词和七类 facet 筛选。
- 详情只向产品界面展示 current + 3 个历史快照；内部审计版本不删除。
- 修订必须匹配 expectedVersion/contentHash/schema，并携带 `secondConfirmation=true`。
- 修订原子创建 correction Source、Candidate、DecisionReceipt 和后继 MemoryVersion；陈旧写返回冲突，重复 command 幂等回放。
- PublicationVersion 始终固定到发布时选择的不可变 MemoryVersion，不随 Owner 后续纠正漂移。
- iOS 在“记忆档案”增加 Owner-only“正式记忆”入口，支持列表、筛选、详情、历史、内存草稿、差异预览和二次确认。
- 未确认草稿不写 UserDefaults 或文件；账户切换使用 AccountLease 与 generation token 丢弃旧响应。

## 版本与部署

| 工程 | 分支 | 提交 |
|---|---|---|
| Backend | `main` | `d0718b7`（功能提交 `ae670ea`，PostgreSQL 转义修复 `d0718b7`） |
| iOS | `feature/prd-stitch-ui-adaptation` | `a437c602` |

Backend 已部署到 `https://dreamjourney-api.liftora.cn`，`/ready` 为 `ready`，migration head 为 `0098`。

## 验证

- Backend 相关单元/API/路由/ReleasePolicy：19 项通过。
- production-postgres smoke：列表搜索/筛选、current + 3、陈旧写冲突、幂等、PublicationVersion 固定和无删除路由均通过。
- iOS `OwnerTruthContractsTests`：225 项通过。
- iOS workspace Debug simulator build：通过。
- 正式记忆静态 Gate、release QA package check：通过。
- 模拟器 UIQA：列表与详情通过，使用本机 QA Bundle ID `com.yxj.dreamjourney.app`。
- 两仓库 `git diff --check`：通过。

UIQA 截图位于：

- `tmp/visual-qa/product-v4/owner-truth-formal-memory-smoke/20260819-151039/01-formal-memory-list.png`
- `tmp/visual-qa/product-v4/owner-truth-formal-memory-smoke/20260819-151039/02-formal-memory-detail.png`

## 边界与回滚

- 本项没有数据库迁移，不改变现有 MemoryVersion 或 PublicationVersion 表结构。
- 回滚时先关闭 `ownerTruthCandidateReview` 的公开策略，再回退 Backend/iOS 提交；不得删除已经创建的修订版本。
- 当前页面沿用既有设计体系完成可用态；后续存在新的 Stitch/htmlCode 时再做 final visual QA。

下一交接点：`PC-B2 query-ranked Owner 检索`。
