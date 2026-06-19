# Profile Care Backend State Smoke

日期：2026-06-19

## 目标

把“心境追踪/关怀状态”的 UIQA 从本地 fallback 推进到真实后端状态验证：用已部署 FastAPI/Postgres 后端生成 care fixture，再进入 iOS Profile 页面渲染并断言。

本轮真实后端 UIQA 覆盖 active / empty / stale；failed 作为读取失败 fallback 继续由本地状态 smoke 覆盖，并额外通过 invalid-token UIQA 覆盖“失败态重试失败”后的用户反馈。

## 覆盖范围

- 真实后端 `/health` 必须返回 `store=postgres`。
- 真实后端写入并读取 active care snapshot。
- 真实后端写入并读取 stale care snapshot。
- missing user 通过真实后端 404 映射到 iOS empty 状态。
- invalid care snapshot 通过真实后端 400 验证 failed 边界不会被错误持久化。
- iOS Profile 卡片和长辈关怀看板都必须显示一致状态。
- `重新同步` 按钮必须可点击，并从 stale 状态重新请求真实后端，刷新到 active/available 状态。
- 点击 `重新同步` 后必须立即显示 `正在重新同步关怀信号`，避免用户误以为按钮无响应。
- 当失败态点击 `重新同步` 且后端仍失败时，页面必须从 loading 回到 `关怀信号加载失败`，并保留 `重新同步` 入口。

## 状态模型

| 后端 fixture | iOS 状态 | 来源 |
| --- | --- | --- |
| active | `profileCareStateAvailable` | `/care/snapshots/latest/{activeUserId}` 成功响应 |
| empty | `profileCareStateEmpty` | `/care/snapshots/latest/{missingUserId}` 404 后安全 fallback |
| stale | `profileCareStateStale` | `/care/snapshots/latest/{staleUserId}` 成功响应，`windowEnd` 过期 |
| failed | `profileCareStateFailed` | 不作为后端业务数据写入；由本地 `run-profile-care-state-smoke.sh` 覆盖读取失败 fallback，并由 invalid-token UIQA 覆盖失败态重试失败 |

## 脚本

```bash
tmp/visual-qa/prd-stitch-ui/run-profile-care-backend-state-smoke.sh
```

脚本会优先读取：

- `BACKEND_BASE_URL`
- `BACKEND_API_TOKEN`
- `DEPLOYED_BACKEND_ACCESS_DOC`
- `DreamJourneyBackend/private/deployed-backend-access.md`
- `DreamJourneyBackend/deployed-backend-access.md`

## 产物

- `backend-care-state-uiqa-fixtures-result.json`
- `profile-care-backend-state-smoke-result.json`
- `profile-care-backend-failure-retry-smoke-result.json`
- `01-profile-care-backend-state-smoke.png`
- `02-profile-care-backend-failure-retry.png`
- `build.log`
- `failure-retry-build.log`
- `runtime.log`
- `failure-retry-runtime.log`
- `oslog.log`
- `failure-retry-oslog.log`

`profile-care-backend-state-smoke-result.json` 的 `retry` 对象必须包含：

- `retryActionFired=true`
- `retryInitialState=profileCareStateStale`
- `retryIntermediateState=profileCareStateLoading`
- `retryIntermediateSyncCaption` 包含 `正在重新同步关怀信号`
- `retryFinalState=profileCareStateAvailable`
- `retryRequestCountAdvanced=true`

`profile-care-backend-failure-retry-smoke-result.json` 的 `retry` 对象必须包含：

- `retryActionFired=true`
- `retryFailureInitialState=profileCareStateFailed`
- `retryIntermediateState=profileCareStateLoading`
- `retryIntermediateSyncCaption` 包含 `正在重新同步关怀信号`
- `retryFailureFinalState=profileCareStateFailed`
- `retryFailureFinalRetryVisible=true`
- `retryRequestCountAdvanced=true`

## Release Regression

默认不跑真实后端 UIQA，避免没有部署配置时阻塞本地开发。需要发布/交接验收时打开：

```bash
RUN_PROFILE_CARE_BACKEND_STATE_SMOKE=1 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

本 smoke 只验证公开 MVP 个人页/关怀状态，不暴露隐藏 PRD 功能。
