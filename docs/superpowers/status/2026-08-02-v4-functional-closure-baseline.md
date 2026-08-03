# DreamJourney V4 剩余功能闭环执行基线

日期：2026-08-03
计划：`docs/superpowers/plans/2026-08-02-dreamjourney-v4-remaining-functional-closure-plan.md`
状态：`WAVE_6_NON_DEVICE_GATE_PASSED`

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
- 当前远端与运行代码：`bc1dfd7 fix(owner-truth): preserve owner-authored memory semantics`，已部署至服务器。
- 本地工作区：干净；服务器工作区只保留未纳入 Git 的历史 `.env.backup*` 私密备份。

## 3. Wave 状态

| Wave | 目标 | 当前状态 | 当前事实 / 下一步 |
| --- | --- | --- | --- |
| 0 | 基线与提交隔离 | `FUNCTIONAL_VERIFIED` | 计划与本文件已由 iOS 提交 `afa51ba` 建立；后续继续严格使用精确暂存，不处理并行工作区。 |
| 1 | Owner Truth 真实闭环 | `FUNCTIONAL_VERIFIED` | 服务器 Postgres 已跑通 `Source -> Candidate -> Confirm -> Projection -> Context -> Citation -> Correction`；真实短信/身份 Provider 仍单列为 `EXTERNAL_BLOCKED`。 |
| 2 | 引导式访谈 | `FUNCTIONAL_VERIFIED` | 自然输入、用户边界、结束会话和候选确认由真实后端合同、XCTest 与模拟器 UIQA 覆盖。 |
| 3 | 双推荐与知识地图 | `FUNCTIONAL_VERIFIED` | 连续性/知识完整性推荐、激活和 life-map 已完成部署持久化 smoke；默认发布态仍受服务端 cohort 控制。 |
| 4 | 数据权利、家庭与安全 | `FUNCTIONAL_VERIFIED` | owner-bound session、路由隔离、导出/删除、家庭贡献授权与 deny-by-default 已由部署 Postgres smoke 覆盖。 |
| 5 | M0 UI 与 release-like 集成 | `FUNCTIONAL_VERIFIED` | 维持三 Tab 与全屏 Echo；closed-pilot M0 产品面、失败收敛和隐藏能力公开范围均已完成 UIQA。 |
| 6 | 非真机发布门 | `FUNCTIONAL_VERIFIED` | 统一后端/模拟器/XCTest/iPhoneOS Gate 已在 2026-08-03 完整通过，证据路径见第 14 节。 |
| 7 | 真机与 M1 Voice | `EXTERNAL_BLOCKED` | Wave 2–6 已关闭。2026-08-03 已检测到已配对 iPhone，但本机 Xcode 未登录 Team `2BTR77V3R8` 的开发者账号，缺少 `com.yxj.dreamjourney.app` 与 Widget 的开发描述文件；登录并下载 profile 后执行登录/权限/前后台/通知与 M1 声音专项验收。 |

## 4. Wave 1 启动判定

已确认的可复用资产：

- 后端已有持久化 Source、Candidate、DecisionReceipt、MemoryVersion、Projection、Correction 和 Context 模型与迁移。
- 后端已有 Owner/Vault/authority epoch、认证、Route Ownership 和 Release Policy 基础。
- iOS 已有 typed Owner Truth contract、AccountLease、候选确认与失败收敛 UI。
- 后端已有隔离 Postgres smoke 框架，iOS 已有模拟器 UIQA 框架。

未完成的真实闭环边界：

