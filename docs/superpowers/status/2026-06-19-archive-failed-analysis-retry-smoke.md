# 档案分析失败重试 UIQA Smoke

## 目标

把“档案详情 failed 状态 -> 点击重新分析”的入口，从静态检查和后端 smoke 推进到可重复的模拟器交互回归。

## 覆盖范围

- 种子数据：已云端同步、AI 分析失败、可重试的相册影像。
- 页面：`MemoryArchiveDetailViewController` 档案详情。
- 交互：触发 `archive-analysis-retry-button` 的真实按钮 action。
- 后端：使用部署后端配置调用 `/archive/image-analysis`。
- 结果：允许 provider fallback 返回 `analysisStatus=failed` 且 `analysisRetryable=true`；未来接入真实视觉 provider 后，也允许成功落到 `analysisStatus=analyzed`。

## 一键运行

```bash
RUN_ID=20260619-archive-failed-analysis-retry-smoke \
tmp/visual-qa/prd-stitch-ui/run-archive-failed-analysis-retry-smoke.sh
```

脚本会优先读取：

- `BACKEND_BASE_URL`
- `BACKEND_API_TOKEN`
- `DreamJourneyBackend/private/deployed-backend-access.md`
- `DreamJourneyBackend/deployed-backend-access.md`

token 只写入 `tmp` 下的临时 `backend-private.xcconfig`，不进入 git。

## 输出证据

- `tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke/<run-id>/archive-failed-analysis-retry-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke/<run-id>/01-archive-failed-analysis-retry.png`
- `tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke/<run-id>/runtime.log`
- `tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke/<run-id>/oslog.log`

## Release 回归接入

- 静态 guard：`tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke-check.swift`
- release regression 默认只跑静态 guard。
- 如需把交互 smoke 纳入一键回归：

```bash
RUN_ARCHIVE_FAILED_ANALYSIS_RETRY_SMOKE=1 \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

## 验收条件

- 初始档案状态为 `failed`。
- “重新分析”按钮可见且 action 已触发。
- 后端配置已注入。
- 最终状态为 `failed` 或 `analyzed`。
- 如果最终仍为 `failed`，必须保持 `analysisRetryable=true`。
- 云端状态保持“云端已同步”，不再误显示为“同步失败”。
