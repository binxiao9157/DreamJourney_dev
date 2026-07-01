# Echo Runtime Diagnostics / QA Clues / Readiness Report

日期：2026-07-02

## 背景

基于 `2026-07-02-ackem-mechanism-reference.md`，本轮只吸收适合 DreamJourney 的轻量机制，不引入 Ackem 的桌面端、插件市场或平台化能力。

目标是让 Echo 真机和后端问题可解释、可导出、可回归：

- A：统一 `EchoRuntimeDiagnosticsSnapshot`。
- B：隐藏 QA 面板展示本轮 Echo 线索。
- C：一键 readiness 报告。

公开用户界面默认不展示这些调试信息。

## A. EchoRuntimeDiagnosticsSnapshot

新增：

- `EchoRuntimeDiagnosticsSnapshot`
- `EchoRuntimeDiagnosticsStore`

记录字段包括：

- `turnID`
- `traceId`
- `archiveItemIDs`
- `archiveItemsIncluded / archiveItemsAvailable`
- `kbFactCount`
- `voiceProfileId`
- `voiceOutputMode`
- `audioOwner`
- `digitalHumanRuntimeState`
- `digitalHumanProviderMode`
- `providerLogId`
- `providerRequestId`
- `fallbackReason`
- `privacyScopeLabel`
- `crossScopeArchiveIncluded`
- `contextLatencyMs`

存储策略：

- 本地 `UserDefaults`
- 最近 20 条
- 可导出 `echo-runtime-diagnostics.json`

实际采集点：

- `/context/build` 成功后记录 context packet。
- 声音复刻 PCM-drive 合成成功。
- 声音复刻 PCM-drive 合成失败。
- 未启用复刻音色。
- 数字人 runtime 失败或降级。

## B. 隐藏 QA 线索面板

新增 QA-only launch arg：

```text
DJShowEchoRuntimeDiagnosticsPanel
```

UIQA smoke 也会自动启用：

```text
DJRunEchoRuntimeDiagnosticsExportSmoke
```

面板展示：

- 本轮 turn。
- 本轮档案命中数量和前 3 个档案 ID。
- KBLite facts 数量。
- persona / privacy scope。
- family data 和 cross-scope 状态。
- voiceProfileId 和 voice output mode。
- audioOwner。
- digital human runtime state / provider mode。
- providerLogId。
- fallbackReason。
- context latency。

公开 release 默认不显示，避免影响现有全屏 Echo 设计。

## C. Readiness Report

新增：

- `Scripts/QA/prd-stitch-ui/echo-readiness-report.py`
- `Scripts/QA/prd-stitch-ui/run-echo-readiness-report.sh`
- `Scripts/QA/prd-stitch-ui/echo-readiness-report-check.swift`

默认本地模式检查：

- Context Packet / Echo Trace / Runtime Diagnostics 代码合同。
- 数字人 session client 合同。
- 声音复刻 synthesis client 合同。
- APNs entitlement gating。
- KBLite 本地导出能力。

如果设置后端环境变量，会额外检查部署后端：

```bash
BACKEND_BASE_URL=...
BACKEND_API_TOKEN=...
RUN_ID=20260702-readiness \
Scripts/QA/prd-stitch-ui/run-echo-readiness-report.sh
```

部署后端探测范围：

- `GET /health`
- `GET /config/runtime`
- `POST /context/build`
- `POST /digital-human/sessions`

声音合成探测默认关闭，避免日常回归误消耗 provider 额度。需要时显式打开：

```bash
RUN_READINESS_VOICE_SYNTHESIS=1 \
VOICE_CLONE_READY_PROFILE_ID=S_xxx \
BACKEND_BASE_URL=... \
BACKEND_API_TOKEN=... \
Scripts/QA/prd-stitch-ui/run-echo-readiness-report.sh
```

输出：

- `echo-readiness-report.json`
- `echo-readiness-report.md`
- `echo-readiness-report-runner.json`

默认不会因后端未配置而失败；需要硬门时设置：

```bash
READINESS_STRICT=1
```

## Release 接入

已接入：

- `Scripts/QA/prd-stitch-ui/run-release-regression.sh`
- `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`

可选开关：

```bash
RUN_ECHO_READINESS_REPORT=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

新增静态检查：

```bash
swift Scripts/QA/prd-stitch-ui/echo-runtime-diagnostics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/echo-readiness-report-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

## 验证结果

已通过：

```text
swift Scripts/QA/prd-stitch-ui/echo-runtime-diagnostics-check.swift
swift Scripts/QA/prd-stitch-ui/echo-readiness-report-check.swift
RUN_ID=20260702-local-readiness Scripts/QA/prd-stitch-ui/run-echo-readiness-report.sh
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/build/echo-abc-diagnostics-dd build
```

本轮没有跑真机，也没有部署后端。

## 后续建议

下一步可以继续做 Echo trace 证据包标准化，把 iOS runtime diagnostics、后端 `/context/build`、`/digital-human/sessions`、`/voice/synthesis` 摘要合并成一个 QA-only 导出包，用于真机问题定位。
