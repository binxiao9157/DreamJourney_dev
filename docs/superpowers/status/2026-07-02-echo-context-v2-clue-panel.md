# Echo Context V2 QA Clue Panel

日期：2026-07-02

## 目标

在 Echo QA 面板里直接展示本轮 `/context/build` 返回的 Context V2 线索说明，方便真机或模拟器复现问题时判断回响到底使用了哪些上下文，以及为什么发生 fallback。

## 实现范围

- QA-only：仅在 `DJShowEchoRuntimeDiagnosticsPanel` 或相关 UIQA launch arg 下展示，不影响公开 Echo UI。
- `EchoContextPacket` / `EchoTraceRecord` 现在保留 `selectedContextRefsBySource`。
- 新增 `EchoContextV2ClueSummary`，统一生成：
  - archive refs
  - KBLite fact refs
  - persona refs
  - care refs
  - filtered reasons
  - selected source counts
  - ranking trace count
  - fallbacks
  - context latency
- Echo runtime diagnostics panel 追加 `ctx ...` 线索摘要。
- Echo trace evidence package 的 `contextBuild.clueSummary` 会导出同一份可读线索摘要。

## 验证入口

- 静态 gate：
  - `swift Scripts/QA/prd-stitch-ui/echo-context-v2-clue-panel-check.swift .`
- UIQA：
  - `RUN_ID=20260702-context-v2-clue-panel-v2 Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-panel-export-smoke.sh`
- Release regression：
  - `RUN_ID=20260702-context-v2-clue-panel-regression RUN_STANDARD_BUILD=0 RUN_SIMULATOR_SMOKE=0 RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 Scripts/QA/prd-stitch-ui/run-release-regression.sh`

## 证据路径

- UIQA 截图：
  - `tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-panel-export-smoke/20260702-context-v2-clue-panel-v2/01-echo-trace-evidence-package-panel-export-smoke.png`
- UIQA 结果：
  - `tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-panel-export-smoke/20260702-context-v2-clue-panel-v2/echo-trace-evidence-package-panel-export-smoke-result.json`
- 导出证据包：
  - `tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-panel-export-smoke/20260702-context-v2-clue-panel-v2/echo-trace-evidence-packages.json`

## 后续

下一步可把同一份 clue summary 接入 Readiness Report，让一键报告同时覆盖 Context、数字人、声音复刻和 fallback 原因。
