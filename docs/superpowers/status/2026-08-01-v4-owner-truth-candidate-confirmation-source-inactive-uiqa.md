# V4：候选确认详情来源失效终态 UIQA

日期：2026-08-01

## 状态

`VERIFIED_LOCAL / DEFAULT_OFF / G1_ADDITIONAL_EVIDENCE / NO_BACKEND_OR_PUBLIC_UI_CHANGE`

## 本轮目的

`WI-S1-01-06` 的候选确认动作和读取 use case 已能把
`ownerTruthCandidateSourceInactive` 映射为 `contentUnavailable`，且已有
合约测试。此前缺少模拟器交互证据，无法直接证明候选在页面上已经显示后，
来源变为不可用时，旧内容会被清空并进入不可继续操作的终态。

本轮新增默认关闭的 UIQA 变体。它复用确认详情的内存端口，不访问真实
Candidate 路由、不写入持久化数据、不修改公开页面、发布策略、后端或
Provider。

## 实现

1. 将既有确认详情 fail-closed 内存夹具收敛为两种模式：
   `responseMismatch` 与 `sourceInactive`。
2. 新增 QA-only launch scenario：
   `DJRunOwnerTruthInterviewCandidateConfirmationSourceInactiveSmoke`。
3. 来源失效夹具先返回一条可确认候选；批量确认动作返回
   `ownerTruthCandidateSourceInactive`；自动重新读取也返回同一类型错误。
4. 断言重新读取期间旧候选立即清空、提交按钮隐藏且禁用、列表和刷新锁定；
   结束后进入 `unavailable`，没有候选内容，也没有可用刷新入口。
5. 结果只包含布尔值、计数、状态枚举、公共 UI 文案和 launch argument；
   不输出候选正文、Vault、Source、Memory 或收据标识。

## 验证

```bash
bash Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-confirmation-source-inactive-smoke.sh
```

结果：通过。

- `actionRequestCount=1`
- `confirmationReadCount=2`
- `failureDisposition=sourceInactive`
- `oldCandidateClearedDuringReload=true`
- `batchSubmitHiddenDuringReload=true`
- `batchSubmitDisabledDuringReload=true`
- `listInteractionDisabledDuringReload=true`
- `refreshDisabledDuringReload=true`
- `terminalSourceInactiveState=true`
- `finalPhase=unavailable`
- `finalCandidateCount=0`
- `candidateRouteNetworkRequests=0`
- `persistentCandidateWrites=0`

截图与运行结果：

`tmp/visual-qa/product-v4/owner-truth-interview-candidate-confirmation-source-inactive-smoke/20260801-003928/`

截图确认只显示来源失效的终态说明；候选列表、确认按钮和可用刷新入口均不存在。

其他回归：

```bash
swift Scripts/QA/product-v4/owner-truth-candidate-proposal-status-handoff-check.swift
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
bash Scripts/QA/product-v4/run-ios-owner-truth-kblite-compatibility-gate.sh
```

结果：全部通过。最后一条包括 `OwnerTruthContractsTests` 与无签名通用
`iPhoneOS build-for-testing`。

## 范围说明

- 本证据只证明 iOS 确认详情在来源失效时的 fail-closed 交互边界。
- 未因此把 `WI-S1-01-06` 整项标为完成；Registry 保持保守状态。
- 未部署、未推送、未进行真机验证。
