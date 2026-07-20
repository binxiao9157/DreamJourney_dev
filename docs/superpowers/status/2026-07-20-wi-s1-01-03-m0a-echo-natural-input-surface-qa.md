# WI-S1-01-03 M0-A Echo 自然输入 QA Surface

## 本轮范围

本轮为已完成的私有访谈自然输入合同增加一个 **仅 QA 可见** 的 Echo 入口。入口是话筒
旁的键盘图标，点击后以底部 Sheet 打开现有自然输入控制器。它不改变公开全屏 Echo 的
布局、默认交互或发布态信息架构。

入口同时要求以下两个条件：

```text
DJEnableOwnerTruthCandidateReviewQA
DJShowOwnerTruthInterviewNaturalInputEntryQA
```

并被 `#if DEBUG || UI_QA_SIMULATOR` 包围；Release 构建中固定为不可见。

## 行为边界

- 人工 QA 点击入口时，控制器仍使用已部署的自然输入后端合同；会话创建和文本追加继续受
  AccountLease、QA header、线程/会话版本栅栏约束。
- 自动 UIQA smoke 使用内存 fake client，只验证入口、Sheet 和渲染，不发起网络请求，
  不持久化会话或输入，也不启动麦克风、腾讯数智人或语音播放。
- 本轮不会创建 Source、Candidate、DecisionReceipt、MemoryVersion、Projection、provider
  请求、legacy Archive/KBLite 写入；也没有将自然输入公开给普通用户。

## 验证证据

- `Scripts/QA/product-v4/owner-truth-interview-natural-input-echo-surface-check.py` 通过，确认
  入口受双 QA Gate 与编译期开关限制，并检查 smoke 不触发语音、数字人或持久化写入。
- `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-echo-surface-smoke.sh` 通过。
  结果包含：`completed=true`、`entryVisible=true`、`sheetPresented=true`、
  `backendNetworkStarted=false`、`persistentInterviewWriteStarted=false`、
  `voiceTurnStarted=false`、`digitalHumanSessionStarted=false`。
- `OwnerTruthContractsTests` 定向 XCTest 通过。
- 通用 `generic/platform=iOS` Debug 编译通过（`CODE_SIGNING_ALLOWED=NO`）。
- 截图：
  `tmp/visual-qa/product-v4/owner-truth-interview-natural-input-echo-surface-smoke/20260720-235140/01-owner-truth-interview-natural-input-echo-surface.png`。

截图中的 Sheet 只会在 UIQA 模式出现，不能作为公开 UI 设计变更依据。

## Gate 结论

- G0：Echo 到自然输入 QA surface 的租约绑定与副作用隔离已验证。
- G1：仅模拟器 QA Sheet 已验证；公开 Echo 仍未接入。
- G2：无新增后端变更；沿用已部署自然输入命令合同。
- G3：外部 provider 生成保持未启用。

## 后续边界

下一步需要记录 M0-A 公开产品 surface Gate，明确自然输入是否、何时以及以什么交互进入
公开 Echo。在该 Gate 完成前，入口继续保持 QA-only/default-off。

## 2026-07-21 受控产品入口更新

本节取代上文“公开 Echo 未接入”的旧表述，但不改变 QA 入口的隔离边界。

- 新增的产品入口位于现有全屏 Echo 内，显示文案为“今天想聊点什么？”。初始状态始终隐藏，
  只有 iOS 获得新鲜 echoTextInput 发布策略，并同时满足 route 可见和 write decision 时
  才显示；策略缺失、过期、刷新失败、账号切换或语音回合进行中都会重新隐藏。
- 产品态 Sheet 只展示面向用户的标题、说明和发送操作；不展示 QA、线程版本或回执等内部
  信息。既有背景、底部 Tab、话筒和语音主链路不变。
- 产品客户端每次创建会话或追加文本都重新携带 captured policy。后端新增正式授权路径：
  缺少或拒绝 echoTextInput policy 时返回 403 release_policy_denied，不能退回 QA header
  或默认放行。QA 路径仍需要显式 QA header，兼容已有受控验证。
- 新产品态 UIQA 使用内存 client，只验证布局和文案；结果中显式标记
  inMemoryPreview=true 与 releasePolicyBypassedForPreview=true，不构成线上策略许可，也
  不会发起网络写入、持久化写入、语音回合或数字人 session。

本轮验证：

