# Echo trace 证据包标准化

日期：2026-07-02

## 目标

把 Echo 真机/模拟器排查所需证据收敛成 QA-only 导出包。一个包尽量回答：

- 本轮 Echo 用了哪些档案线索。
- 后端 `/context/build` 返回的上下文摘要是什么。
- iOS runtime diagnostics 当前看到的 audioOwner、数字人 runtime、fallback 是什么。
- 后端 `/digital-human/sessions` 的 session 摘要是什么。
- 后端 `/voice/synthesis` 的声音合成摘要是什么。

本轮不改变公开 UI，不影响当前 Echo 全屏产品设计。

## 新增结构

新增 `EchoTraceEvidencePackage`，包含：

- `traceRecord`
- `runtimeDiagnostics`
- `contextBuild`
- `digitalHumanSession`
- `voiceSynthesis`
- `redactionPolicy`

新增摘要结构：

- `EchoContextBuildEvidenceSummary`
- `EchoDigitalHumanSessionEvidenceSummary`
- `EchoVoiceSynthesisEvidenceSummary`

新增本地存储：

- `EchoTraceEvidencePackageStore`
- 最近 20 条
- 导出文件：`echo-trace-evidence-packages.json`

## 数据来源

### iOS runtime diagnostics

来自上一轮新增的 `EchoRuntimeDiagnosticsSnapshot`。

重点字段：

- `audioOwner`
- `digitalHumanRuntimeState`
- `digitalHumanProviderMode`
- `providerLogId`
- `providerRequestId`
- `fallbackReason`

### `/context/build`

通过 `EchoTraceRecord` 汇总：

- `traceId`
- `archiveItemIDs`
- `archiveItemsIncluded`
- `archiveItemsAvailable`
- `kbFactCount`
- `voiceProfileId`
- `voiceOutputMode`
- `privacyScopeLabel`
- `crossScopeArchiveIncluded`
- `latencyMs`

### `/digital-human/sessions`

通过 `EchoDigitalHumanSessionEvidenceSummary` 汇总：

- `sessionId`
- `provider`
- `providerMode`
- `personaId`
- `scene`
- `lifecycleMode`
- `driveMode`
- `assetSource`
- `hasProviderAssetId`
- `hasProviderProjectId`
- `credentialMode`
- `credentialExpiresAt`
- `hasBackendIssuedCredential`
- `fallbackMode`
- `fallbackReason`
- `contractVersion`

### `/voice/synthesis`

通过 `EchoVoiceSynthesisEvidenceSummary` 汇总：

- `voiceProfileId`
- `providerMode`
- `outputMode`
- `audioFormat`
- `byteCount`
- `sampleRate`
- `bitsPerSample`
- `channelCount`
- `durationSeconds`
- `providerLogId`
- `providerRequestId`
- `tencentAudioDriveCompatible`
- `visemeFrameCount`

## 安全边界

证据包不导出 raw audio。

证据包不导出 `audioBase64`。

证据包不导出腾讯 `appkey/accesstoken`。

检查口径：不导出 appkey/accesstoken。

证据包只保留：

- provider log id
- provider request id
- session/provider 摘要
- 档案 ID 与数量
- 权限范围摘要

## QA 入口

### 手动导出

在 QA 启动参数 `DJShowEchoRuntimeDiagnosticsPanel` 下，Echo 页面右上角会显示诊断面板。面板底部提供 `导出证据包` 按钮：

- 点击后先记录当前 iOS runtime diagnostics。
- 生成 `echo-trace-evidence-packages.json`。
- 通过系统分享面板导出文件。
- 普通公开模式不显示该按钮。

### 自动 smoke

App launch arg：

```text
DJRunEchoTraceEvidencePackageExportSmoke
```

一键模拟器 smoke：

```bash
Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-export-smoke.sh
```

QA 面板按钮 smoke：

```bash
Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-panel-export-smoke.sh
```

结果文件：

```text
echo-trace-evidence-package-export-smoke-result.json
echo-trace-evidence-package-panel-export-smoke-result.json
```

证据包文件：

```text
echo-trace-evidence-packages.json
```

## 静态检查

```bash
swift Scripts/QA/prd-stitch-ui/echo-trace-evidence-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

该检查已接入：

- `Scripts/QA/prd-stitch-ui/run-release-regression.sh`
- `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`

release regression 可选开关：

```bash
RUN_ECHO_TRACE_EVIDENCE_PACKAGE_EXPORT_SMOKE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh
RUN_ECHO_TRACE_EVIDENCE_PACKAGE_PANEL_EXPORT_SMOKE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 后续建议

下一步可以把真机 Echo 问题复现后的证据包上传/归档流程接入内部 QA handoff，方便把 providerLogId、context trace 和 runtime diagnostics 一起交给后端或服务商排查。
