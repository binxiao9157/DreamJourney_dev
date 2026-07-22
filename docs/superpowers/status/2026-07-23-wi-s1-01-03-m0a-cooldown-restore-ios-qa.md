# WI-S1-01-03 M0-A 冷却期恢复 iOS QA

日期：2026-07-23

## 结论

`以后再聊` 的服务端语义此前已经存在：冷却期内不进入推荐，到期后可作为连续性推荐的最高优先来源；实际恢复仍必须通过服务端时钟校验的独立 `restore-cooldown` 合同。本轮补齐 iOS 对该既有合同的 typed QA 消费与回归证据，不新增公开 Echo 功能。

## 本轮实现

- 新增 `OwnerTruthInterviewRestoreCooldownCommand`，payload 仅含 `commandId`、`threadId`、`expectedSessionVersion`；客户端不能传入或缩短 `cooldownUntil`。
- `OwnerTruthInterviewNaturalInputUseCase` 仅在当前回执为 `paused + cooldown` 时调用恢复命令，并继续复用 AccountLease 的 request/commit 双侧围栏与 generation 丢弃规则。
- `DreamJourneyBackendClient` 只在 `DJEnableOwnerTruthCandidateReviewQA` 开启时调用既有 `/restore-cooldown`；不复用 release-policy transport。
- QA-only 控件和 UIQA scenario 验证 `cooldown -> restore -> active/open -> canContinue`。控件仍位于 `#if DEBUG || UI_QA_SIMULATOR`，Release 不创建。

## 验证

```bash
python3 Scripts/QA/product-v4/owner-truth-interview-boundary-qa-surface-check.py

xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests \
  CODE_SIGNING_ALLOWED=NO \
  test

Scripts/QA/prd-stitch-ui/run-owner-truth-interview-boundary-smoke.sh

xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

结果：静态检查通过；`OwnerTruthContractsTests` 65 项通过；模拟器 UIQA 完成且 `cooldownRestoreCompleted=true`、`doNotAskRestoreCompleted=true`；Release 模拟器构建通过。

本轮 UIQA 产物：

- 结果：`tmp/visual-qa/product-v4/owner-truth-interview-boundary-smoke/20260723-070549/owner-truth-interview-boundary-uiqa-result.json`
- 截图：`tmp/visual-qa/product-v4/owner-truth-interview-boundary-smoke/20260723-070549/01-owner-truth-interview-boundary.png`

## 未关闭边界

- 服务端时钟、早于到期时间的拒绝、幂等恢复仍由已部署的 Postgres smoke 覆盖；本轮 in-memory UIQA 不替代该验证。
- 不实现自然语言主题再识别、用户输入与禁问主题的自动匹配、自动重新开启或公开 Echo 入口；这些涉及独立的 topic identity/matching 语义与产品决策。
- 不创建 Candidate、Memory、Provider effect，也不修改后端或触发新的部署。
