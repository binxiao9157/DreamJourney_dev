# WI-S1-03-10 QA Dispatch Metadata G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / IOS_UIQA_AND_RELEASE_BUILD_VERIFIED`
- 本次只将 UIQA 启动时序收敛为 scenario metadata；业务 smoke 的显式调用仍在
  `AppDelegate` bridge 中。

## 本次范围

1. `QALaunchScenario.startupDelay` 成为所有延迟启动 UIQA scenario 的唯一时序表：保留原有
   `1.0s`、`0.8s` 和无延迟 seed 的行为。
2. `QAScenarioRunner.schedule` 按 metadata 执行延迟或立即 action。
3. `AppDelegate` 的 switch 继续清晰表达每个 scenario 调用哪个既有 smoke 方法，但不再保存
   每个 case 的魔法延迟值。
4. 模型 smoke 验证 Echo trace 的 `1.0s`、音色复刻 runtime 的 `0.8s`、seed-only 的无延迟，
   并验证 scheduled/immediate 两条 runner 路径。

## 边界

- 不改变 scenario 优先级、登录/feature flag reset、seed 内容、业务 API、结果文件、UI 或
  Release 默认状态。
- `archiveMediaEchoContextSmoke` 与三个 seed-only scenario 保持既有直接路径；它们没有被错误地
  包装成异步调度。
- 仍未迁移具体 smoke 方法到独立 Xcode target。此次是 progressive strangler 的 metadata 层，
  不是完成态 QASupport module。

## 验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
bash Scripts/QA/prd-stitch-ui/run-echo-trace-export-uiqa-smoke.sh
xcodebuild build -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。

- Echo Trace UIQA smoke 通过，结果、trace、日志和截图目录：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-trace-export-smoke/20260719-114005/`
- Release iPhoneOS build 成功；仅保留项目/第三方既有 warning。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-ECHO-EXPORT-RUNNER-EXTRACTION`。

选择一个已通过 smoke 的 Echo export scenario，将其 root/Echo 路由与 retry 编排抽成编译隔离的
QA runner；`AppDelegate` 仅保留稳定结果写入 adapter。先做单个 scenario 的 parity，不一次性迁移全部
UIQA switch。
