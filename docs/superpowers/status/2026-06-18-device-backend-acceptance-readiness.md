# Device And Backend Acceptance Readiness

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Scope: PRD P0 真机验收与后端验收就绪包。

## Status

当前状态是 **真机安装/启动已通过，权限与完整语音对话仍待人工验收**，并且 **公网后端模拟器 release-like 验收已通过**。

这不是“真机已验收”，也不是 APNs 真机通知已验收，也不是生产语音 SDK 质量已验收。

原因：

- 当前工程已经具备模拟器核心闭环、后端配置注入、token 合约检查、后端环境 smoke 脚本和静态 guard。
- 部署后的 FastAPI/Postgres 后端已经通过 release-like 模拟器验收，包括 archive/care/family、push-token、delayed-reply persistence，以及 `POST /echo/delayed-replies/dispatch-due` 服务端待投递合同。
- 已接受的部署后端验收 run：`20260618-deployed-echo-dispatch-contract-accepted-211732`。
- 该 run 验证了 `echoDelayedReplyDispatchState=readyForProvider` 和 `echoDelayedReplyProviderDeliveryAttempted=false`，但没有声明 APNs provider delivery 或真机通知到达。
- 真机已可被 Xcode 识别为 `platform:iOS` 设备；iPhoneOS 不签名编译已通过。
- 本轮已修复本机签名 profile 缺失问题，完成真机 signed build、安装和启动。
- 真机 console 证据显示端侧 `SpeechEngineToB` SDK 初始化成功，`DialogEngine` 返回 `initEngine = 0`。
- 生产语音 SDK 质量验收仍待人工触发麦克风权限、完成至少一轮 ASR/TTS 对话、前后台切换，并采集错误恢复证据。
- 语音链路 readiness 已分层：mock ASR/TTS 只证明状态机；后端 token fallback 只证明降级可控；生产 SDK readiness 必须依赖真机验收证据包。当前不声明生产语音闭环完成。
- APNs 注册曾在真机 console 中失败，原因是缺少 `aps-environment` entitlement；当前工程已改为运行时检测 entitlement，Personal Team 构建会跳过 APNs 注册以避免系统失败。`DreamJourney/DreamJourney.entitlements` 已保留为付费开发者 Team 开启 Push Notifications 后的配置入口。

## Source Of Truth

- PRD: 最新附件 `《寻梦环游 产品PRD V1.0》(1).md`。
- UI: 当前 Stitch 画布和 `htmlCode` 源码为准，MCP screenshot 只作辅助复核。
- Core simulator regression: `tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh`。
- Backend environment regression: `tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh`。

## Backend And Voice Configuration

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
- `run-true-device-voice-preflight.sh` 会自动读取 `DreamJourney/Config/Backend.local.xcconfig`；`DREAMJOURNEY_BACKEND_BASE_URL` 和 `DREAMJOURNEY_BACKEND_API_TOKEN` 也可以通过 smoke 脚本环境变量覆盖。
- `DREAMJOURNEY_BACKEND_API_TOKEN` 为空时，`run-backend-env-smoke.sh` 必须失败，避免误用无鉴权环境。

生产语音 SDK 配置同样只能通过本地配置、环境变量或 xcodebuild build setting 注入，不要把真实 key 提交。

Recommended local file:

```xcconfig
// DreamJourney/Config/VoiceSDK.local.xcconfig
VOLCENGINE_APP_ID = your-real-volcengine-app-id
VOLCENGINE_APP_KEY = your-real-volcengine-app-key
VOLCENGINE_APP_TOKEN = your-real-volcengine-app-token
```

Rules:

- `DreamJourney/Config/VoiceSDK.example.xcconfig` 只保留示例占位值。
- `DreamJourney/Config/VoiceSDK.local.xcconfig` 已在 `.gitignore` 中忽略。
- `run-true-device-voice-preflight.sh` 会自动读取 `DreamJourney/Config/VoiceSDK.local.xcconfig`；`VOLCENGINE_APP_ID`、`VOLCENGINE_APP_KEY`、`VOLCENGINE_APP_TOKEN` 也可以通过环境变量覆盖。
- `VolcEngineAppID`、`VolcEngineAppKey` 和 `VolcEngineAppToken` 在 `Info.plist` 中通过 `$(VOLCENGINE_APP_ID)`、`$(VOLCENGINE_APP_KEY)`、`$(VOLCENGINE_APP_TOKEN)` 解析。
- `DialogEngineManager` 会在生产语音 SDK 配置缺失或仍为占位值时提前失败，不继续启动 `SpeechEngineToB`。
- `VoiceSDKReadinessSummary` 明确区分 mock ASR/TTS、后端 token fallback、生产 SDK readiness 和已通过真机验收。未完成真机麦克风、ASR、TTS、播放路由、前后台和日志证据前，不允许把状态标为生产语音闭环完成。

