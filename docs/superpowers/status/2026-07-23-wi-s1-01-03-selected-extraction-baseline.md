# WI-S1-01-03 候选提取审核基线收敛

- 日期：2026-07-23
- 范围：Owner Truth 私有访谈 Candidate 的审核读取边界。
- 状态：后端 G0/G2 已验证；iOS typed 读取保护已验证；公开产品入口仍默认关闭。

## 问题

同一已准入 Source/版本可能保留多个不可变 `ExtractionResult`，例如历史
processor、model 或 prompt 版本已经写入结果。旧实现只用最新一次结果计算
`latestExtractionStatus`，但审核 Candidate 查询会把所有成功结果的 pending
Candidate 合并到同一个审核批次。这样会混入不同提取基线的建议。

## 已实现边界

1. 后端 review composition 选择同一 Source/version 下最新的成功
   `ExtractionResult` 作为唯一 `selectedExtractionId`。
2. `latestExtractionStatus` 仍反映最新一次尝试的状态；若更新后的尝试失败，
   最近一次成功基线的待审核 Candidate 保留可见，避免临时失败使 Owner 的待审
   内容消失。
3. composition 不允许 Candidate 与 `selectedExtractionId` 混用。
4. iOS typed contract 解析 `selectedExtractionId`，并在服务端返回混合
   Candidate baseline 时 fail-closed；旧服务器未返回该字段时，也只接受单一
   extraction ID 的兼容响应。
5. 该改动不创建 MemoryVersion、不改变 Candidate 决策写入、不开放任何 UI。

## 历史结果与 effect 幂等

现有 Source effect consumer 设计为同一个 effect 只完成一次，不能把第二次
提取当成同一 effect 的正常重放。线上 smoke 因此在隔离临时数据库中经现有
Extraction repository 写入历史不可变结果，只验证 review read-side 对既有
历史数据的选择规则；它不改变 effect 幂等约束，也不宣称已启用生产重提取。

## 验证

本地通过：

```text
.venv/bin/python -m unittest tests.test_owner_truth_interview_candidate_review tests.test_owner_truth_interview_candidate_batch_decision tests.test_owner_truth_interview_candidate_single_review tests.test_owner_truth_interview_candidate_review_api
./scripts/verify_backend.sh
swiftc -parse DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift DreamJourneyTests/OwnerTruthContractsTests.swift
xcodebuild test -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'platform=iOS Simulator,id=F54C960B-005F-434A-81E2-557D21AF14ED' -derivedDataPath tmp/visual-qa/v4-selected-extraction-baseline -only-testing:DreamJourneyTests/OwnerTruthContractsTests
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphoneos -derivedDataPath tmp/visual-qa/v4-selected-extraction-baseline/iphoneos-generic CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app DEVELOPMENT_TEAM=2BTR77V3R8 build
git diff --check
```

结果：后端 focused tests `25` 通过、API tests `6` 通过、全量
`verify_backend.sh` 通过；iOS `OwnerTruthContractsTests` 执行 `59` 项，全部
通过；generic iPhoneOS Debug build 通过。

部署验证：

```text
backend main@f383e1b, then main@179efbd
/ready -> status=ready
docker compose exec api: python scripts/backend-owner-truth-conversation-postgres-smoke.py
owner_truth_conversation_postgres_smoke=passed
```

该 smoke 创建并清理独立临时 Postgres 数据库，未写入现有业务数据。

## 非目标与后续

- 不是重新处理/重提取功能；如要允许同一 Source 的新 processor 执行，必须先
  为新的 effect admission 与 supersession 生命周期单独设计 Work Item。
- 不因该证据调整保守 Registry 的 `PLANNED/STOP` 计划状态。
- 后续仍按 current handoff 选择下一个不重复的 G0 子切片。
