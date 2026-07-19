# Profile Care Backend State Smoke

日期：2026-06-19

## 目标

把“心境追踪/关怀状态”的 UIQA 从本地 fallback 推进到真实后端状态验证：在已部署 FastAPI/Postgres 的 API 容器内生成隔离 QA 用户、短期 V2 用户会话和 care fixture，再进入 iOS Profile 页面渲染并断言。

本轮真实后端 UIQA 覆盖 active / empty / stale。失败态重试使用服务端签发的一次性 V2 用户会话、但将 iOS 构建指向不可达后端，验证“失败 -> 重新同步 -> 再次失败且保留入口”的客户端恢复行为；不向 iOS 注入机器 token，也不需要绕过关怀功能的发布策略。

## 覆盖范围

- 真实后端 `/health` 必须返回 `store=postgres`。
- 每个 active / empty / stale 状态使用各自的用户会话单独启动一次模拟器，避免跨账号读取被 QA 旁路掩盖。
- 真实后端以 active 用户主体写入并读取 active care snapshot。
- 真实后端以 stale 用户主体写入并读取 stale care snapshot。
- empty 用户以自身主体收到真实后端 404，再映射到 iOS empty 状态。
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
| failed | `profileCareStateFailed` | 不作为后端业务数据写入；`RUN_PROFILE_CARE_FAILURE_RETRY_ONLY=1` 使用真实短期用户会话和不可达 iOS 后端地址覆盖失败态重试失败 |

## 脚本

```bash
Scripts/QA/prd-stitch-ui/run-profile-care-backend-state-smoke.sh
```

脚本会优先读取：

- `BACKEND_BASE_URL`
- `DEPLOYED_BACKEND_ACCESS_DOC`
- `DreamJourneyBackend/private/deployed-backend-access.md`
- `DreamJourneyBackend/deployed-backend-access.md`

并通过当前服务器的 API 容器执行 fixture helper：

- `BACKEND_REMOTE_HOST`，默认 `miao-server`
- `BACKEND_REMOTE_ROOT`，默认 `/opt/services/dreamjourney/DreamJourneyBackend`

脚本不再使用 `BACKEND_API_TOKEN` 写入 `/care/snapshots`。该 token 是机器主体，线上授权模式下必须被 user route 拒绝。fixture helper 只在 API 容器内直连其私有 Postgres 创建一次性 QA 用户并签发短期 V2 用户会话；用户创建使用 `INSERT ... ON CONFLICT DO NOTHING`，碰撞时直接失败，绝不覆盖已有账号。每个 fixture 带独立 `qaFixtureMarker`，清理前会逐一核验 marker，清理后再次确认用户已不存在；marker 不匹配、清理失败或远程临时目录无法移除都会使 smoke 失败。

会话以 `0600` 临时文件复制到 Simulator Documents，App 读取后立即删除。正常完成路径会显式执行并校验服务器清理，异常路径由 `EXIT` trap 继续重试清理；保留的 QA 产物不包含会话 token 或 cleanup manifest。

在创建任何 QA 数据之前，fixture 会查询 `/v2/release-policy`。只有 `careDashboard` 被明确加入当前 closed-pilot canary 后才会继续；否则以 `careDashboardNotApprovedForClosedPilot` 失败。这是发布范围的有意边界，脚本不得通过伪造 QA audience 或 header 绕过。

### 本地失败/重试专用验证

下列命令只创建一个临时认证用户会话；iOS 使用不可达的后端地址，因此不会调用 `/care/snapshots`，也不需要 `careDashboard` 的 closed-pilot canary。它用于在完整服务器状态 smoke 尚未获批时，持续验证客户端失败恢复逻辑。

```bash
RUN_PROFILE_CARE_FAILURE_RETRY_ONLY=1 \
  Scripts/QA/prd-stitch-ui/run-profile-care-backend-state-smoke.sh
```

该模式仍要求部署后端健康检查返回 `store=postgres`，并会在退出时清理临时用户、会话与远程临时文件。

## 产物

- `backend-care-state-uiqa-fixtures-result.json`
- `backend-care-auth-cleanup-result.json`
- `profile-care-backend-state-smoke-result.json`
- `profile-care-backend-state-active-smoke-result.json`
- `profile-care-backend-state-empty-smoke-result.json`
- `profile-care-backend-state-stale-smoke-result.json`
- `profile-care-backend-failure-retry-smoke-result.json`
- `01-profile-care-backend-active.png`
- `02-profile-care-backend-empty.png`
- `03-profile-care-backend-stale.png`
- `04-profile-care-backend-failure-retry.png`
- `install/build.log`
- `failure-retry-install/build.log`
- `runtime-active.log`
- `runtime-empty.log`
- `runtime-stale.log`
- `failure-retry-runtime.log`
- `oslog-active.log`
- `oslog-empty.log`
- `oslog-stale.log`
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

默认不跑真实后端 UIQA，避免没有部署配置或服务器 SSH 权限时阻塞本地开发。需要发布/交接验收时优先打开公开 MVP 关怀/心境追踪 P0 回归门：

```bash
RUN_P0_PROFILE_CARE_REGRESSION=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

该开关会同时跑本地 empty / stale / failed UIQA，以及完整真实后端 active / empty / stale UIQA。完整真实后端部分会先执行 `careDashboard` closed-pilot canary 预检；未获批时必须停止且不创建 QA 数据。失败/重试客户端恢复可单独使用上述专用命令运行。只需要单独跑完整真实后端状态 smoke 时，仍可使用 `RUN_PROFILE_CARE_BACKEND_STATE_SMOKE=1`。

本 smoke 只验证公开 MVP 个人页/关怀状态，不暴露隐藏 PRD 功能。
