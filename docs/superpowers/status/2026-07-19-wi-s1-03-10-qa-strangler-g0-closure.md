# WI-S1-03-10 QA Strangler G0 收敛记录

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 收敛状态：`INTERNAL_READY / BOUNDED_G0_QA_STRANGLER_PARITY_VERIFIED`
- 本记录只确认可重复的 G0 内部 QA 编排边界；不宣称 G1 公开视觉回归、G3 Provider 或 G4 真机已完成。

## 已收敛范围

1. `FeatureFlagService` 是 QA launch argument 的唯一 fail-closed 读取边界。
2. `QAScenarioRunner`、`QAScenarioResultWriter`、`QALaunchScenario` 和
   `QAEchoScenarioRunner` 接管了启动计划、结果写入、Echo route/retry 以及五类 Echo
   evidence export 的编排。
3. 数字人 lifecycle、authenticated runtime stub、Tencent backend PCM-drive mock 都已有
   独立 runner parity；不会重新把 Provider/AVAudioSession 控制塞回 `AppDelegate` 或页面。
4. `GlobalPrivateStoreRetirementSmoke` 和 `QAProfileScenarioRunner` 已承接各自的
   run/persist/present 或 Profile root routing/result persistence。
5. Profile Care 后端失败重试 runner 使用真实短期 V2 认证会话，经
   `UserManager`、`AccountLease` 和正式根视图组合进入页面；不注入 service token，也不绕过
   账号边界。
6. 35 个未逐段迁移的非 Echo 启动场景已被分类。认证、seed 或 AccountLease 敏感场景暂留
   `AppDelegate` 是有意边界，不是允许新 QA bypass 的例外。

## 安全与数据边界

- Profile Care fixture 仅插入带 QA marker 的临时 V2 用户；ID 冲突会重试，绝不更新既有账号。
- fixture cleanup 先验证 marker，再以 marker 约束删除，并验证用户已不存在；清理失败会使
  smoke 失败。
- 完整 active/empty/stale backend-state 场景在创建数据前先检查 ReleasePolicy；未获 closed
  pilot 批准时预期停止，不能借 QA 场景绕过发布策略。
- 不改公开三 Tab、Stitch 视觉、ReleasePolicy、后端业务合同或任何 Provider 配置。

## 本次验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
bash -n Scripts/QA/prd-stitch-ui/run-profile-care-backend-state-smoke.sh
python3 -m py_compile Scripts/QA/prd-stitch-ui/backend-care-state-uiqa-fixtures.py
swift Scripts/QA/prd-stitch-ui/profile-care-backend-state-smoke-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift "$PWD"
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app build
git diff --check
```

结果：通过。

- 安全的 authenticated failure/retry runtime 结果：
  `tmp/visual-qa/prd-stitch-ui/profile-care-backend-state-smoke/profile-care-safe-fixture-20260719-135054/profile-care-state-smoke-result.json`。
- 结果证明失败态、点击 `重新同步`、loading 过渡及再次失败后的可恢复入口均正常；远端临时目录和
  模拟器 Documents fixture 均在结束后清理。
- 完整 backend-state smoke 因 `careDashboard` 尚未获 closed pilot ReleasePolicy 批准而在预检处停止；
  这是预期 fail-closed 结果，不是失败绕过。

## 未关闭 Gate

- `G1`：公开 MVP 全流程视觉/截图回归仍需独立执行。
- `G3`：腾讯数字人、火山语音、APNs 等 Provider 外部合同不由本 Work Item 宣称通过。
- `G4`：真机、人工产品验收和外部证据保持未验。

## 交接

`WI-S1-03-10` 的有界 G0 收敛完成。派生执行交接切换到下一个 P0 Owner Truth 项
`WI-S1-01-04`：Candidate Inbox、Owner Review 与不可变 DecisionReceipt。该项继续保持 hidden /
无公开权限，先完成 G0/G2 合同和可重复验证。