- 后端 tests.test_owner_truth_interview_input_api、tests.test_owner_truth_interview_session_state_api
  和 tests.test_release_policy 共 36 项通过，覆盖无 captured policy 拒绝、匹配 policy
  允许及 QA 兼容。
- owner-truth-interview-natural-input-echo-surface-check.py 通过，确认 QA 双 Gate 仍保留，
  产品入口要求 fresh policy、route decision 和 write decision。
- 两条 Simulator UIQA smoke 均通过；产品态截图位于
  tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260721-045259/01-owner-truth-interview-natural-input-product-surface.png。
- Swift parse、git diff --check、Simulator UIQA build 与 generic/platform=iOS Debug build
  均通过。

Gate 结论：本轮为本地 G0/G1 scoped evidence。后端授权逻辑尚待部署和线上 Postgres smoke，
G4 cohort、产品和隐私发布决策仍开放，因此不得将其称为公开发布。

## 2026-07-21 后端 G2 部署验证

- 后端提交 `db95a5f feat(m0): gate natural interview input by release policy` 已推送并部署至
  `miao-server`，API 容器已重建且 `/ready` 的 database、schema、auth、incident 均为 ready。
- 新增部署容器 smoke
  `scripts/run-backend-owner-truth-interview-natural-input-deployed-smoke.sh`。它先读取线上
  `echoTextInput` 策略快照，再在一次性 Postgres 临时数据库中验证：缺少 capture 必须返回
  `release_policy_denied`，匹配 capture 可以创建、追加和读取会话，读取结果不回显叙事内容。
- 部署 smoke 通过，摘要为：`formalMissingCaptureDenied=true`、
  `formalMatchingCaptureStarted=true`、`formalMatchingCaptureAppended=true`、
  `formalMatchingCaptureRead=true`、`contentFreeStateVerified=true`、
  `productionBusinessDataMutated=false`，临时库迁移头为 `0035`。

Gate 结论：本 slice 的正式自然输入授权 G2 已部署验证；产品入口仍默认隐藏且受策略控制。
G4 cohort、产品和隐私放行仍开放，因此这不是公开发布结论。

## 2026-07-21 Slice 3D 继续/待确认摘要

- 后端提交 `8cb6a0d feat(m0): add interview continuation presentation` 已推送并部署。
  新增受既有自然输入授权约束的 `GET /v2/vaults/{vaultId}/interview-sessions/{sessionId}/presentation`。
  它只返回 `readyForNarrative`、`narrativeRecorded`、`reviewPending`、`paused` 或 `ended`，以及
  `canContinue` 和 `canContinueLater`；不返回输入文本、Candidate 内容、review ID、轮次、疲劳值
  或内部 thread/session 状态。
- iOS 产品态 Sheet 仅将上述状态映射为自然文案。例如，输入记录后显示“这段分享已经留好”，
  并提示“想起来时，可以继续补充”；待确认时只提示“有内容等待你确认”，不泄露待确认内容。
  服务端摘要读取失败不会撤销已经成功的自然输入回执。
- 产品态 UIQA 在内存 client 中提交固定文本后验证 `narrativeRecorded` 摘要、已清空输入框和
  既有全屏 Echo 视觉不变；整个验证不发起网络、持久化写入、语音回合或数字人 session。
- 后端路由已登记为 `USER_SESSION`，避免正式授权路径被路由鉴权层误判为未分类。

本轮验证：

- 后端定向路由/自然输入测试通过，完整 `./scripts/verify_backend.sh` 通过（1055 tests）。
- 已部署的自然输入 smoke 通过，确认 `contentFreePresentationVerified=true`、
  `formalMatchingCapturePresentation=true`，并在一次性 Postgres 临时库中执行，
  `productionBusinessDataMutated=false`。
- `swiftc -parse`、
  `Scripts/QA/product-v4/owner-truth-interview-natural-input-echo-surface-check.py`、
  `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-product-surface-smoke.sh`、
  `git diff --check` 与通用 `generic/platform=iOS` Debug build 均通过。
- 本轮截图：
  `tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260721-051527/01-owner-truth-interview-natural-input-product-surface.png`。

Gate 结论：该摘要/继续态为 G0、G1 scoped 和 G2 deployed evidence。产品入口仍默认隐藏、继续
受发布策略控制；本轮没有把 QA Candidate review API 或候选内容开放到产品态。下一条边界只能
先定义受策略保护的产品确认合同，不能复用 QA review 路由直接暴露私有候选内容。

## 2026-07-21 Slice 3E 默认关闭的产品确认读取合同

