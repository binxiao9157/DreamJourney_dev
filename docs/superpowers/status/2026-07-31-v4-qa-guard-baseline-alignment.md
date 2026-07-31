# V4：QA 启动与 Echo Trace Guard 基线对齐

日期：2026-07-31

## 状态

`VERIFIED_LOCAL / QA_INFRASTRUCTURE_ONLY / DEFAULT_OFF / NO_PRODUCT_BEHAVIOR_CHANGE`

## 本轮目的

当前 `WI-S1-01-06` 的候选确认和 Echo Trace 证据仍依赖既有模拟器
QA 启动编排。三个已纳入回归的静态 guard 停留在旧实现，导致真实代码
不变时也无法形成可信的本地绿色基线。本轮仅对齐这些 guard，不新增
Owner Truth 写入、后端路由、发布入口、Provider 调用或真机行为。

## 已对齐内容

1. Echo Trace 导出已统一使用 `QAScenarioResultWriter.writeAndLog`；两个
   guard 不再要求已经删除的 `writeEchoQAExportSmokeResult` 或
   `writeEchoTraceExportSmokeResult` 适配器。
2. 保留稳定的 `echo-trace-export-smoke-result.json` 结果协议，并让
   QA 启动 gate 实际运行 Echo Trace 导出静态检查。
3. UIQA 场景库存已覆盖当前 `QALaunchScenario` 的全部 54 个场景：
   10 个共享 Echo 路由、1 个认证 runtime-stub、6 个 seed 路径、2 个
   AccountLease 敏感路径和 35 个标准调度路径。
4. 清除了本轮脚本输出中把 QA 编排错误标注为 `WI-S1-03-10` 的表述。
   终版执行计划中该 Work Item 仍受其自身依赖与 Gate 约束；本轮没有
   修改 Registry，也不声称完成其 Legacy shadow / cohort cutover 范围。

## 验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
```

结果：通过，包含 QA 启动静态边界、54 项场景库存、Echo Trace 导出 guard
以及 Debug/Release 启动配置模型 smoke。

```bash
git diff --check -- \
  Scripts/QA/product-v4/qa-launch-configuration-static-check.py \
  Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py \
  Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh \
  Scripts/QA/prd-stitch-ui/echo-trace-export-check.swift
```

结果：通过。

```bash
xcodebuild build -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

结果：无签名通用 iPhoneOS Debug 构建通过。

```bash
bash Scripts/QA/prd-stitch-ui/run-echo-trace-export-uiqa-smoke.sh
```

结果：通过。模拟器结果、运行日志和脱敏 Trace 导出位于：

`tmp/visual-qa/prd-stitch-ui/echo-trace-export-smoke/20260731-235921/`

截图：

`tmp/visual-qa/prd-stitch-ui/echo-trace-export-smoke/20260731-235921/01-echo-trace-export-smoke.png`

## 未声明范围

- 未改变任何公开 UI、Stitch 视觉、功能开关、Owner Truth 合同或数据写入。
- 未执行后端部署、Postgres、Provider 或真机验收。
- 未将 Registry 的保守 `PLANNED/STOP` 状态改写为实现完成。
