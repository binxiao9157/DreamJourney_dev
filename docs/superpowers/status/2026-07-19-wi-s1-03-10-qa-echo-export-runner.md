# WI-S1-03-10 QA Echo Export Runner G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / FIRST_TWO_EXPORT_SCENARIOS_PARITY_VERIFIED`
- 已迁移两个低风险、已有稳定 smoke 的 export scenario；没有把全部 UIQA 路由一次性迁移。

## 本次范围

1. 新增仅 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 编译的 `QAEchoExportRunner`。
2. runner 统一负责五类可复用的 UIQA 编排动作：
   - 等待 key-window root tab（最多 20 次、每次 0.25 秒）
   - 校验 Echo navigation/root
   - 选择回响 Tab
   - 将 `selectedTabIndex` 写入结果 payload
   - 统一 `missingRootTab` / `missingEcho` 的失败结果
3. 以下两条已迁移并复核：
   - `EchoTraceExportSmoke`
   - `EchoRuntimeDiagnosticsExportSmoke`
4. 每个调用点仍保留自身的 Echo operation、结果 writer 和完成日志；因此 export 内容、文件名、
   redaction 和 shell 合同没有改动。

## 边界

- runner 不参与公开 Echo、数字人、音频、网络请求或业务数据构建。
- 仅在模拟器 UIQA 编译；Release artifact 不包含该实现。
- 其余 evidence package / panel / bundle export 以及数字人 lifecycle 继续走旧 bridge，作为下一轮
  parity migration；这避免一次性扩大 blast radius。

## 验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
bash Scripts/QA/prd-stitch-ui/run-echo-trace-export-uiqa-smoke.sh
git diff --check
```

结果：`PASS`。

- trace export 的真实 UIQA smoke 完整通过，产物目录：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-trace-export-smoke/20260719-114404/`
- build/install/runtime log/result/trace/screenshot 均已生成，证明 runner 路由、延迟等待、Tab 选择和
  结果写入保持可用。
- static gate 要求至少两条 export scenario 已通过 runner，防止本次迁移意外回退成单点 facade。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-ECHO-EVIDENCE-EXPORT-RUNNER-EXPANSION`。

把 trace evidence package、panel export、QA evidence bundle 逐条迁入同一 runner；每迁移一组都运行对应
模拟器 smoke，再考虑数字人 lifecycle 或其它 UIQA route。
