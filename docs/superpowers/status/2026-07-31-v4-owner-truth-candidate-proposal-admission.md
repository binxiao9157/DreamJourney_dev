# Owner Truth：确认后开始整理（M0-A）

日期：2026-07-31

## 状态

`VERIFIED_LOCAL / DEFAULT_OFF / BACKEND_CONTRACT_ALREADY_DEPLOYED`

本轮把已部署的正式 Candidate Proposal Admission 合同接入 iOS 自然输入 Sheet。它不是候选生成、候选确认或记忆激活完成态。

## 用户与权限边界

1. 正常结束当前 Owner 访谈后，Sheet 进入 `reviewPending`。
2. 用户先执行“确认本次分享”，只冻结一个当前、精确且不透明的 review batch/version 边界。
3. 只有在单独的 `ownerTruthCandidateReview` feature flag 与 release policy 都允许时，才显示“开始整理”。
4. 用户显式点击后，客户端只发送 `commandId` 与 `expectedReviewBatchVersion`；服务端回传值最小化 receipt，表示私有 Source / effect 已进入整理队列。
5. 后续 Candidate 的查看、接受、修正和 MemoryVersion 激活仍在独立 Archive 确认流程中完成。

因此，确认分享不会自动开始整理；开始整理不会直接生成或展示 Candidate，也不会写入 Memory。

## iOS 约束

- `OwnerTruthInterviewCandidateProposalAdmissionUseCase` 使用当前 `AccountLease` 做请求和提交阶段围栏。
- `DreamJourneyBackendClient` 为 admission 单独使用 `ownerTruthCandidateReview` 策略；不使用 `echoTextInput`，不附加 QA header。
- receipt 严格拒绝 Source ID、Candidate 内容、Memory、provider 数据和其他未约定字段。
- 公开发布态默认不显示该入口；UIQA 仅通过内存 client 和显式策略 fixture 打开。

## 验证证据

- iOS XCTest：`OwnerTruthContractsTests`，149 项通过。
- 静态检查：
  - `Scripts/QA/product-v4/owner-truth-candidate-proposal-admission-check.swift`
  - `Scripts/QA/product-v4/owner-truth-pending-review-batch-acknowledgement-check.swift`
  - `Scripts/QA/product-v4/owner-truth-candidate-confirmation-presentation-check.swift`
- 发布回归：准入静态守卫已编排进 `Scripts/QA/prd-stitch-ui/run-release-regression.sh`，避免后续常规 release gate 漏检该边界。
- 模拟器 UIQA：
  `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-product-surface-smoke.sh`
  已覆盖 `ended -> acknowledged -> admitted`，无网络请求、无持久化写入。
- 截图：
  `tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260731-212745/01-owner-truth-interview-natural-input-product-surface.png`
- 后端合同：`DreamJourneyBackend main@e7dccd6` 已存在对应 route；本轮没有后端源码、迁移或部署变更。

## 未声明的范围

本轮不宣称真实语义提取质量、Candidate worker 启用、生产数据库写入、公开功能发布、Provider 调用或真机验收。它只完成 iOS 受策略控制的正式 admission 消费面与可重复本地证据。