1. `candidate-proposal/admit` 仍是访谈专用入口；closed-pilot 的文字 Source 已可由独立 extraction worker 生成 Candidate，但实际 worker profile 尚未部署运行。
2. Candidate confirmation 的 generic route 已有服务端 closed-pilot 授权；iOS 的真实后端 Candidate/Source UIQA 和批量/部分确认仍未验收。
3. `/context/build` 已在服务器 API 容器内的隔离 Postgres 中读取确认后的 Projection；生产全局开关、常驻 worker 与真实 allowlist 仍未启用，线上普通数据不会消费该路径。
4. Citation 与 Correction 已新增服务器授权的 closed-pilot 路径：正式 Owner 必须具备 `ownerTruthCandidateReview` 的服务端 allowlist 与发布策略 capture；QA header 仍只是兼容路径。服务器容器内已通过无 QA header 的隔离 Postgres E2E；真实 allowlist 账号尚未入组验收。

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
- 尚未声明为 Wave 1 功能完成：代码虽已部署，但没有真实 closed-pilot 用户入组，
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
- 尚未声明为 Wave 1 功能完成：Worker Compose profile 尚未启动、未对真实 closed-pilot 用户运行；
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
- 尚未声明为 Wave 1 功能完成：全局开关仍默认关闭、常驻 Worker profile 未启用，且尚未由真实
  closed-pilot 账号运行完整 iOS 流程；但服务器 API 容器内的隔离 Postgres E2E 已实际跑通。

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
- 尚未声明为 Wave 1 功能完成：该路径本地仅完成脚本和单测证明，实际隔离
  Postgres 脚本尚未执行；服务器部署 worker profile、开关和 allowlist 后仍必须跑线上
  Postgres E2E。

## 9. Wave 1 已完成 Slice：closed-pilot Citation / Correction 正式授权

- 后端提交：`18b222c feat(owner-truth): authorize closed-pilot corrections`。
- `POST /v2/vaults/{vaultId}/answer-citation-receipts` 与
  `GET /v2/vaults/{vaultId}/answers/{answerId}/citations` 现在可由满足服务端
  `ownerTruthCandidateReview` 发布策略的 Owner 调用；显式 QA header 继续走原有兼容
  shadow 路径。
- 正式 Citation 复用 confirmed Projection 的 materialization，不允许客户端选择该分支；
  只保存 hash 与 typed citation，不回显问题、回答或 Source 正文。
- Correction request 与 resolve 同样要求服务端发布策略。纠错创建私有 Source 和待确认
  Candidate；确认后只替换被引用的 MemoryVersion，并把 release-policy capture 写入既有
  DecisionReceipt 的 `authorization_evidence`。
- `answer feedback` 仍为 QA-only，未随 Citation / Correction 放宽。
- 扩展 disposable Postgres smoke，覆盖：正式 Citation、非 allowlist 的纠错拒绝、正式
  Correction、Projection 重建后的 replacement citation，以及 DecisionReceipt 授权证据。
- 本 Slice 本地验证：
  - `21` 项 Citation、Correction、Candidate review 与 smoke 静态测试通过；
  - Python 编译和 `git diff --check` 通过；
  - 服务器 API 容器已于 `bc1dfd7` 部署后实际执行该 disposable Postgres 脚本，完整
    `closedPilotSourceCandidate / closedPilotProjectionContext / closedPilotCitationCorrection`
    均为 `true`；该脚本使用临时数据库，不写入生产业务数据。

## 10. Wave 1 已完成 Slice：后端部署与隔离 Postgres E2E（默认关闭）

- 后端 runtime 提交：`bc1dfd7 fix(owner-truth): preserve owner-authored memory semantics`；
  包含 route-authentication、正式文字 Source fixture 与 owner-authored metadata 的后续收敛。
- 服务器已显式应用并验证 migration `0071`；`/ready` 返回 `200`，数据库、schema、auth 与
  incident 均为 `ready`。
- 已在服务器 API 容器内运行 route-authentication Postgres smoke：`status=passed`，
  `routeCount=150`，并覆盖匿名用户拒绝、用户业务路由允许、机器业务路由拒绝和机器系统路由允许。
- 已在同一已部署 API 容器运行
  `backend-owner-truth-candidate-route-postgres-smoke.py`：`status=passed`，并实际验证无
  QA header 的 Source 创建、Candidate pending、接受、Projection、Context citation 与
  Correction；烟测在 disposable Postgres 数据库执行，结束后清理。
- 本次修复把仅限 closed-pilot 本人手写文字 Source 的确定性 Candidate 元数据固定为
  `firstPerson / recalled / standard`，但它仍必须先经 Owner 接受才可投影或进入 Context；
  这不放宽模型推断、未确认 Candidate 或受限内容的 Context 读取。
- `OWNER_TRUTH_CANDIDATE_REVIEW_QA_ENABLED`、Candidate/Projection Worker 与 Context
  Authority 均保持 `false`；本部署没有写入 closed-pilot 用户 allowlist，也没有启动
  `owner-truth-worker` profile。
