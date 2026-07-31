# V4：候选确认详情 Response Mismatch Fail-Closed UIQA

日期：2026-08-01

## 状态

`VERIFIED_LOCAL / DEFAULT_OFF / G1_ADDITIONAL_EVIDENCE / NO_BACKEND_OR_PUBLIC_UI_CHANGE`

## 本轮目的

`WI-S1-01-06` 的候选确认详情此前已有 use case 与 UIKit 静态/单元测试，
但没有可重复的模拟器交互证据证明：批量确认返回与当前选择不一致的结果后，
旧 Candidate 内容会在下一次读取完成前立即失效，而不会继续显示或可操作。

本轮只补这一条默认关闭的模拟器 UIQA 路径。它不替代既有的
review-ready 收件箱交接 smoke；后者继续证明仅当前 review batch 可进入
收件箱，并且不会自动提交确认动作。

## 实现

1. `OwnerTruthInterviewCandidateConfirmationViewController` 在候选确认动作触发
   自动重新读取时保留本次 fail-closed 原因文案，直到读取完成；不再被通用
   “正在读取确认线索”覆盖。
2. 新增 QA-only launch scenario：
   `DJRunOwnerTruthInterviewCandidateConfirmationFailClosedSmoke`。
3. 新增纯内存夹具，显式注入 confirmation reader、batch action client 和
   single action client。夹具构造类型合法、但候选 ID 与当前 command 不一致的
   batch result，触发正式 `responseMismatch` 路径。
4. 结果文件只保留布尔值、计数、状态枚举和 launch argument；不导出候选正文、
   Vault、Source、Memory 或 DecisionReceipt 标识。
5. 结果断言：动作只提交一次；初始读取后发生一次新读取；重新读取期间旧候选
   数为零、提交按钮隐藏、列表和刷新不可操作；最终读取为空态且不恢复旧候选。

## 验证

```bash
swift Scripts/QA/product-v4/owner-truth-candidate-proposal-status-handoff-check.swift
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
```

结果：通过。QA 场景库存为 55 项；新增场景属于 AccountLease 敏感的独立
详情路由，不与既有 read-only 收件箱 smoke 混淆。

```bash
bash Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-confirmation-fail-closed-smoke.sh
```

结果：通过。结果包含：

- `actionRequestCount=1`
- `confirmationReadCount=2`
- `oldCandidateClearedDuringReload=true`
- `batchSubmitHiddenDuringReload=true`
- `listInteractionDisabledDuringReload=true`
- `refreshDisabledDuringReload=true`
- `staleActionStatusVisibleDuringReload=true`
- `finalPhase=empty`
- `candidateRouteNetworkRequests=0`
- `persistentCandidateWrites=0`

模拟器结果与截图：

`tmp/visual-qa/product-v4/owner-truth-interview-candidate-confirmation-fail-closed-smoke/20260801-001354/`

```bash
bash Scripts/QA/product-v4/run-ios-owner-truth-kblite-compatibility-gate.sh
```

结果：通过，包括 Owner Truth focused tests 与无签名通用 iPhoneOS
`build-for-testing`。

## 范围说明

- `candidateRouteNetworkRequests=0` 仅描述本 smoke 显式注入的 Candidate
  read/write 路径；不把整个 App 进程的后台 policy 刷新泛化为零网络声明。
- 未新增真实后端写入、路由、数据库迁移、Provider 调用、发布入口或真机结论。
- 未修改 V4 Registry 的保守状态，也不据此宣称 `WI-S1-01-06` 整项完成。
