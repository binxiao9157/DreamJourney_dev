# WI-S1-03-10 腾讯 Backend PCM Drive Runner Parity G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / PCM_DRIVE_ROUTE_STATIC_AND_UIQA_BUILD_VERIFIED`
- `TencentBackendPCMDriveMockSmoke` 已改用共享 `QAEchoScenarioRunner` 处理 key-window、Echo
  route、Tab 切换、重试和 `selectedTabIndex` 写入。
- 此变更没有修改后端合成合同、腾讯 runtime stub、PCM 分块、audio owner、中断探针或公开 Echo UI。

## 本次范围

1. `AppDelegate` 不再为 PCM mock 独立维护 Root Tab/Echo 查找和 20 次重试逻辑；保留它自己的
   `voiceProfileId`、`userId` 参数适配、结果 writer 和稳定日志字段。
2. 现有 `TencentBackendPCMDriveMockSmoke` 启动参数仍只由集中式
   `QALaunchScenario.tencentBackendPCMDriveMockSmoke` 持有。静态检查不再错误要求 raw argument
   回流 `AppDelegate`。
3. `tencent-backend-pcm-drive-mock-smoke-check.swift` 新增 shared runner 断言；
   `qa-launch-configuration-static-check.py` 将 PCM mock 纳入共享 Echo scenario runner 数量守卫。

## 边界

- 仅影响 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 下的 UIQA route。
- 不伪造或写死真实 ready `voiceProfileId`、owner、火山凭据、腾讯凭据或后端 token。
- 已有的完整脚本仍要求显式提供已持久化的
  `VOICE_CLONE_READY_PROFILE_ID` 与 `VOICE_CLONE_READY_PROFILE_USER_ID`，以避免试用槽位过期或
  训练状态变化时误把任意 `S_` ID 当作可用音色。
- 因当前本机没有该私密测试对，本子切片不把部署后端的实际合成 smoke 伪报为通过；这属于既有
  G3/外部 provider 运行前提，不影响本次 G0 路由收敛的完成定义。

## 验证

```bash
swift Scripts/QA/prd-stitch-ui/tencent-backend-pcm-drive-mock-smoke-check.swift "$PWD"
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
bash -n Scripts/QA/prd-stitch-ui/run-tencent-backend-pcm-drive-mock-smoke.sh
git diff --check
xcodebuild -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataTencentBackendPCMDriveRunnerParity \
  CODE_SIGNING_ALLOWED=NO SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app \
  DREAMJOURNEY_DEVELOPMENT_TEAM=2BTR77V3R8 EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

结果：通过。

- 编译确认共享 runner 的 PCM mock closure 在 UIQA 条件下可用。
- 现存 Pods/Tencent SDK warning 未由本次代码引入。
- `run-tencent-backend-pcm-drive-mock-smoke.sh` 未在本机执行完成：它正确拒绝缺失的 ready
  profile/owner 输入，没有降级为默认或过期音色。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-NON-ECHO-DISPATCH-INVENTORY`。

先盘点仍在 `AppDelegate` 中直接编排的非 Echo/seed 场景，按相同的 compile-isolated、单场景
parity 原则选择下一项；不得一次性迁移全部 switch，也不得改变公开功能或 Stitch 视觉。