- 该 Slice 证明部署基础设施、默认拒绝边界和服务器内真实持久化 E2E；不能替代真实
  closed-pilot 用户、常驻 Worker profile、iOS 重启恢复与发布前用户流程验收。

## 11. Wave 1 已完成 Slice：iOS 文字 Source 创建入口

- iOS 提交：`53a13e6 feat(owner-truth): add closed pilot source entry`；仅限
  closed-pilot 的本人档案页。
- Archive 创建菜单默认不展示“提交待确认记忆”。只有服务端同时批准
  `ownerTextCaptureV1` 与 `ownerTruthCandidateReview` 时，才显示该入口；本地 flag 不能
  自行开启。
- 该入口不会复用旧的“添加文字描述”本地档案写入。它先读取 Source authority epoch，使用
  AccountLease 和稳定 command ID 调用正式 Source capture；网络失败时仅在当前输入页内以
  相同命令重试，账户/策略变化时失效并清除。
- 成功后只提示用户前往“待确认记忆”，不把 Candidate、MemoryVersion 或 Projection 伪造为
  本地成功；普通发布态的既有文字档案流程不变。
- 本 Slice 本地验证：
  - `OwnerTruthContractsTests` 共 `179` 项通过，新增提交、同命令重试、账户切换、策略关闭和
    默认隐藏覆盖；
  - `product-v4-ios-owner-truth-text-source-capture-check.py` 通过，现已覆盖传输、默认隐藏、
    双服务端策略、typed entry 和选择路由；
  - 既有文字 Source / Candidate closed-pilot gate 通过；
  - iPhoneOS generic build 通过，`git diff --check` 通过。
- 仍缺：服务端部署后由真实 closed-pilot 账号运行 `Source -> worker -> Candidate -> Confirm`
  的模拟器 UIQA，以及强杀重开和线上 Postgres E2E。这些完成前，Wave 1 仍为
  `IN_PROGRESS`。

## 12. Wave 1 进行中 Slice：iOS Candidate 批量/部分确认

- 本 Slice 将同一轮中可批量确认的标准敏感度 Candidate 收敛为一个明确的 closed-pilot
  操作：用户先选择 Candidate，客户端再依次调用既有的单条正式确认路由。服务端仍以
  `DecisionReceipt + MemoryVersion` 的单条原子事务作为唯一写入权威，未新增会绕开
  Receipt 的批量写接口。
- 仅 `sensitivity=standard` 且 `reviewMode=batch` 的 Candidate 可以进入选择集；单条或
  敏感 Candidate 继续走逐条确认、纠正或拒绝，不能被误批量确认。
- 一轮批量请求在首个失败、`409` 版本冲突、Source 已失效或响应终态不匹配时停止；已成功
  的条目从 inbox 移除，未处理条目保留。相同运行期内的待处理 Candidate 保留稳定 command
  ID；强杀重开后以服务端 inbox 为准，不把旧的本地选择或成功结果当成事实。
- iOS 在 closed-pilot 候选页提供选择、确认、取消和进度反馈；普通发布态不因本 Slice
  新增入口，服务端 closed-pilot 策略仍是可见性的必要条件。
- 本 Slice 本地验证：
  - `OwnerTruthContractsTests` 共 `182` 项通过，覆盖选择性批量确认、首项成功后第二项
    `409` 的部分成功、重启后重新读取 pending inbox、稳定重试 command ID、非法选择和
    Source inactive 分类；
  - `product-v4-ios-owner-truth-candidate-client-check.py` 通过，覆盖类型合同、批量资格、
    失败分类、UI 控件和 QA 路由；
  - `run-owner-truth-candidate-inbox-smoke.sh` 通过，模拟器完成两条 Candidate 的逐条正式
    确认，并生成 `batchAcceptedCount=2`、`batchSequenceCompleted=true` 的结果；最近截图：
    `tmp/visual-qa/product-v4/owner-truth-candidate-inbox-smoke/20260802-122856/01-owner-truth-candidate-inbox.png`。
  - 本轮重新执行 `xcodebuild test -only-testing:DreamJourneyTests/OwnerTruthContractsTests`，
    `182` 项通过；`swift test` 的跨平台纯域目标 `3` 项通过；iPhoneOS generic
    `build-for-testing` 和 `git diff --check` 通过。
  - 跨平台 Package 不再直接编译 iOS App client、UIKit 或 App composition 测试；纯域层通过
    `OwnerTruthBackendFailureClassifying` 接收必要的错误分类，完整网络/UI 测试仍在 Xcode
    `DreamJourneyTests` target 中执行，避免把测试隔离误当作业务降级。
