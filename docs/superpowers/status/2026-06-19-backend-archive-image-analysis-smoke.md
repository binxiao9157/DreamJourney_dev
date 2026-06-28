# Backend Archive Image Analysis Smoke

## 目标

本轮新增真实部署后端 smoke，用于验证公开 MVP 的相册影像分析闭环：

相册导入 -> /archive/image-analysis -> /archive/items -> GET /archive/items

这个 smoke 不替代真机相册权限验收；它验证的是后端图像分析、结构化线索字段、Postgres 持久化和重新拉取展示所需字段。

## 配置

- 默认后端配置来源：`DreamJourneyBackend/private/deployed-backend-access.md` 或 `DreamJourneyBackend/deployed-backend-access.md`。
- 也可以显式传入 `BACKEND_BASE_URL` 和 `BACKEND_API_TOKEN`。
- `BACKEND_API_TOKEN` 只在本地环境变量中使用；脚本报告只记录“configured, value intentionally omitted”。
- 默认图片样本：`DreamJourney/Assets.xcassets/default_memory_1.imageset/memory.jpg`。

## 验证字段

脚本会要求：

- `/health` 返回 `status=ok` 且 `store=postgres`。
- `/archive/image-analysis` 返回 `analysisStatus=analyzed`。
- 分析结果至少包含摘要或可展示线索。
- `/archive/items` 成功保存同一条相册影像。
- `GET /archive/items/{userId}` 能重新读出同一条数据。
- 读回字段包括 `analysisStatus`、`analysisSummary`、`detectedPeople`、`detectedLocations`、`detectedScenes`、`tags`、`analysisFailureReason`、`analysisRetryable`。

## 运行方式

```bash
RUN_ID=20260619-backend-archive-image-analysis-smoke \
Scripts/QA/prd-stitch-ui/run-backend-archive-image-analysis-smoke.sh
```

可选接入 release regression：

```bash
RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE=1 \
RUN_ID=<run-id> \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 产物

- `tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke/<run-id>/backend-archive-image-analysis-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke/<run-id>/backend-archive-image-analysis-smoke.log`
- `tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke/<run-id>/report.md`

## 当前证据

### 2026-06-19 Provider Fallback 部署后验收通过

Run ID: `20260619-backend-archive-image-analysis-provider-fallback`

结果：passed。

已确认：

- `/health` 返回 `store=postgres`。
- `/archive/image-analysis` 在当前 DeepSeek 图片输入不可用时返回可持久化失败合同。
- `/archive/items` 成功保存同一条相册影像分析结果。
- `GET /archive/items/{userId}` 能重新读出同一条数据。

读回关键字段：

- `analysisStatus=failed`
- `analysisFailureReason=provider_unavailable`
- `analysisRetryable=true`
- `detectedPeople=[]`
- `detectedLocations=[]`
- `detectedScenes=[]`
- `metadata.source=album_import`
- `metadata.smokeMarker=20260619-backend-archive-image-analysis-provider-fallback`

产物：

- `tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke/20260619-backend-archive-image-analysis-provider-fallback/report.md`
- `tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke/20260619-backend-archive-image-analysis-provider-fallback/backend-archive-image-analysis-smoke-result.json`

结论：

- “相册导入 -> /archive/image-analysis -> /archive/items -> GET /archive/items” 的失败/可重试持久化闭环已通过部署后端验收。
- 公开 MVP 可以基于该状态显示“分析失败，可稍后重试”，避免误显示为云端同步失败。
- 真正的人物/地点/场景线索仍需切换到明确支持视觉输入的 provider 后再做 full analysis 验收。

### 2026-06-19 Provider 不可用降级合同

后端已按产品降级策略调整：

- 当 `/archive/image-analysis` 的真实 provider 不可用、缺少 key、上游 400/5xx、返回非 JSON 等异常发生时，不再返回 HTTP 502/503。
- 非 `dryRun` 请求返回可持久化的失败合同：
  - `analysisStatus=failed`
  - `analysisFailureReason=provider_unavailable`
  - `analysisRetryable=true`
  - `detectedPeople=[]`
  - `detectedLocations=[]`
  - `detectedScenes=[]`
  - `tags=[]`
- 参数缺失、隐私范围不允许等产品/权限错误仍保持 400/403。

Smoke 脚本已同步更新：

- `analyzed`：继续要求摘要或可展示线索。
- `failed + provider_unavailable + retryable`：继续写入 `/archive/items`，再通过 `GET /archive/items/{userId}` 验证 read-after-write。

部署后重跑：

```bash
RUN_ID=20260619-backend-archive-image-analysis-provider-fallback \
Scripts/QA/prd-stitch-ui/run-backend-archive-image-analysis-smoke.sh
```

预期：

- 在当前 DeepSeek 不支持图片输入的前提下，smoke 应通过“失败/可重试状态持久化”闭环。
- 真正的人物/地点/场景线索仍需要切到明确支持视觉输入的 provider 后再验收。

### 2026-06-19 重新部署后验证

Run ID: `20260619-backend-archive-image-analysis-after-deploy`

结果：blocked。

已确认：

- `DreamJourneyBackend/main`、`origin/main` 和服务器声明版本均为 `782a92b`。
- `POST /archive/image-analysis?dryRun=true` 已返回 `responseContract`。
- `responseContract` 包含 `analysisStatus`、`analysisSummary`、`detectedPeople`、`detectedLocations`、`detectedScenes`、`tags`、`analysisFailureReason`、`analysisRetryable`。
- 失败边界已经从“部署旧版本”推进到“真实 provider 调用”。

失败点：

- `POST /archive/image-analysis` 返回 502。
- 后端捕获到 DeepSeek 上游 `400 Bad Request`。
- dryRun 看到当前部署请求：
  - upstream URL: `https://api.deepseek.com/v1/chat/completions`
  - model: `DeepSeek-V4-Flash`
  - user message content: `text + image_url` 数组

