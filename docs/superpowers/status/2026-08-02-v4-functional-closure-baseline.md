# DreamJourney V4 剩余功能闭环执行基线

日期：2026-08-02
计划：`docs/superpowers/plans/2026-08-02-dreamjourney-v4-remaining-functional-closure-plan.md`
状态：`WAVE_1_IN_PROGRESS`

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
- 相对上游：本地领先 `5` 个提交。
- 启动时工作区：干净。
- 部署版本：`UNVERIFIED`，Wave 1 的部署 smoke 前不假定服务器已包含本地代码。

## 3. Wave 状态

| Wave | 目标 | 当前状态 | 当前事实 / 下一步 |
| --- | --- | --- | --- |
| 0 | 基线与提交隔离 | `FUNCTIONAL_VERIFIED` | 计划与本文件已由 iOS 提交 `afa51ba` 建立；后续继续严格使用精确暂存，不处理并行工作区。 |
| 1 | Owner Truth 真实闭环 | `IN_PROGRESS` | 后端 `8112e0f` 已在隔离 Postgres 串联正式 `Source -> Candidate -> Confirm -> Projection -> Context`，无 QA header、无内存 fixture。仍缺 closed-pilot 纠错、部署 worker/profile、线上 smoke 与 iOS 真实数据 UIQA。 |
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

1. `candidate-proposal/admit` 仍是访谈专用入口；closed-pilot 的文字 Source 已可由独立 extraction worker 生成 Candidate，但实际 worker profile 尚未部署运行。
2. Candidate confirmation 的 generic route 已有服务端 closed-pilot 授权；iOS 的真实后端 Candidate/Source UIQA 和批量/部分确认仍未验收。
3. `/context/build` 已能在隔离 Postgres 中读取确认后的 Projection；服务器开关、worker 与 allowlist 尚未同时部署，线上仍没有真实 closed-pilot 数据可供消费。
4. Correction 路由仍为 QA-only。因此尚无部署态、无 QA header 的完整 E2E：`Source -> Candidate -> Confirm -> MemoryVersion -> Projection -> Context -> Correction`。

Wave 1 先解决以上四点；在真实 E2E 未通过前，不进入推荐、媒体、Voice 或 Publication 新功能。

## 5. Wave 1 已完成 Slice：服务端 closed-pilot 授权

- 后端提交：`2dd20f2 feat(release-policy): grant closed pilot server-side`。
- 新增部署配置：`RELEASE_POLICY_CLOSED_PILOT_OWNER_IDS` 与
  `RELEASE_POLICY_CLOSED_PILOT_FEATURES=ownerTruthCandidateReview`。
- 资格只根据认证后的服务端用户 ID 判断；客户端声明
  `X-DreamJourney-Policy-Cohort` 或 `cohort=closedPilotAdultSelf` 无效。
- 默认值为空，普通 release 与未列入 allowlist 的用户保持拒绝。
- 本 Slice 本地验证：
  - `scripts/verify_backend.sh` 全量通过：`1683` 个单测、全部既有 Gate、
    FastAPI smoke、编译和 `git diff --check`；
  - Owner Truth 访谈、确认、结果、推荐、地图、检索与 client-compatibility
    测试夹具均改为显式模拟服务端入组，覆盖了新的信任边界。
- 尚未声明为 Wave 1 功能完成：没有部署、没有真实 closed-pilot 用户入组，
  也没有启动 candidate/projection worker 或将 `/context/build` 切换为
  confirmed Projection 权威读取。

## 6. Wave 1 已完成 Slice：可部署的 Candidate / Projection Worker

- 后端提交：`f2a57f8 feat(owner-truth): add opt-in worker service profile`。
- 新增 `owner-truth-worker` Compose profile，分别运行：
  - `owner-truth-candidate-extraction-worker`；
  - `owner-truth-memory-projection-worker`。
- 两个 Worker 都支持兼容原有 one-shot 的 `--once`，以及受
  `OWNER_TRUTH_WORKER_POLL_SECONDS` 控制的 `--loop` 常驻模式；空闲轮询只在
  状态变化时输出，避免运行日志持续刷屏。
- 默认不随普通服务启动。只有服务器显式启用该 profile，才会消费已持久化的
  extraction / projection effect；因此公开 release 行为不变。
- 本 Slice 本地验证：
  - `scripts/verify_backend.sh` 全量通过：`1687` 个单测、全部既有 Gate、
    FastAPI smoke、编译和 `git diff --check`；
  - 新增 `scripts/run-backend-owner-truth-worker-process-gate.sh`，覆盖 CLI
    参数、轮询去重日志、资源关闭、Compose profile 与启动命令；
  - 本机没有 Docker CLI，未把 Compose 容器实际启动当作验证证据。服务器部署后
    必须显式启动 profile 并运行真实 Postgres Worker smoke。