- 仍缺：真实 closed-pilot 账号、已启用的常驻 worker/profile、真实 iOS 后端数据流与强杀重开。
  服务器 disposable Postgres 已验证 Source -> Candidate -> Confirm -> Projection -> Context ->
  Correction，但这不能替代真实用户入组，因此批量 UI 不能标记为已发布或 Wave 1 完成。

## 13. 本轮提交白名单

本 Slice 只允许精确暂存以下 iOS 文件；后端改动必须独立提交在 Backend 仓库。

- `Package.swift`
- `DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift`
- `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- `DreamJourneyTests/OwnerTruthCoreContractTests.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- `DreamJourneyTests/OwnerTruthContractsTests.swift`
- `Scripts/QA/product-v4/product-v4-ios-owner-truth-candidate-client-check.py`
- `Scripts/QA/prd-stitch-ui/run-owner-truth-candidate-inbox-smoke.sh`
- `docs/superpowers/status/2026-08-02-v4-functional-closure-baseline.md`

后续每个 Slice 在开始前更新本文件的状态、提交和验证证据；不使用全仓 `git add`。

## 14. Wave 2–6 非真机闭环证据（2026-08-03）

- 后端最终提交：`dae7772 test(release): harden deployed public scope smoke`，已推送至 `main` 并部署到服务器。
- 后端统一发布门：`/tmp/dreamjourney-v4-w6-backend/v4-m0-non-device-20260803-102543/manifest.json`，状态 `passed`。该证据覆盖 migration/replay、Owner Truth、引导式访谈、推荐、家庭贡献、数据权利、Context、公开范围和部署后 Postgres 合同。
- iOS 统一发布门：`/tmp/dreamjourney-v4-w6-ios/full-20260803-104300/manifest.json`，状态 `passed`。该门覆盖：后端证据引用、`git diff --check`、6 条静态检查、AccountLease、`OwnerTruthContractsTests`、4 条模拟器 UIQA、公开 release scope regression 和 generic iPhoneOS build。
- iOS 本机验证固定使用 `com.yxj.dreamjourney.app / 2BTR77V3R8`；统一 Gate 的 XCTest 也显式传入同一项目级覆盖，避免测试落回协作默认 Bundle ID。
- 最新自然输入产品面截图：`/tmp/dreamjourney-v4-w6-ios/full-20260803-104300/uiqa/natural-input-product/full-20260803-104300/01-owner-truth-interview-natural-input-product-surface-smoke.png`。
- 该门不声明真机完成。仍需 Wave 7 验收：真实身份 Provider、麦克风/相册权限、前后台恢复、通知跳转、设备性能，以及 M1 声音复刻/数字人专项。

## 15. Wave 7 启动记录（2026-08-03）

- 真机已检测：`iPhone 17`，设备标识 `B7887DD8-3561-5F2A-8D62-A3FEACDC80D9`，状态 `available (paired)`。
- `run-true-device-voice-preflight.sh` 已生成证据目录：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260803-v4-wave7-voice-preflight/`。
- 本机设备编译被 Xcode 签名环境阻断：没有可用的 `com.yxj.dreamjourney.app` / `.widget` development profile；尝试 `-allowProvisioningUpdates` 后，Xcode 返回 `No Accounts: Add a new account in Accounts settings`。
- 真机 runner 现会在已登录账号的机器上请求刷新已有 provisioning profile；它们不会写入 Provider 密钥，也不会改动共享工程默认 Bundle ID。
- 解阻条件：在 Xcode Settings > Accounts 登录有 Team `2BTR77V3R8` 权限的 Apple Developer 账号，并确保该 Team 为 `com.yxj.dreamjourney.app` 及 `com.yxj.dreamjourney.app.widget` 提供包含当前设备的开发描述文件。之后重跑 Wave 7 预检与 PCM-drive smoke。