- 后端提交 `79a0504 feat(m0): add policy-bound candidate confirmation read` 已推送并部署至
  `miao-server`。新增
  `GET /v2/vaults/{vaultId}/interview-review-batches/{reviewBatchId}/confirmation`，它与既有
  QA Candidate review 路由完全分离。
- 新路由只接受服务端签发且仍有效的 `ownerTruthCandidateReview` captured policy；该 feature
  默认不在 closed-pilot 可见集合中。缺少 capture、过期 capture 或只携带 QA header 均返回
  `403 release_policy_denied`，不能借用 QA 通道绕过产品策略。
- iOS 仅登记 feature 和后端路由归属，将其归为 owner text core；它是 non-persistent、默认关闭
  的能力。本轮没有新增产品 UI、路由入口或自动读取逻辑，因此公开 Echo 不会出现候选内容。
- 返回体只在未来获得正式 release-policy 许可时才包含 owner-scoped confirmation 与候选项；当前
  没有把它接到自然输入 Sheet，也没有触及任何 Candidate 接受、记忆激活或发布写入。

本轮验证：

- 后端定向 Candidate confirmation API 测试通过；完整 `./scripts/verify_backend.sh` 通过
  （1057 tests），并已更新 route ownership inventory 为 103 条、无未分类路由。
- `swiftc -parse` 和通用 `generic/platform=iOS` Debug build 通过；iOS 路由归属映射不会改变
  默认发布态。
- `Scripts/QA/product-v4/owner-truth-candidate-confirmation-default-off-check.swift`、
  `release-feature-matrix-check.swift` 与 feature-gate evaluator smoke 通过，确认新 feature 不在
  默认启用集合、不持久化，且 confirmation 路由只映射到该独立 feature。
- 部署容器 smoke 使用一次性 Postgres 临时库通过，确认
  `deployedCandidateReviewPolicyDefaultClosed=true`、
  `formalCandidateConfirmationDenied=true`、`productionBusinessDataMutated=false`，迁移头为
  `0035`。

Gate 结论：确认读取合同已有 G0/G2 证据，但仍为 default-off，尚未拥有 G1 产品消费面。下一步如
需继续，只能先建立 typed iOS QA consumer 与受策略控制的可读展示，不能直接公开 Candidate
内容或连接现有 QA review 写入路由。

## 2026-07-21 Slice 3F 默认关闭确认 typed iOS consumer

- iOS 新增 `OwnerTruthInterviewCandidateConfirmation`、只读 client port 和
  `OwnerTruthInterviewCandidateConfirmationUseCase`。它只解析后端 confirmation envelope；没有
  Candidate 接受、修正、拒绝、MemoryVersion 激活或 legacy Archive/KBLite 写入能力。
- use case 默认 `releasePolicyAvailable=false`。未显式提供已捕获的产品策略时，刷新请求直接
  失败关闭为 `releasePolicyDisabled`，不发起网络请求；请求和回调提交都执行 AccountLease 校验，
  账号切换后的延迟结果会被丢弃。
- `DreamJourneyBackendClient` 读取正式 `/confirmation` 路由时重新捕获
  `ownerTruthCandidateReview` FeatureDecision，并将其传入 `requestJSON`。该请求不带
  `X-DreamJourney-QA-Owner-Truth`，不能借用 QA review 通道，也不依赖其写入 API。
- 本轮没有新增产品入口、Sheet、自动读取、候选内容展示或发布策略放行；默认公开版本仍看不到
  任何确认内容。是否进入产品确认 surface 仍是后续独立的产品/G1 决策。
- 为使定向 XCTest 重新成为可信门，补齐了既有自然输入测试桩遗漏的 continuation read 协议方法；
  其默认失败是 advisory read 行为，不影响已成功的输入回执，也不改变产品功能。

本轮验证：

- `OwnerTruthContractsTests` 在 iPhone 17 Pro Simulator 通过：51 项、0 failures。
- `swiftc -parse`、candidate confirmation default-off static check、release feature matrix check、
  feature-gate evaluator model smoke、`git diff --check` 全部通过。
- 通用 `generic/platform=iOS` Debug build（`CODE_SIGNING_ALLOWED=NO`）通过。

Gate 结论：该 typed consumer 获得 G0 scoped evidence；G2 复用已部署 confirmation read 合同。
没有新增 G1 可视 surface，也没有缩短 G4 产品/隐私放行路径。
