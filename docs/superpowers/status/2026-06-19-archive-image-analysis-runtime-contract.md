# 档案图像分析 Runtime 合同

日期：2026-06-19

## 本轮目标

围绕 PRD P1 后端/合同任务，收敛档案图像分析能力公告与状态枚举：

- 后端把 `DeepSeekImageAnalysisProxy` 外层收敛为 provider adapter。
- 当前 provider 明确为 `deepseek/text-only`，不声明视觉能力。
- `/config/runtime` 暴露 `archiveImageAnalysis` 能力对象。
- 后端和 iOS 统一识别 `pending / analyzing / analyzed / failed / retryable` 五个远端分析状态。
- iOS 保留本地 `manual` 状态，用于手写/本地归档素材，不作为后端合同状态。

## 后端合同

`/config/runtime` 返回：

```json
{
  "archiveImageAnalysis": {
    "enabled": true,
    "endpoint": "/archive/image-analysis",
    "provider": "deepseek/text-only",
    "supportsVision": false,
    "fallbackMode": "retryableFailure",
    "statuses": ["pending", "analyzing", "analyzed", "failed", "retryable"]
  }
}
```

当前 `deepseek/text-only` 模式下，`/archive/image-analysis` 非 dryRun 不会伪装真实视觉分析；它会返回可持久化的 `failed + analysisRetryable=true + provider_unavailable` 合同。后续切到真正视觉 provider 时，应新增 provider adapter 并保持 iOS 合同不变。

## iOS 合同

iOS 新增 `ArchiveImageAnalysisRuntimeCapability`，从 `BackendRuntimeConfig.archiveImageAnalysis` 解析：

- `enabled`
- `endpoint`
- `provider`
- `supportsVision`
- `fallbackMode`
- `statuses`

档案分析状态新增：

- `analyzing`
- `retryable`

Echo 档案上下文仍只接收 `manual/analyzed` 的结构化线索；`failed/retryable` 只允许使用用户手写说明，避免把空人物/地点/场景线索注入回响。

## 验证

- 后端：`./scripts/verify_backend.sh`
- iOS 静态合同：`swift Scripts/QA/prd-stitch-ui/archive-image-analysis-runtime-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- 部署 smoke 包装检查：`swift Scripts/QA/prd-stitch-ui/backend-archive-image-analysis-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- Release QA package：`swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- iOS 构建日志：`tmp/visual-qa/prd-stitch-ui/p1-archive-runtime-contract-build.log`
