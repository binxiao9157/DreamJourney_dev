# 2026-06-19 Archive Analysis Backend Contract

## Scope

本轮把档案 AI 分析结果从 UI seed/mock 推进到真实后端 payload 合同：

- `detectedPeople`
- `detectedLocations`
- `detectedScenes`
- `tags`
- `analysisFailureReason`
- `analysisRetryable`

后端 `/archive/items` 会规范化并持久化这些字段；`GET /archive/items/{user_id}` 会回传同一结构。`/archive/image-analysis` 的 DeepSeek 解析结果也返回同一套字段，`dryRun=true` 额外返回 `responseContract` 供前端和 QA 对齐。

## iOS Handling

iOS `MemoryArchiveItem` 继续保留现有 UI 结构：

- 人物线索来自 `detectedPeople`
- 地点线索落到 `analysisLocationClues`
- 场景线索落到 `analysisSceneClues`
- 失败原因落到 `analysisFailureReason`
- 是否可重试落到 `analysisRetryable`

档案详情页和回响上下文都复用这些字段。公开 MVP 不新增入口，也不改变隐藏功能策略。

## Not Covered

这不是生产 AI 质量验收，也不证明真实图片分析准确率。真机图片上传、真实 provider 稳定性、失败重试队列和人工可解释性仍需后续验收。

## Verification

- Backend targeted unittest:
  - `ArchiveAPITests.test_archive_items_api_persists_structured_analysis_contract`
  - `ArchiveImageAnalysisAPITests.test_image_analysis_parse_returns_archive_insight_contract`
  - `ArchiveImageAnalysisAPITests.test_archive_image_analysis_dry_run_redacts_secret`
- iOS static guard:
  - `tmp/visual-qa/prd-stitch-ui/archive-analysis-backend-payload-contract-check.swift`
- Release package:
  - `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
  - `tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift`
