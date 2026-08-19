# PC-B2 query-ranked Owner Context 完成记录

日期：2026-08-19

Work Item：`PC-B2`

状态：`COMPLETE`

## 1. 交付范围

- 生产 Owner Context 从固定 Citation 顺序切换为 query-ranked SearchDocument。
- 自然语言查询在完整短语精确匹配之外使用有界、确定性的中文词项匹配；完整短语仍具有最高优先级。
- 候选集最多 20 条，最终上下文最多 8 条，生成上下文最多 4,096 字。
- 入选前复核 Authority Epoch、current MemoryVersion、content hash 和状态。
- 无命中返回 `memoryGrounding=gap`，不调用生成 Provider，也不扩大 KBLite/Legacy Archive 回退。
- SearchDocument 不可用时记录明确 deterministic fallback reason，且不读取额外数据源。

## 2. 版本与部署

| 项目 | 版本/状态 |
|---|---|
| Backend 功能提交 | `f093fd6 feat: rank owner echo by formal memories` |
| Backend smoke 修复 | `cee7122`、`7bd935d` |
| Backend 部署版本 | `7bd935d` |
| iOS 功能基线 | `a437c602`；PC-B2 无公开 UI 或产品代码变化 |
| 数据库 | PostgreSQL，migration head `0098`；本项无迁移 |

## 3. 验证结果

- PC-B2 定向后端测试：88 项通过。
- SearchDocument projection worker gate：24 项通过。
- memory-search offline evaluation gate：4 项通过。
- Python compileall 与 `git diff --check` 通过。
- production-postgres deployed smoke 通过：自然语言相关性、Top-K、current/version/hash/rights 复核、无命中 gap、SearchDocument fallback 均成立。
- 生产 `/ready` 在部署和 smoke 后均为 ready，schema head 为 `0098`。

全量 discovery 另发现既有测试基础问题：共享 PostgreSQL pool/全局状态造成 49 个顺序相关 error；路由 inventory 仍固定为 219，但当前应用已有 222 条路由，产生 5 个 failure。本项未新增路由，问题不纳入 PC-B2 功能提交，后续应单独修复测试隔离和 inventory 基线。

## 4. 产品边界

- 本项不改变公开 UI。
- 本项不开放 KBLite 用户入口，也不改变其既有后台读写权限。
- 本项不把检索 fallback 解释为有记忆命中。
- Citation 和 Grounding 的最终一致性由下一项 `PC-B3` 收敛。

## 5. 证据与回滚

验收证据：`artifacts/product-confirmed/20260819-pc-b2/PC-B2/`。

回滚仅回退 Backend 到 `d0718b7` 并重建 API；本项无数据库迁移，不删除或改写正式记忆、SearchDocument、Projection 或审计数据。回滚后必须重新验证 `/ready` 和 Owner Context deployed smoke。
