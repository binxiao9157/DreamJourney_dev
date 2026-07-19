# WI-S1-03-10 Echo Evidence Export Runner 扩展 G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / FIVE_ECHO_EVIDENCE_EXPORT_SCENARIOS_PARITY_VERIFIED`
- `QAEchoExportRunner` 已成为五条已有稳定 smoke 的唯一 root/Echo 路由、Tab 选择、重试和结果注入层；各场景自身的 export 内容、文件名、redaction 与日志合同保持不变。

## 本次范围

在已有 trace / runtime diagnostics 两条路径基础上，迁移其余三条证据导出场景：

1. `EchoTraceEvidencePackageExportSmoke`
2. `EchoTraceEvidencePackagePanelExportSmoke`
3. `EchoQAEvidenceBundleExportSmoke`

五条场景现在共享：

- key-window root tab 等待（最多 20 次、每次 0.25 秒）
- Echo navigation/root 校验
- 回响 Tab 选择
- `selectedTabIndex` 结果注入
- `missingRootTab` / `missingEcho` 失败合同

## 边界

- 仅在 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 编译。
- 不改公开 UI、Echo 业务、数字人、音频 owner、Provider 或网络请求。
- 不迁移非证据类 smoke/seed；数字人 lifecycle runner parity 留在下一子切片。

## 验证

```bash
bash Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-export-smoke.sh
bash Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-panel-export-smoke.sh
bash Scripts/QA/prd-stitch-ui/run-echo-qa-evidence-bundle-export-smoke.sh
```

结果均为 `PASS`：

- evidence package：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-export-smoke/20260719-114840/`
- evidence package panel：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-panel-export-smoke/20260719-114903/`
- QA evidence bundle：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260719-115052/`

三个结果文件均显示 `completed=true`、`fileExists=true`、`selectedTabIndex=1`；bundle 同时验证 manifest 当前、owner isolation 和红线字段摘要。

通用设备编译也已通过：

```bash
xcodebuild build -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

该命令禁用签名，仅验证 Release iPhoneOS 编译；不覆盖本机 Team、Bundle ID 或 provisioning profile。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-DIGITAL-HUMAN-LIFECYCLE-RUNNER-PARITY`。

只迁移已有 `EchoDigitalHumanLifecycleSmoke` 的 root/Echo 路由到同一 runner，先做静态检查和模拟器 smoke，再决定是否继续其它 QA route。