## Backend Acceptance

当前选定部署后端已经通过 release-like simulator scope。证据见：

- `docs/superpowers/status/2026-06-18-release-like-backend-acceptance.md`
- `tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-deployed-echo-dispatch-contract-accepted-211732/`

后续如果后端重新部署、合同字段变化，或要切换另一个后端环境，再执行：

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
  - `familyRefreshSucceeded = true`
  - `containsBackendFamilyMember = true`
  - `backendFamilyMemberCount >= 1`

If this fails:

- 401/403 优先检查 `DREAMJOURNEY_BACKEND_API_TOKEN`。
- 连接错误优先检查 `DREAMJOURNEY_BACKEND_BASE_URL`、证书、网络和服务进程。
- 字段缺失优先检查后端契约是否与当前 `DreamJourneyBackendClient` 保持一致。
- family 断言失败优先检查 `/family/invite`、`/family/members/{userId}/{memberId}/accept` 和 `/family/members/{userId}` 是否返回 active/accepted 成员。
- dispatch 断言失败优先检查 `/echo/delayed-replies/dispatch-due` 是否部署到当前公网后端路由表。
- APNs provider delivery 和真机通知到达不由该 simulator smoke 证明，需要单独真机验收。

## True Device Acceptance

真机验收必须由用户提供设备和签名条件后执行，模拟器不能替代。
本阶段已把真机验收证据包格式固定下来：回响语音验收和语音档案验收都必须生成 `evidence-manifest.md`，并按固定截图、日志、人工记录文件收敛证据。证据包覆盖麦克风、相册、语音识别、前后台、播放路由、截图和日志，但证据包本身不代表真机验收通过。

Preflight command:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
DREAMJOURNEY_BACKEND_BASE_URL="https://your-backend.example.com" \
DREAMJOURNEY_BACKEND_API_TOKEN="your-real-token" \
VOLCENGINE_APP_ID="your-real-volcengine-app-id" \
VOLCENGINE_APP_KEY="your-real-volcengine-app-key" \
VOLCENGINE_APP_TOKEN="your-real-volcengine-app-token" \
tmp/visual-qa/prd-stitch-ui/run-true-device-voice-preflight.sh
```

Expected preflight behavior:

- 在线物理 iPhone/iPad 可被 `xcodebuild -showdestinations` 发现；脚本同时保存 `devicectl` 和 `xctrace` 结果作为辅助诊断。
- 后端 URL/token 和生产语音 SDK key 均已设置且不是占位值。
- `NSMicrophoneUsageDescription`、`NSSpeechRecognitionUsageDescription`、`NSPhotoLibraryUsageDescription`、`NSCameraUsageDescription` 均存在。
- 可选真机构建通过，并生成 `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/<run-id>/report.md`。
- 同一 run 目录必须生成 `evidence-manifest.md`、`manual-qa-notes.md` 和 `console-output.log`，用于记录截图、日志、播放路由与前后台恢复证据。

Current 2026-06-18 evidence:

- Device detection smoke: `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260618-device-detection-smoke/report.md`
- Local config preflight: `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260618-local-config-preflight/report.md`
- Device source: `xcodebuild -showdestinations`
- Device destination: `id=00008150-001402D60A04401C`
- iPhoneOS no-sign compile: passed, log at `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260618-ios-device-compile-nosign/ios-device-nosign-build.log`
- Signed physical-device build: passed after restoring the missing local provisioning profile file; report at `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260618-true-device-preflight-after-profile-copy/report.md`
- True-device install and launch: passed, evidence under `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260618-true-device-install-launch/`
- Installed app: `com.yxj.dreamjourney.app`, version `1.0.0`, bundle version `1`
- Running process: `DreamJourney.app/DreamJourney`, PID `6846` in `processes.json`
- Console launch evidence: `console-output.log` includes `SpeechEngineToB` SDK initialization and `[DialogEngine] ✅ 引擎初始化成功`
- APNs entitlement status: `DreamJourney/DreamJourney.entitlements` declares `aps-environment=development`, but the default Personal Team build does not force `CODE_SIGN_ENTITLEMENTS` because Apple personal development teams do not support Push Notifications capability.
- APNs current behavior: `AppDelegate` checks the embedded provisioning profile for `aps-environment`; if missing, it logs `APNs entitlement missing; skip remote notification registration` and does not call `registerForRemoteNotifications()`.
- APNs gated-registration evidence: `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260618-apns-gated-registration-launch/console-output.log` contains the skip log and no longer contains the previous system failure `remote notification registration failed: 未找到应用程序的“aps-environment”的授权字符串`.
- APNs remaining acceptance: use a paid Apple Developer Team / profile with Push Notifications enabled, build with `DreamJourney/DreamJourney.entitlements`, confirm APNs returns a device token, then verify backend token registration and provider delivery.

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
- `manual-qa-notes.md` 中必须记录麦克风、相册、语音识别、前后台、播放路由、截图和日志是否齐全。

## Archive Audio True-Device Acceptance

语音档案真机前置验收使用专用脚本，不和回响语音对话验收混在一起：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260619-archive-audio-true-device-preflight \
tmp/visual-qa/prd-stitch-ui/run-true-device-archive-audio-preflight.sh
```

