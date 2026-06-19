# 2026-06-19 Archive Image Analysis Live Chain

## Scope

本轮把 iOS 相册导入后的 AI 分析从 seed/mock 推进到真实后端调用链路：

1. 用户从相册或样张封存照片。
2. iOS 先保存本地 archive item，保持现有离线可用行为。
3. 如果已配置后端地址，则将压缩后的 JPEG base64 发送到 `/archive/image-analysis`。
4. 后端返回结构化字段后，iOS 合并为本地档案的分析结果。
5. iOS 再通过现有 archive item 同步链路把结构化结果同步回 `/archive/items`。

## Result Mapping

iOS 合并以下后端字段：

- `analysisStatus`
- `analysisSummary` / `description`
- `detectedPeople`
- `detectedLocations`
- `detectedScenes`
- `tags`
- `analysisFailureReason`
- `analysisRetryable`

地点线索和场景线索继续落到已有 metadata key，详情页与回响上下文复用同一份数据。

## Failure Handling

- 后端未配置：不发起请求，照片保持 pending，避免本地开发环境误报失败。
- 图片编码失败：标记为 `failed`，可稍后重试。
- 后端请求失败：标记为 `failed`，写入短失败原因，并同步该失败状态。

## Verification

- Static guard:
  - `tmp/visual-qa/prd-stitch-ui/archive-image-analysis-live-chain-check.swift`
- Existing guards:
  - `tmp/visual-qa/prd-stitch-ui/archive-analysis-backend-payload-contract-check.swift`
  - `tmp/visual-qa/prd-stitch-ui/archive-analysis-insights-contract-check.swift`
- Release package:
  - `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
  - `tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift`
