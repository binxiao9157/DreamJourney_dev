# WI-S1-01-03 M0-A：产品态访谈边界控制

日期：2026-07-31
iOS 基线：`feature/prd-stitch-ui-adaptation@4903bd3`（本地提交前）
后端基线：无变更；复用已存在的受策略保护访谈边界合同。

## 问题与范围

自然输入产品 Sheet 已可在 `echoTextInput` 的既有发布策略授权后创建和追加访谈会话，但用户无法在产品态明确选择：

- 这次先跳过；
- 以后再聊；
- 不再问。

这些语义和后端合同已经存在，缺口只在 iOS 产品展示层。此前所有边界控件都被编译为 QA-only，和终版 M0-A 的用户控制要求不一致。

本轮只补齐这个产品态缺口：

1. 产品 Sheet 在发送按钮下方显示紧凑横排的三项边界控制。
2. 三项操作继续复用已有 `OwnerTruthInterviewBoundaryCommand`、AccountLease 和当前 session-version 围栏。
3. 当用户选择“不再问”后，显示“重新开启这个话题”；恢复仍经过已有独立 `restore-do-not-ask` 合同和二次确认弹窗。
4. QA-only 的话题切换、节奏记录、冷却恢复继续只在 `DEBUG || UI_QA_SIMULATOR` 编译条件和 QA presentation 中存在。

## 不包含

- 不改变 Echo 全屏视觉、Tab、普通回响或数字人链路。
- 不改变 `echoTextInput` 默认发布策略；产品入口仍由 Echo 的 fresh policy 决定，策略未授权时不展示。
- 不把 Candidate review、Memory 生成、主题自动识别、冷却策略或 QA 调试操作开放到产品态。
- 不新增后端路由、迁移、Provider 调用、部署或真机结论。

## 实现

`OwnerTruthInterviewNaturalInputViewController` 现在按 presentation 分开组织控件：

- `.product`：`这次先跳过 / 以后再聊 / 不再问`，以及仅在 `doNotAsk` 状态可见的恢复按钮；
- `.qa`：保留原有纵向边界、话题切换、节奏、冷却恢复调试面板；Release 编译不创建 QA-only 控件。

产品态的三项按钮以横排展示，避免把 QA 面板的多行操作直接带入正式 Sheet。恢复禁问话题仍由 `UIAlertController` 要求用户点击“确认恢复”，不通过通用 `boundary=open` 重开。

新增静态检查：

```bash
python3 Scripts/QA/product-v4/owner-truth-interview-product-boundary-surface-check.py
```

该检查同时约束：产品态可见的三项操作、独立恢复命令、确认弹窗、以及 QA-only 控件不泄漏到产品态。

## 验证

本地通过：

```bash
python3 Scripts/QA/product-v4/owner-truth-interview-product-boundary-surface-check.py
python3 Scripts/QA/product-v4/owner-truth-interview-boundary-qa-surface-check.py

xcodebuild test -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests \
  CODE_SIGNING_ALLOWED=NO

Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-product-surface-smoke.sh
Scripts/QA/prd-stitch-ui/run-owner-truth-interview-boundary-smoke.sh

xcodebuild build -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

结果：

- `OwnerTruthContractsTests`：124/124 通过，包含产品态只暴露三项边界、禁问后显示恢复入口的断言。
- 产品态模拟器 smoke：通过，结果含 `productBoundaryControlsVisible=true`、`qaOnlyBoundaryControlsHidden=true`。
- QA 边界 smoke：通过，三种边界、禁问恢复和冷却恢复均保持原有行为。
- Release generic iOS build：通过。

产品态截图：

`tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260731-004024/01-owner-truth-interview-natural-input-product-surface.png`

## Gate 结论

这是 `WI-S1-01-03` 的本地 G1 产品展示增量，不等于公开发布或全 M0-A 完成。它只在已有 `echoTextInput` 发布策略明确允许时才可达；后端、生产数据、部署、Provider 与真机状态均未作新的声明。

此前的 QA 恢复合同证据见：
`docs/superpowers/status/2026-07-23-wi-s1-01-03-m0a-do-not-ask-confirmed-restore.md`。
