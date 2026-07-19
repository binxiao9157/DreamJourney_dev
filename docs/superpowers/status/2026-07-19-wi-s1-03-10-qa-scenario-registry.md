# WI-S1-03-10 QA Scenario Registry G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / IOS_LOCAL_VERIFIED`
- 该结果只固定 QA 启动场景的选择与编排策略；没有把整个 `WI-S1-03-10` 标记为完成。

## 本次范围

1. `QALaunchScenario` 成为 App 启动 UIQA scenario 的唯一注册表，保留原 `AppDelegate`
   `if / else` 链的优先级。多参数并存时只执行 `startupOrder` 中最早命中的一个场景。
2. `QALaunchFeature` 集中保存不启动 scenario 的能力开关：远端档案拉取、数字人面板和
   真机数字人 text/PCM smoke。
3. 每个 scenario 固定声明登录/重置 feature flag 的准备策略；`AppDelegate` 只按 typed
   scenario 分发到既有 smoke、seed 或导出执行体，不改变这些执行体的业务行为。
4. 档案、回响、关怀、时间信件、音色复刻和数字人相关静态检查同步改为检查注册表和 typed
   dispatch，不再依赖控制器中分散的原始 argument 字符串。

## 运行边界

- `QALaunchConfiguration` 仍是唯一读取 `ProcessInfo.processInfo.arguments` 的位置。
- 非 `DEBUG` / `UI_QA_SIMULATOR` 配置保持空参数，因此不会解析 startup scenario、QA seed 或
  隐藏 capability。
- 没有新增公开入口、deeplink、持久化开关或发布态 UI；三 Tab、Stitch 视觉和业务调用链均未改变。
- 本切片没有迁移具体 smoke/seed/export 方法到独立 `QASupport` 文件或 target，那是下一子切片。

## 验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
swift Scripts/QA/prd-stitch-ui/digital-human-live-panel-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/echo-voice-state-visual-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/archive-failed-analysis-retry-smoke-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/voice-clone-synthesis-runtime-smoke-check.swift "$PWD"
python3 Scripts/QA/product-v4/global-private-store-retirement-uiqa-check.py
python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-candidate-client-check.py
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。

- model smoke 同时验证 Debug/UIQA 多参数优先级、profile-care seed 策略和生产配置 fail closed。
- iPhoneOS Debug `build-for-testing` 成功；第三方地图库的既有 warning 未由本切片引入。
- 全量旧静态脚本抽查发现若干早于本切片的基线漂移（旧 import 条件、旧 Echo delayed-reply
  保存调用名、Archive context 枚举文本、PCM timeout 文本）；它们未改变本次 registry 行为，已保留
  为后续 QA 债，不在本子切片中借机修改业务代码。

## 未关闭 Gate 与后续

- `G0`：launch configuration 与 scenario registry 已完成；具体 smoke/seed/export 执行体仍在
  `AppDelegate`，尚未完成 QASupport runner 抽离。
- `G1`：逐段迁移后的 simulator 交互、截图与 parity 证据未开始。
- `G3/G4`：Voice、Digital Human、APNs 和真机外部门保持原状态。

下一子切片：`WI-S1-03-10-G0-QA-SCENARIO-RUNNER-EXTRACTION`。先选择一个无业务副作用的
export scenario，将执行编排移到编译隔离的 QA support facade，并保留旧路径 counter；不一次性移动
全部 `AppDelegate` UIQA 方法。
