# Round 3C2 iOS、API 与 AuthZ 双轨 Rollout 结果

## Summary

Round 3C2 已形成设备内账号生命周期与服务端 API/AuthZ 切流的统一合同：iOS 通过 AccountSessionActor/Lease/generation/epoch 阻止晚到结果和跨账号 store 污染；API 通过 typed principal/route policy/AuthZ/DB 约束阻止伪造 owner 和 error-driven legacy fallback。两侧以同一 subject/vault/session/authorityEpoch/ReleasePolicy snapshot 对接。

## Done

- P037 / R028：AccountSessionActor、refresh CAS、17 类 store、9 个 iOS waves、20 个竞态场景。
- P038 / R029：5 auth modes、5 route modes、9 AuthZ groups、11 API waves、20 个安全场景。
- 冷启动只信已验证 session，本地 profile 不再决定认证。
- 旧 callback/timer/runtime/store commit 需要 AccountLease；A 结果不能写 B。
- 401/403/404/409/5xx/timeout/contract error 不触发 legacy mutation fallback。
- client shared/provider credential 必须移除并由最终 artifact/header scan 证明。
- Capability 分 enabled/providerReady/releaseVisible/externalVerified 四轴。
- DR-041 登记本地草稿保留边界；DR-023/040 等保持开放门。

## Verification

- R028/C028 与 R029/C029 均成功。
- iOS Account/Store rollout、API/AuthZ rollout、Round 3B API/AuthZ、Data/Job/Backend/Evidence/Docs checks 通过。
- Product V4 决策登记连续至 DR-041。
- `git diff --check` 在父结果记录前通过。

## Known Gaps

- 没有生产 Swift/backend 代码、XCTest、strong identity、`/v2`、AuthZ enforce、artifact scan或 canary evidence。
- 两次专项 reviewer 未在限定窗口返回，未作为证据；Round 3D 仍必须做新的独立组合复审。
- Job/Object/Provider 副作用和全域退役 runbook 尚需 P033/P034。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `docs/product/DreamJourney_V4_产品决策登记册_V1.0.md`
- `Scripts/QA/product-v4/product-v4-ios-account-store-rollout-check.py`
- `Scripts/QA/product-v4/product-v4-api-authz-rollout-check.py`
- `docs/plans/task_27_round_3c2a_result.md`
- `docs/plans/task_27_round_3c2b_result.md`
- `docs/plans/task_27_round_3c2_result.md`
