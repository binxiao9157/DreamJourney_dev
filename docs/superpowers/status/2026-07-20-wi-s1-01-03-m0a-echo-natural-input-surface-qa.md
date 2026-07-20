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
