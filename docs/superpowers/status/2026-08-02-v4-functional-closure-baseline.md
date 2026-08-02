# DreamJourney V4 剩余功能闭环执行基线

日期：2026-08-02
计划：`docs/superpowers/plans/2026-08-02-dreamjourney-v4-remaining-functional-closure-plan.md`
状态：`WAVE_0_IN_PROGRESS`

## 1. 本计划的完成口径

本基线只承认以下状态：

| 状态 | 含义 |
| --- | --- |
| `NOT_STARTED` | 尚未开始功能闭环实现。 |
| `IN_PROGRESS` | 正在实现，尚未达到完整验证。 |
| `FUNCTIONAL_VERIFIED` | 已在真实持久化或可部署路径验证，不依赖 QA header、内存 fixture 或 mock。 |
| `DEVICE_REQUIRED` | 非真机部分已完成，剩余结论只能通过真机、权限、Provider 或设备性能验证。 |
| `EXTERNAL_BLOCKED` | 代码和本地验证已完成，等待明确外部依赖或产品决策。 |

历史 `INTERNAL_READY`、`QA_ONLY`、`DEFAULT_OFF`、静态检查或文档记录仅表示已有资产，不能单独计为功能完成。

## 2. 提交与工作区隔离

### iOS

- 仓库：`/Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- 分支：`feature/prd-stitch-ui-adaptation`
- 启动提交：`cbb4bbfaa26e825b09ce9a25a8726af4d3d2138b`
- 上游基线：`f84e86b33949120623bddc6dadbad626892fd10b`
- 相对上游：本地领先 `483` 个提交。
- 启动时工作区：`507` 条未提交记录，其中 `42` 个修改、`59` 个删除、`406` 个未跟踪文件。

这些未提交内容属于并行工作或历史 QA 产物。本计划只使用精确路径暂存；不清理、不回滚、不重写、不把它们混入功能提交。

### Backend

- 仓库：`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend`
- 分支：`main`
- 启动提交：`ffa1f4ecfc09ad8469ede38464db46e22bd1b1c1`
- 上游基线：`e7dccd6f18077aa7c30bd50e10a5d65284d5a94c`
- 相对上游：本地领先 `2` 个提交。
- 启动时工作区：干净。
- 部署版本：`UNVERIFIED`，Wave 1 的部署 smoke 前不假定服务器已包含本地代码。

## 3. Wave 状态

| Wave | 目标 | 当前状态 | 当前事实 / 下一步 |
| --- | --- | --- | --- |
| 0 | 基线与提交隔离 | `IN_PROGRESS` | 本文件已建立；下一步提交这份基线与计划状态。 |
| 1 | Owner Truth 真实闭环 | `IN_PROGRESS` | Source、Candidate、Confirmation、MemoryVersion、Projection 和 Context 模型已存在，但关键路径仍由 QA/default-off/captured-policy 分段阻断；需建立服务端 closed-pilot 授权和真实 E2E。 |
| 2 | 引导式访谈 | `NOT_STARTED` | 已有会话、节奏、换题等局部合同；尚未作为正式 closed-pilot 自然输入闭环验收。 |
| 3 | 双推荐与知识地图 | `NOT_STARTED` | 已有 QA/shadow 资产；未形成普通 closed-pilot 用户可用能力。 |
| 4 | 数据权利、家庭与安全 | `NOT_STARTED` | 有局部 API、合同和 smoke；尚未完成全路由 owner-bound 验收。 |
| 5 | M0 UI 与 release-like 集成 | `NOT_STARTED` | 当前 UI 仍以现有公开 MVP 和 QA gate 为主。 |
| 6 | 非真机发布门 | `NOT_STARTED` | 现有脚本分散，尚未形成一次真实 M0 E2E gate。 |
| 7 | 真机与 M1 Voice | `NOT_STARTED` | 等 Wave 6 通过后再集中执行。 |

## 4. Wave 1 启动判定

已确认的可复用资产：

- 后端已有持久化 Source、Candidate、DecisionReceipt、MemoryVersion、Projection、Correction 和 Context 模型与迁移。
- 后端已有 Owner/Vault/authority epoch、认证、Route Ownership 和 Release Policy 基础。
- iOS 已有 typed Owner Truth contract、AccountLease、候选确认与失败收敛 UI。
- 后端已有隔离 Postgres smoke 框架，iOS 已有模拟器 UIQA 框架。

未完成的真实闭环边界：

1. `candidate-proposal/admit` 只创建 Source 与默认关闭的 extraction effect，实际 extraction 不会在 closed-pilot 流程中运行。
2. Candidate confirmation 仍是 default-off，且目前的端到端证据使用 QA header、受控 HTTP 或合成数据库。
3. `/context/build` 仍以旧 Context authority 为主；Owner Truth Projection 只在 shadow/compare 路径证明。
4. 尚无一个不使用 QA header、in-memory fixture 或本地假数据的部署 E2E：`Source -> Candidate -> Confirm -> MemoryVersion -> Projection -> Context -> Correction`。

Wave 1 先解决以上四点；在真实 E2E 未通过前，不进入推荐、媒体、Voice 或 Publication 新功能。

## 5. 本轮提交白名单

Wave 0 只允许提交：

- `docs/superpowers/plans/2026-08-02-dreamjourney-v4-remaining-functional-closure-plan.md`
- `docs/superpowers/status/2026-08-02-v4-functional-closure-baseline.md`

后续每个 Slice 在开始前更新本文件的状态、提交和验证证据；不使用全仓 `git add`。