对照 DeepSeek 官方文档：

- Chat Completion API 是 `/chat/completions`。
- 模型枚举是 `deepseek-v4-flash` / `deepseek-v4-pro`。
- user message `content` 合同是文本字符串。
- Models & Pricing 也只标记 DeepSeek V4 Flash/Pro 的 Chat/Text 能力，没有明确视觉输入能力。

结论：

- 后端部署合同已更新，但当前 DeepSeek provider 请求仍不满足官方 chat completion 合同。
- 真实“相册导入 -> 图像分析 -> 持久化 -> 重新拉取线索”闭环还不能验收通过。
- 下一步需要部署 provider 不可用降级合同；真实视觉线索仍需要切换到明确支持视觉输入的 provider。

产物：

- `tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke/20260619-backend-archive-image-analysis-after-deploy/report.md`
- `tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke/20260619-backend-archive-image-analysis-after-deploy/backend-archive-image-analysis-smoke.log`

### 2026-06-19 重新部署前验证

Run ID: `20260619-backend-archive-image-analysis-smoke-preflight`

结果：blocked。

失败点：

- `/health` 已可访问，部署后端地址为 `https://dreamjourney-api.liftora.cn`。
- `POST /archive/image-analysis?dryRun=true` 没有返回 `responseContract`。
- 当前本地后端 `DreamJourneyBackend/main` 已包含 `responseContract` 合同，但本地分支相对 `origin/main` 为 `ahead 4`，部署服务很可能仍在运行旧的远端 main。

前一次真实调用证据：

- Run ID: `20260619-backend-archive-image-analysis-smoke`
- `/archive/image-analysis` 返回 502。
- 后端上游错误为 DeepSeek `400 Bad Request`。
- dryRun 看到部署后端实际转发到 `https://api.deepseek.com/v1/chat/completions`，模型为 `DeepSeek-V4-Flash`，user content 是 `text + image_url` 数组。

根因判断：

1. 部署版本未包含当前本地后端 archive analysis insight contract，因此无法证明 `detectedPeople`、`detectedLocations`、`detectedScenes`、`analysisFailureReason`、`analysisRetryable` 的部署合同。
2. DeepSeek 官方 chat completion 文档当前描述的接口是 `/chat/completions`，模型名是 `deepseek-v4-flash` / `deepseek-v4-pro`，user message content 是文本字符串；当前部署请求使用图片 `image_url` 数组，存在 provider 合同不匹配风险。

当时下一步：

1. 先把本地后端 `main` 的 4 个提交推送并重新部署服务器。
2. 部署后重跑：

```bash
RUN_ID=20260619-backend-archive-image-analysis-after-deploy \
Scripts/QA/prd-stitch-ui/run-backend-archive-image-analysis-smoke.sh
```

3. 如果仍然失败在 DeepSeek 400，需要切换到明确支持视觉输入的 provider，或把 `/archive/image-analysis` 改成“后端结构化合同 + provider 不可用时返回可重试失败状态”的产品降级方案。
