# WI-S1-03-10 QA Export Result Writer G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / IOS_UIQA_VERIFIED`
- 本次仅抽取 Echo QA export 的 JSON 结果写入基础设施；不迁移业务 smoke、seed 或公开 UI。

## 本次范围

1. 新增 `QAScenarioResultWriter`，仅在 `DEBUG || UI_QA_SIMULATOR` 编译。它负责 JSON 编码、
   Documents 目录定位和原子写入；Release 不包含该 writer。
2. 将五个 Echo export smoke 的结果持久化改为共用 writer：
   - Echo trace export
   - Echo runtime diagnostics export
   - Echo trace evidence package export
   - Echo trace evidence package panel export
   - Echo QA evidence bundle export
3. 保留每个 smoke 的历史结果文件名、日志 label 和失败文案；`AppDelegate` 仅保留轻量适配层，
   因此既有 shell/UIQA 脚本不需要改路径。
4. model smoke 以临时目录验证 writer 写入及 JSON 可读性；static gate 验证所有上述 smoke 通过
   共用 adapter 调用 writer。

## 边界

- 不改变 Echo trace/evidence 的字段、redaction、权限、业务上下文或任何网络调用。
- 不修改 Stitch 页面、三 Tab、数字人、音色复刻、麦克风或公开 release 行为。
- 此处是 compile-contained QA support。工程 `project.pbxproj` 仍有非本任务改动，独立
  `QASupport` file/target 的创建继续后置到工程文件可安全审查时。

## 验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
xcodebuild build -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' CODE_SIGNING_ALLOWED=NO
bash Scripts/QA/prd-stitch-ui/run-echo-trace-export-uiqa-smoke.sh
git diff --check
```

结果：`PASS`。

- UIQA smoke 实际产出结果 JSON、trace export、runtime log、OS log 和截图。
- 产物目录：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-trace-export-smoke/20260719-113618/`
- 模拟器截图确认回响页仍为正常的公开布局，无 QA 控件误暴露。
- Release iPhoneOS build 已在前一子切片通过；本子切片的 writer 在 Release 编译条件中被排除。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-DISPATCH-METADATA-EXTRACTION`。

先把 scenario 的延迟与无副作用准备元数据化，缩小 `AppDelegate` 的启动编排；实际业务 smoke 的调用继续
保留为显式 bridge，等 parity/old-path 证据具备后再逐段迁移。
