# Device And Backend Acceptance Readiness

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Scope: PRD P0 真机验收与后端验收就绪包。

## Status

当前状态是 **验收就绪**，不是“真机已验收”或“真实后端已验收”。

原因：

- 当前工程已经具备模拟器核心闭环、后端配置注入、token 合约检查、后端环境 smoke 脚本和静态 guard。
- 真实验收待用户提供后端环境和真机，包括真实 `DREAMJOURNEY_BACKEND_BASE_URL`、`DREAMJOURNEY_BACKEND_API_TOKEN`、Apple 签名/设备操作和系统权限弹窗确认。
- 在真实后端和真机未执行前，不能声明真机已验收，也不能声明线上后端已验收。

## Source Of Truth

- PRD: 最新附件 `《寻梦环游 产品PRD V1.0》(1).md`。
- UI: 当前 Stitch 画布和 `htmlCode` 源码为准，MCP screenshot 只作辅助复核。
- Core simulator regression: `tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh`。
- Backend environment regression: `tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh`。

## Backend Configuration

真实后端配置只能通过本地配置或环境变量注入，不要把真实 token 提交。

Recommended local file:

```xcconfig
// DreamJourney/Config/Backend.local.xcconfig
DREAMJOURNEY_BACKEND_BASE_URL = https://your-backend.example.com
DREAMJOURNEY_BACKEND_API_TOKEN = your-real-token
```

Rules:

- `DreamJourney/Config/Backend.example.xcconfig` 只保留示例值和占位 token。
- `DreamJourney/Config/Backend.local.xcconfig` 已在 `.gitignore` 中忽略。
- `DREAMJOURNEY_BACKEND_BASE_URL` 和 `DREAMJOURNEY_BACKEND_API_TOKEN` 也可以通过 smoke 脚本环境变量传入。
- `DREAMJOURNEY_BACKEND_API_TOKEN` 为空时，`run-backend-env-smoke.sh` 必须失败，避免误用无鉴权环境。

## Backend Acceptance

用户提供真实后端后，执行：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
BACKEND_BASE_URL="https://your-backend.example.com" \
BACKEND_API_TOKEN="your-real-token" \
tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh
```

Expected behavior:

- `backend-auth-token-contract-check.py` 通过，证明后端要求 token 鉴权。
- `backend-integration-contract-check.py` 通过，证明档案、关怀、聚合数据契约可用。
- App 使用 `DJRunBackendEnvSmoke` 启动参数完成后端 smoke。
- 产物包含 `backend-env-smoke-result.json`、`app-archive-store-summary.json`、`report.md` 和截图。
- `backend-env-smoke-result.json` 中：
  - `completed = true`
  - `archiveRefreshSucceeded = true`
  - `containsBackendContractPhoto = true`
  - `careMoodStatus = 需关注`

If this fails:

- 401/403 优先检查 `DREAMJOURNEY_BACKEND_API_TOKEN`。
- 连接错误优先检查 `DREAMJOURNEY_BACKEND_BASE_URL`、证书、网络和服务进程。
- 字段缺失优先检查后端契约是否与当前 `DreamJourneyBackendClient` 保持一致。

## True Device Acceptance

真机验收必须由用户提供设备和签名条件后执行，模拟器不能替代。

Required privacy keys in `DreamJourney/Resources/Info.plist`:

- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSCameraUsageDescription`

Manual true-device checklist:

- 首次进入回响页时，麦克风权限弹窗文案正确，允许后能进入录音状态。
- 拒绝麦克风权限后，页面给出可恢复的错误反馈，不崩溃。
- 重新在系统设置打开麦克风权限后，回响可恢复录音。
- 进入档案创建照片入口时，照片权限弹窗文案正确。
- 选择照片后，档案可生成本地分析状态，并能出现在回响上下文。
- 语音识别权限弹窗出现时文案正确；拒绝后语音链路降级可控。
- 真机后台/前台切换后，录音状态、档案持久化和回响状态不丢失。

True-device evidence to save:

- 真机系统版本、设备型号、构建配置。
- 回响权限允许/拒绝/恢复三组截图。
- 照片选择到档案沉淀再到回响上下文的截图。
- 控制台或设备日志中与权限、录音、照片选择相关的错误摘要。

## Simulator Core Regression

每次 Stitch UI、档案逻辑或回响逻辑更新后，先跑核心闭环回归：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
```

Expected artifacts:

- `archive-to-echo-smoke-result.json`
- `01-archive-to-echo-completed.png`
- `build.log`
- `runtime.log`
- `oslog.log`

Expected JSON:

- `completed = true`
- `containsArchiveContext = true`
- `availableItemCount >= 1`

## Static Guards

Run these before committing acceptance-related changes:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/backend-env-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

These prove:

- 本地真实 token 不会被提交。
- 后端 URL/token 通过 build setting 或环境变量注入。
- 关键隐私权限声明仍在。
- 后端 smoke 和档案到回响核心 smoke 仍可被发现。
- PRD 验收状态不会被误写为“真机已完成”。

## Blocking Conditions / 阻塞条件

需要停下来找用户的情况：

- 用户提供真实 `DREAMJOURNEY_BACKEND_BASE_URL` 和 `DREAMJOURNEY_BACKEND_API_TOKEN` 之前，不能跑真实后端验收。
- 用户提供真机、Apple 开发者签名、证书或设备操作之前，不能跑真机验收。
- 如果后端契约需要改字段、迁移数据或删除数据，需要用户确认产品/兼容性取舍。
- 如果要公开家庭管理、账号注销、医生联系、星辰/静默/阳光模式入口，需要用户确认发布边界。

## Acceptance Boundary

This document closes the readiness gap only.

It does not close:

- 真实后端已验收。
- 真机已验收。
- 语音 SDK 生产质量已验收。
- 家庭/persona 管理公开发布。
- 账号注销、医生联系或数字继承完整生命周期。
