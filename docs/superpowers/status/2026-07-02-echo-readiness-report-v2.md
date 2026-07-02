# Echo Readiness Report v2

日期：2026-07-02

## 目标

把 Echo 相关运行状态收敛成一份 QA-only 可导出的 readiness 报告，用于排查“上下文没进来、数字人未 ready、声音复刻未进入 Echo、fallback 触发原因不清楚”等问题。

## 新增能力

- JSON 顶层升级为 `schemaVersion=2`。
- 新增 `echoTrace` 汇总层，包含：
  - `contextClues`
  - `digitalHumanSession`
  - `voiceSynthesis`
  - `fallbackSummary`
- `contextClues` 会聚合 `/context/build` 的 Context V2 线索：
  - `contextVersion`
  - `selectedContextRefs`
  - `selectedContextRefsBySource`
  - `archiveRefs`
  - `kbFactRefs`
  - `personaRefs`
  - `careRefs`
  - `filteredContextReasons`
  - `selectedContextSourceCounts`
  - `rankingTraceCount`
  - `fallbacks`
  - `latencyMs`
- `digitalHumanSession` 汇总 `/config/runtime`、`/context/build` 和 `/digital-human/sessions` 的数字人状态。
- `voiceSynthesis` 汇总 `/config/runtime`、`/context/build` 和可选 `/voice/synthesis` 的复刻合成状态。
- `fallbackSummary` 合并后端 fallback、失败检查、跳过检查和推断 fallback。

## 验证入口

- 静态 guard：
  - `swift Scripts/QA/prd-stitch-ui/echo-readiness-report-check.swift .`
- 本地无后端模式：
  - `RUN_ID=20260702-echo-readiness-v2-local BACKEND_BASE_URL= BACKEND_API_TOKEN= Scripts/QA/prd-stitch-ui/run-echo-readiness-report.sh`
- 线上后端模式：
  - `RUN_ID=20260702-echo-readiness-v2-deployed`
  - `BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn`
  - `RUN_READINESS_VOICE_SYNTHESIS=0`
- Release regression 可选 gate：
  - `RUN_ECHO_READINESS_REPORT=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh`

## 本次证据路径

- 本地报告：
  - `tmp/visual-qa/prd-stitch-ui/echo-readiness-report/20260702-echo-readiness-v2-local/echo-readiness-report.json`
  - `tmp/visual-qa/prd-stitch-ui/echo-readiness-report/20260702-echo-readiness-v2-local/echo-readiness-report.md`
- 线上报告：
  - `tmp/visual-qa/prd-stitch-ui/echo-readiness-report/20260702-echo-readiness-v2-deployed/echo-readiness-report.json`
  - `tmp/visual-qa/prd-stitch-ui/echo-readiness-report/20260702-echo-readiness-v2-deployed/echo-readiness-report.md`

## 当前线上摘要

- `/context/build`：`contextVersion=echo-context-v2`
- `/digital-human/sessions`：HTTP 200
- `/voice/synthesis`：本轮未启用真实合成探针，`probeStatus=skipped`
- `fallbackSummary`：包含 `voice_clone_not_ready` 和 `voice_synthesis_probe_skipped`
