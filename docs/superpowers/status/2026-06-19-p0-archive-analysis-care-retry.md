# P0 档案分析与心境状态收敛

日期：2026-06-19

## 范围

- 档案详情将云端同步状态和 AI 分析可用性拆开展示。
- `analysisStatus=failed` 且 `analysisRetryable=true` 时，展示为 `AI 分析暂不可用，可稍后重试`，不再误导成云端同步失败。
- 档案详情的 `重新分析` 入口优先使用本地原图重新调用 `/archive/image-analysis`，再通过 `/archive/items` 持久化结果。
- Echo 档案上下文不再注入失败分析的人物、地点、场景、标签；但仍保留用户手写说明进入回响上下文。
- 心境追踪补齐 empty / stale / failed 的重试入口；后端 404 映射为空态，网络或后端异常映射为失败态，过期 `windowEnd` 映射为 stale。

## 验证

- `p0-archive-analysis-care-retry-check.swift`：通过。
- `profile-care-snapshot-check.swift`：通过，使用 `swiftc -parse-as-library` 编译模型后运行。
- `archive-context-snapshot-check.swift`：通过，覆盖 failed 分析只保留手写说明进入 Echo。
- 轻量 release regression：`20260619-p0-archive-care-static-r5` 通过。
- 部署后端 smoke：`20260619-p0-archive-analysis-retry-backend` 通过，`analysis_contract_mode=failed_retryable_provider_unavailable`，并通过 `/archive/items` 持久化和重新读取。
- 模拟器 Archive -> Echo smoke：`20260619-p0-archive-care-echo-smoke` 通过。
- iOS Debug simulator build：`tmp/visual-qa/prd-stitch-ui/p0-archive-care-build-r2.log`，`BUILD SUCCEEDED`。
- `git diff --check`：通过。

## 证据路径

- Release regression report: `tmp/visual-qa/prd-stitch-ui/release-regression/20260619-p0-archive-care-static-r5/report.md`
- Backend smoke report: `tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke/20260619-p0-archive-analysis-retry-backend/report.md`
- Archive -> Echo screenshot: `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260619-p0-archive-care-echo-smoke/01-archive-to-echo-completed.png`
- iOS build log: `tmp/visual-qa/prd-stitch-ui/p0-archive-care-build-r2.log`

## 后续

- 如果视觉 provider 切到支持图片输入的模型，需要再跑一轮真实 `analyzed` 合同验收，确认人物、地点、场景线索从后端真实返回。
- 真机阶段仍需验证相册权限、真实图片路径保留、重试入口触达和弱网恢复。