该脚本会保存 `xcodebuild-destinations.txt`、`devicectl-devices.txt`、`xctrace-devices.txt` 和 `report.md`，并在在线真机可用时执行 Debug device build。设备离线、未解锁、未信任或 Xcode 无法发现物理设备时，脚本必须写出 blocked report，不允许声明通过。
同一 run 目录还会生成 `evidence-manifest.md`、`audio-quality-notes.md`、`playback-route-notes.md` 和 `background-foreground-notes.md`，用来固定录音质量、播放路由、前后台恢复和截图证据格式。

人工验收仍要使用 hidden QA 入口 `DJEnableArchiveHiddenBranches`，确认：

- 记忆档案 -> 封存新记忆 -> 录入语音。
- 首次麦克风授权、拒绝、从系统设置重新授权均可恢复。
- 保存后的语音档案可进入详情播放路由。
- 前后台切换后列表、详情和本地音频文件不丢。
- 录音质量需要人工记录，包含清晰度、音量、噪声、截断和播放失败。

需要保存截图：

- `01-audio-permission-allow.png`
- `02-audio-permission-deny.png`
- `03-audio-permission-recover.png`
- `04-audio-created.png`
- `05-audio-detail-playback.png`
- `06-audio-after-background-foreground.png`

对应状态文档：

- `docs/superpowers/status/2026-06-19-true-device-archive-audio-acceptance.md`

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
swift tmp/visual-qa/prd-stitch-ui/backend-family-acceptance-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/true-device-voice-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/voice-sdk-readiness-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/true-device-archive-audio-acceptance-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/true-device-acceptance-evidence-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

These prove:

- 本地真实 token 不会被提交。
- 后端 URL/token 通过 build setting 或环境变量注入。
- 生产语音 SDK key 通过 build setting 或环境变量注入。
- 关键隐私权限声明仍在。
- 后端 smoke 和档案到回响核心 smoke 仍可被发现。
- PRD 验收状态不会被误写为“真机已完成”。

## Blocking Conditions / 阻塞条件

需要停下来找用户的情况：

- 要切换新的真实 `DREAMJOURNEY_BACKEND_BASE_URL` / `DREAMJOURNEY_BACKEND_API_TOKEN`，或当前部署后端无法访问。
- 要执行生产语音 SDK 验收但缺少 `VOLCENGINE_APP_ID` / `VOLCENGINE_APP_KEY` / `VOLCENGINE_APP_TOKEN`。
- 用户提供真机、Apple 开发者签名、证书或设备操作之前，不能跑真机验收。
- 如果后端契约需要改字段、迁移数据或删除数据，需要用户确认产品/兼容性取舍。
- 如果要公开家庭管理、账号注销、医生联系、星辰/静默/阳光模式入口，需要用户确认发布边界。

## Acceptance Boundary

This document closes the readiness gap only.

It does close:

- 当前选定公网后端的 simulator release-like 验收记录归档。

It does not close:

- 真机已验收。
- APNs provider delivery / 真机通知到达。
- 语音 SDK 生产质量已验收。
- 家庭/persona 管理公开发布。
- 账号注销、医生联系或数字继承完整生命周期。
