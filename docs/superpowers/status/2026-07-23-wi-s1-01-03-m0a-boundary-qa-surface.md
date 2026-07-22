# WI-S1-01-03 M0A-26：访谈边界操作 QA Surface

日期：2026-07-23

iOS 基线：`feature/prd-stitch-ui-adaptation@303e168`

后端基线：`main@a45170d`（本轮未变更）

## 本轮范围

为已完成 AccountLease 围栏的正式访谈边界命令增加可重复的 **QA-only** 交互验证。

- 仅在 `presentation == .qa` 且 `DEBUG || UI_QA_SIMULATOR` 构建分支创建三个操作：`本轮跳过`、`以后再聊`、`不再问`。
- 控件复用 `OwnerTruthInterviewNaturalInputUseCase` 的 `setBoundary`，不新增 transport、payload 或后端路由。
- UIQA 使用 in-memory client，分别验证：
  - `skipOnce -> active -> readyForNarrative -> canContinue=true`
  - `cooldown -> paused -> canContinue=false -> canContinueLater=true`
  - `doNotAsk -> paused -> canContinue=false -> canContinueLater=false`
- Release 构建会编译掉该控件配置；没有公开 Echo 入口、没有产品导航变更。

## 明确不包含

- 不允许 `open` 或重新开启会话。
- 不提交文字，不写 Candidate、Memory、Provider effect 或持久化数据。
- 不改生产后端、不部署后端、不改变 Authority 或 ReleasePolicy。
- 不把 QA 控件视为公开产品功能。

## 验证

1. `OwnerTruthContractsTests`：62 个测试通过，复用 M0A-25 的 boundary/lease/continuation 合同覆盖。
2. `owner-truth-interview-boundary-qa-surface-check.py`：通过，校验 QA presentation、Release 编译分支、禁止 `open`、独立 launch scenario 和 smoke 脚本。
3. `run-owner-truth-interview-boundary-smoke.sh`：通过；三种边界均由实际 UIButton target 触发，结果 JSON 为 `completed=true`。
4. 既有 `run-owner-truth-interview-natural-input-smoke.sh`：通过，确认文字自然输入 QA 路径未回归。
5. `xcodebuild build`：Debug 与 Release 的 `generic/platform=iOS` 构建均通过。
6. `git diff --check`：通过。

模拟器证据：

`tmp/visual-qa/product-v4/owner-truth-interview-boundary-smoke/20260723-022626/01-owner-truth-interview-boundary.png`

## Gate 结论

- 本轮为 `WI-S1-01-03` 的 scoped G0/G1 QA 交互证据。
- 其后端正式边界 G2 证据仍以 `main@a45170d` 为准；本轮不需要部署。
- G3/G4、公开发布、真实产品交互和生产 Authority 切流仍未完成。
