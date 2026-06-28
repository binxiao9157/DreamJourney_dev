# 档案图像分析 Runtime UI 状态

日期：2026-06-19

## 本轮目标

让 iOS 端基于 `/config/runtime.archiveImageAnalysis` 能力公告稳定展示图像分析状态：

- 当 `supportsVision=false` 时，不再把图像分析不可用误导成“已生成图像分析”。
- 相册导入和档案详情“重新分析”入口都先读取 runtime capability。
- 当前 `deepseek/text-only` 模式下，UI 稳定落到“AI 分析暂不可用，可稍后重试”。
- 云端档案同步状态保持“云端已同步”，避免把 AI provider 不可用混同为 `/archive/items` 同步失败。

## 实现要点

- `DreamJourneyBackendClient.fetchArchiveImageAnalysisRuntimeCapability` 提供聚焦能力读取。
- `MemoryArchiveItem.markAnalysisUnavailableFromRuntime` 记录：
  - `analysisFailureReason=provider_unavailable`
  - `analysisRetryable=true`
  - `analysisProvider`
  - `analysisFallbackMode`
- `MemoryArchiveViewController` 在相册导入后先判断 `capability.canRunVisionAnalysis`。
- `MemoryArchiveDetailViewController` 在点击“重新分析”后先判断 `capability.canRunVisionAnalysis`。

## 验证

- 静态 UI gate：`Scripts/QA/prd-stitch-ui/archive-image-analysis-runtime-ui-check.swift`
- 构建日志：`tmp/visual-qa/prd-stitch-ui/archive-runtime-ui-build.log`
- 模拟器 smoke：`tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke/20260619-archive-runtime-ui/`
- 截图：`tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke/20260619-archive-runtime-ui/01-archive-failed-analysis-retry.png`

## Smoke 结果

- `completed=true`
- `backendConfigured=true`
- `initialAnalysisStatus=failed`
- `finalAnalysisStatus=failed`
- `storedFinalAnalysisStatus=failed`
- `analysisRetryable=true`
- `initialAnalysisStateText=AI 分析暂不可用，可稍后重试`
- `storedCloudStateText=云端已同步`
