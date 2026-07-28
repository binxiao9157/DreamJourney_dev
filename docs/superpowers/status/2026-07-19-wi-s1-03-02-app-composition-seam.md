# WI-S1-03-02 AppComposition / Feature Factory 接缝

日期：2026-07-19
最近复核：2026-07-29

## 当前状态

- Work Item：`WI-S1-03-02`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`INTERNAL_READY / G0_COMPOSITION_AND_BUILD_VERIFIED / G1_SIMULATOR_ROUTE_UIQA_VERIFIED / IOS_LOCAL_COMMITTED_711cfe6`
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
- `AppComposition` 现在也是进程启动的私有状态准备边界：先 reconcile 私有会话，再将已验证 owner（或 `nil`）同步给 KnowledgeSync/KBLite 兼容存储。
- `AppDelegate` 与 `SceneDelegate` 共享同一个 root `AppComposition`；`prepareForProcessLaunch()` 具备幂等保护，避免 scene 重连重复执行私有启动副作用。
- 没有新增 Service Locator、没有为既有 `.shared` 机械增加 protocol，也没有迁移任一业务写路径。后续具体 writer 迁移必须通过该 composition context 和对应 use case 单独完成。

## 验证证据

1. `python3 Scripts/QA/product-v4/product-v4-ios-composition-seam-check.py` 通过。
   - 确认 root call site 不再直接创建 `TabCoordinator`。
   - 确认三页根控制器仅由 `AppFeatureFactory` 创建。
   - 确认 runtime context 同时绑定 lease、lifecycle 与 ReleasePolicy authority。
2. 定向 `xcodebuild test -only-testing:DreamJourneyTests/AccountLeaseRuntimeTests` 通过：7 条 XCTest。
   - 新增断言：lifecycle generation 或 policy authority epoch 不一致时，不能构造 feature runtime context。
   - 新增断言：私有会话 reconcile 必须先于 Knowledge/KBLite owner 解析；同一 `AppComposition` 只执行一次启动准备。
3. `Scripts/QA/product-v4/run-ios-composition-seam-gate.sh` 通过。
   - 静态 Guard。
   - unhosted XCTest。
   - `xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`。
4. `git diff --check` 通过。
5. `Scripts/QA/prd-stitch-ui/run-notification-runtime-route-uiqa-smoke.sh` 通过。
   - 模拟器验证有效、跨 owner、过期 generation、畸形 deep link 和时间信件提醒的路由选择；最终保持在档案页。
   - 证据：`tmp/visual-qa/product-v4/app-composition/20260729-app-composition-launch/notification-runtime-route-uiqa-smoke-result.json`。

## Gate 与后续边界

- `G0`：当前接缝、确定性模型和完整 iPhoneOS 编译已验证。
- `G1`：启动准备和通知路由已在模拟器 UIQA 验证；这不是腾讯、地图、语音 provider 的真实运行证据，也不是账户数据迁移或真机验收。
- 不以本项作为 Owner Truth 真实数据迁移、跨账号发布、Voice/Digital Human 或任何公开能力的放行依据。
- 下一步若进入 `WI-S1-03-03`，必须先校验其 G2/G4 数据与外部约束；不能因 factory 已存在而跳过这些 Gate。
