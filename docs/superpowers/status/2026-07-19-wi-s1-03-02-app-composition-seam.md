# WI-S1-03-02 AppComposition / Feature Factory 接缝

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-02`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`INTERNAL_READY / G0_COMPOSITION_AND_BUILD_VERIFIED / IOS_LOCAL_COMMITTED / G1_RUNTIME_EVIDENCE_OPEN`
- 范围：仅将已有 `AppCoordinator -> TabCoordinator` 根构造改为受控 Composition/Feature Factory；不改三 Tab、Stitch 全屏 Echo、公开功能、ReleasePolicy 判定、账户 writer 或后端 API。

## 已实现

- 增加纯 `AppFeatureRuntimeContext`，只能在下列条件同时成立时构造：
  - `lifecycleGeneration == AccountLease.generation`；
  - ReleasePolicy authority epoch 与 `AccountLease.authorityEpoch` 一致。
- `AppCoordinator` 在进入已验证私有 UI 前，从现有 `AccountLeaseRuntime` 捕获并验证 lease，再由 `AppComposition` 创建 Tab coordinator。
- `AppFeatureFactory` 成为当前三 Tab 根页面的唯一构造点：
  - 记忆档案；
  - 回响；
  - 我的（保留现有登出回调）。
- `TabCoordinator` 不再直接实例化三页根控制器；它只消费同一个 runtime context 和 factory。
- 没有新增 Service Locator、没有为既有 `.shared` 机械增加 protocol，也没有迁移任一业务写路径。后续具体 writer 迁移必须通过该 composition context 和对应 use case 单独完成。

## 验证证据

1. `python3 Scripts/QA/product-v4/product-v4-ios-composition-seam-check.py` 通过。
   - 确认 root call site 不再直接创建 `TabCoordinator`。
   - 确认三页根控制器仅由 `AppFeatureFactory` 创建。
   - 确认 runtime context 同时绑定 lease、lifecycle 与 ReleasePolicy authority。
2. `swift test --package-path . --scratch-path .build/product-v4-composition` 通过：9 条 XCTest。
   - 新增断言：lifecycle generation 或 policy authority epoch 不一致时，不能构造 feature runtime context。
3. `Scripts/QA/product-v4/run-ios-composition-seam-gate.sh` 通过。
   - 静态 Guard。
   - unhosted XCTest。
   - `xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`。
4. `git diff --check` 通过。

## Gate 与后续边界

- `G0`：当前接缝、确定性模型和完整 iPhoneOS 编译已验证。
- `G1`：现有腾讯/地图/语音 provider 二进制未提供可运行模拟器 slice，因此没有把 hosted simulator runtime 误标为通过；本切片没有视觉或交互行为变化。
- 不以本项作为 Owner Truth 真实数据迁移、跨账号发布、Voice/Digital Human 或任何公开能力的放行依据。
- 下一步若进入 `WI-S1-03-03`，必须先校验其 G2/G4 数据与外部约束；不能因 factory 已存在而跳过这些 Gate。
