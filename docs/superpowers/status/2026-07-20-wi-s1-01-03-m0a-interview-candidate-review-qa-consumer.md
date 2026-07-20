# WI-S1-01-03 M0A-10：访谈候选审核 QA 消费端

日期：2026-07-20
状态：内部就绪；QA-only、默认关闭；未接公开 Echo UI、未创建 `MemoryVersion`

## 目标与范围

为已经部署的 M0-A 访谈候选审核合同补齐 iOS 的受控消费端。该路径与既有
Candidate Inbox 明确隔离：既有 Inbox 的接受动作会进入 MemoryVersion
activation；本路径只消费访谈审核的 `DecisionReceipt`，不会写入记忆版本、
公开档案、KBLite 或 Provider。

## 已实现

- 新增独立 typed client / read model / batch command / single command，分别调用：
  - `GET /v2/vaults/{vaultId}/interview-review-batches/{reviewBatchId}/candidate-review`
  - `POST .../candidate-review/batch-accept`
  - `POST .../candidate-review/candidates/{candidateId}/decision`
- 所有请求同时要求用户会话、AccountLease request/commit fence、QA feature gate
  和 `X-DreamJourney-QA-Owner-Truth: 1` 请求头。
- 普通 `batch` Candidate 只能走批量确认；`sensitive` 或显式 `single` Candidate
  只能逐条接受、更正或拒绝。错误的跨路径选择会 fail closed。
- 回执解析强制要求 `memoryActivation.status=notApplicable` 与
  `memoryVersionCreated=false`；任何声称创建 MemoryVersion 的后端响应都会被拒绝。
- 新增 QA-only 审核页、启动场景和模拟器 smoke。公开 Archive / Echo 页面没有新增
  入口，也没有新增公开 feature flag。

## 后端基线

后端审核 API 已由 `main@81be076` 部署；`main@f19b072` 仅追加部署记录。
部署后已验证 Postgres review 合同和 `/ready`，并保持 `memories` 与
`memory_versions` 不被该审核路径写入。此 iOS smoke 使用受控 mock client 验证
客户端行为，不将其误记为一次线上 iOS 网络验收。

## 验证证据

- `python3 Scripts/QA/product-v4/qa-launch-configuration-static-check.py`：通过。
- `python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-candidate-client-check.py`：通过。
- `xcodebuild test ... -only-testing:DreamJourneyTests/OwnerTruthContractsTests`：41/41 通过。
- `SIMULATOR_UDID=605B899B-77F1-4AA1-8642-15803FE5B647 bash Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-review-smoke.sh`：通过。
  - 普通 batch Candidate 可见并完成 batch accept。
  - sensitive single Candidate 可见并完成逐条 reject。
  - 两份 receipt 均被消费，`allCandidatesRemoved=true`，
    `memoryVersionCreated=false`。
  - 截图：`tmp/visual-qa/product-v4/owner-truth-interview-candidate-review-smoke/20260720-223958/01-owner-truth-interview-candidate-review.png`。
- `xcodebuild build -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`：通过。
- 本工作项文件的 `git diff --check`：通过。

## 保持的边界

- 此处不是公开产品入口，也不改变现有全屏 Echo 视觉结构。
- 不调用普通 Candidate Inbox / MemoryVersion activation 路径。
- 不扩大到真实 Provider、后台 worker、发布副本、家庭访问或跨 Vault 数据。
- 尚未把 iOS 真正连接到部署 API 做端到端网络验收；该项只能在对应 G1/G2 条件满足时单独进行。

## 后续

继续从 `WI-S1-01-03` 的下一个未重复、依赖已满足的 M0-A 边界中选择小闭环；
任何公开 Echo UI、MemoryVersion activation 或跨账号访问都必须先经过其独立 Gate，
不能由本 QA 消费端推断为已完成。
