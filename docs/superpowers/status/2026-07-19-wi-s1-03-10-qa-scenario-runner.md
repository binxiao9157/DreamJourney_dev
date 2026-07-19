# WI-S1-03-10 QA Scenario Runner G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / IOS_LOCAL_VERIFIED`
- 该结果只收敛启动方案和 session 准备；具体 smoke、seed、导出执行体仍在
  `AppDelegate`，不能把整个 `WI-S1-03-10` 标记为完成。

## 本次范围

1. 新增 `QAScenarioLaunchPlan`，将已解析的启动 scenario、远端档案拉取、数字人面板和
   profile-care seed 能力收敛为一次性 launch plan。
2. 新增 `QAScenarioRunner.prepareSession`。它按场景的声明式
   `QALaunchScenarioSessionPreparation` 执行无准备、登录、登录后重置 feature flag 三种策略。
3. 删除 `AppDelegate.prepareUIQASession`。`AppDelegate` 保留 UIQA scenario 的最终 dispatch，
   但不再自行判断 session 准备策略。
4. model smoke 覆盖 no scenario、login、login-and-reset 三种执行器语义；static gate 断言旧 helper
   不再存在。

## 边界与已知保留项

- `QALaunchConfiguration` 只负责 AppDelegate/Echo 的集中 smoke harness 参数，不声称接管仓库
  内所有 Debug/QA 本地 override。数字人 asset override、OwnerTruth review、Profile/Archive 隐藏分支
  等模块级参数仍维持各自 release gate，后续只能随对应模块迁移。
- 本子切片没有移动任一业务 smoke 的 UI 路由、seed 内容、业务调用或 Stitch 页面；三 Tab 和公开 UI
  没有变更。
- 当前工程 `project.pbxproj` 存在非本任务改动，故暂不新增独立 Xcode file/target；先以已有
  `FeatureFlagService.swift` 内的编译隔离 facade 完成低风险抽离。后续创建独立 `QASupport` 文件前，
  必须先确认工程文件稳定并做一次专门的 project-file 审查。

## 验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
swift Scripts/QA/prd-stitch-ui/digital-human-live-panel-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/echo-voice-state-visual-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/archive-failed-analysis-retry-smoke-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/voice-clone-synthesis-runtime-smoke-check.swift "$PWD"
python3 Scripts/QA/product-v4/global-private-store-retirement-uiqa-check.py
python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-candidate-client-check.py
xcodebuild build-for-testing -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。

- Debug model smoke 同时验证 production configuration fail closed。
- iPhoneOS Debug `build-for-testing`、Release `build` 均通过。
- 构建只保留既有第三方地图库 warning，以及已有 UIKit API deprecation / actor conversion warning；
  本子切片未新增 warning。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-EXPORT-RESULT-WRITER-EXTRACTION`。

先抽取一个无业务副作用的 JSON export/result writer，并保留结果文件名和现有 smoke 输出不变；不一次性
迁移全部 `AppDelegate` UIQA 方法，也不触碰公开 UI。