- 尚未声明为 Wave 1 功能完成：Worker 尚未部署、未对真实 closed-pilot 用户运行；
  `/context/build` 的 confirmed Projection 读取仍仅限随后新增的默认关闭
  closed-pilot Context Authority，尚无真实数据 E2E 证据。

## 7. Wave 1 已完成 Slice：closed-pilot Context Authority

- 后端提交：`184317c feat(owner-truth): add closed pilot context authority`。
- 新增默认关闭配置：`OWNER_TRUTH_CONTEXT_AUTHORITY_CLOSED_PILOT_ENABLED=false`。
- 生效条件同时要求：认证后的服务端用户 ID 在
  `RELEASE_POLICY_CLOSED_PILOT_OWNER_IDS` 内、
  `RELEASE_POLICY_CLOSED_PILOT_FEATURES=ownerTruthCandidateReview` 已批准，且请求是
  本人的 `personal` 回响。客户端 cohort、QA header、家庭角色或任意自定义
  `digitalHumanId` 都不能获得资格。
- 生效后 `/context/build` 只使用当前已确认的 V4 `MemoryProjection`；响应保留 typed
  citation 与 `contextAuthority` 摘要。投影不存在、重建中或不可用时返回空 V4
  Context，不回读旧 Archive/KBLite/Care。
- 本 Slice 本地验证：
  - `scripts/run-backend-owner-truth-context-authority-gate.sh` 通过，覆盖默认关闭、
    服务端白名单、客户端伪造 cohort、无 QA header、投影缺失和旧记忆不回读；
  - `scripts/verify_backend.sh` 全量通过，包含既有单测、Gate、FastAPI smoke、编译和
    `git diff --check`；
  - iOS 当前 `EchoContextPacket` 只要求稳定的基础字段并接受任意
    `contextVersion`，已静态复核可解析新增 V4 packet；本 Slice 不改动 iOS 工作区。
- 尚未声明为 Wave 1 功能完成：开关仍默认关闭、后端尚未部署、Worker profile 尚未
  在 Postgres 运行，且 closed-pilot 的 Source -> Candidate -> Confirmation ->
  Projection -> Context -> Correction 真实 E2E 尚未跑通。

## 8. Wave 1 已完成 Slice：closed-pilot Source 到 confirmed Context 隔离 Postgres smoke

- 后端提交：`8112e0f test(owner-truth): cover closed pilot source pipeline`。
- 扩展 `scripts/backend-owner-truth-candidate-route-postgres-smoke.py`：在一个 disposable
  Postgres 数据库内，同时保留 QA 默认关闭/显式 header 的回归，并新增不含 QA header 的
  closed-pilot 路径。
- 新增的正式路径依次验证：
  1. 服务端 allowlist 用户携带 value-minimized release-policy capture 创建文字 Source；
  2. `OwnerTruthCandidateExtractionWorkerRuntime` 消费真实 outbox job，并生成一条 pending Candidate；
  3. 服务端 allowlist 用户通过 generic Candidate route 确认，写入 DecisionReceipt 与 MemoryVersion；
  4. `OwnerTruthMemoryProjectionWorkerRuntime` 重建 confirmed Projection；
  5. `/context/build` 返回 `echo-context-v4-owner`，且 citation 指向该确认 Source；
  6. 非 allowlist 账号不能读取该 Candidate inbox，所有 worker/result/receipt 都不回显 Source 正文。
- 本 Slice 本地验证：
  - `tests.test_owner_truth_candidate_route_postgres_smoke`、文字 Source、Candidate review、
    Context authority 相关单测共 `14` 项通过；
  - smoke 脚本 `py_compile` 与 `git diff --check` 通过；
  - 本机没有 Docker、`psql` 或 `DATABASE_URL`，因此隔离 Postgres 脚本本次未实际执行。
- 尚未声明为 Wave 1 功能完成：纠错仍是 QA-only，且本地 smoke 只能证明可执行路径；
  服务器部署 worker profile、开关和 allowlist 后仍必须跑线上 Postgres E2E。

## 9. 本轮提交白名单

Wave 0 已提交。当前 Wave 1 的 iOS 侧只允许提交本状态文件；后端改动必须
独立提交在 Backend 仓库。

- `docs/superpowers/status/2026-08-02-v4-functional-closure-baseline.md`

后续每个 Slice 在开始前更新本文件的状态、提交和验证证据；不使用全仓 `git add`。
