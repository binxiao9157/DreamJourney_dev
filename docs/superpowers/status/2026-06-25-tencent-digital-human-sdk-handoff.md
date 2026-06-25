# 腾讯云数智人 iOS SDK 接入 Handoff

日期：2026-06-25

## 当前结论

DreamJourney 当前已完成腾讯数智人后端 session 合同、iOS runtime 抽象、mock contract、降级链路和本地真实 SDK bridge 编译接入。真实接入路线走腾讯云渲染 iOS SDK，不再继续扩展本地 WKWebView / JS 假数字人。

官方云渲染 SDK 接入点已经明确：

- iOS SDK：`VirtualmanStreamSDK.xcframework`
- TRTC 依赖：`TXLiteAVSDK_TRTC_shuziren_13.0.20262`
- 鉴权字段：`appkey`、`accesstoken`
- 建流方式：
  - Asset 建流：`asset_virtualman_key`
  - Project 建流：`virtualman_project_id`
- SDK 初始化形态：
  - `VirtualmanParams(appkey:accesstoken:)`
  - `AssetVirtualmanParams(assetVirtualmanKey:)`
  - `VirtualmanProjectParams(virtualmanProjectId:)`
  - `ExtraInfo(alphaChannelEnable: true)`
- 渲染/会话形态：
  - `Virtualman(frame:)`
  - `openByAsset`
  - `open`
  - `chat(ChatParams(text:isNewChat:))`
  - `close`

## 官方 Demo 包

腾讯文档里的旧 Demo 下载链接当前返回 404：

`https://vh-data.ivh.qq.com/client/cloudsdk/ios/virtualman-stream-demo.zip`

已确认可用的新 Demo 下载链接：

`https://vh-data.ivh.qq.com/client/cloudsdk/ios/virtualman-stream-demo-ios.zip`

Downloaded package SHA-256:

`3056d8caff1b542a5301b69e8a979608662d4a25502832f7d40477989aaa2d1f`

第三方二进制不直接提交仓库。当前本机 SDK staging 状态：

- Demo 包：`tmp/tencent-digital-human-sdk/ios-demo/`
- Xcode 引用路径：`Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework`
- 以上目录均已被 `.gitignore` 忽略。

当前本机可编译是因为本地存在 `Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework`。后续如果要让 CI 或其它机器稳定复现，需要选择二进制管理策略：Git LFS、私有 artifact 下载脚本，或内部依赖仓库。

## 当前不可继续真实建流的缺口

当前已有 `appkey` / `accesstoken` 口径，但真实云渲染会话仍缺至少一个资产标识：

- `asset_virtualman_key`
- `virtualman_project_id`

两者二选一。缺少该字段时，后端只能保持 `mockContract` 或 SDK 合同草案，不能创建真实数智人云渲染会话。

## 后端配置口径

后端应继续使用这些字段：

- `TENCENT_DIGITAL_HUMAN_APP_KEY`
- `TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN`
- `TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY`
- `TENCENT_DIGITAL_HUMAN_VIRTUALMAN_PROJECT_ID`

以下字段只在启用腾讯 ASR 识别时需要，不应作为云渲染建流必填：

- `TENCENT_DIGITAL_HUMAN_APP_ID`
- `TENCENT_DIGITAL_HUMAN_SECRET_ID`
- `TENCENT_DIGITAL_HUMAN_SECRET_KEY`

## iOS 当前新增边界

当前新增 SDK 接入边界：

- `TencentDigitalHumanSDKConfiguration`
  - 固定 session、asset/project、alpha、driveMode、credentialMode 等配置。
- `TencentDigitalHumanSDKBridge`
  - 作为未来真实 `Virtualman` 适配器的协议。
  - 支持 `openByAsset`、`openByProject`、`sendText`、`sendPCM`、`interrupt`、`close`。
- `TencentDigitalHumanCloudRuntime`
  - 依赖 bridge 协议，不直接引用 `Virtualman` 或 TRTC 符号。
  - Asset 优先；没有 asset 时走 Project；两者都没有则失败并交给 Echo 降级。
- `TencentDigitalHumanSDKBridgeFactory`
  - 后续真实 SDK bridge 注册点。
- `TencentVirtualmanSDKBridge`
  - 引用 `VirtualmanStreamSDK` 和 `TXLiteAVSDK_TRTC`。
  - 内部创建 `Virtualman(frame:)` 作为渲染 view。
  - 根据后端 session 合同选择 `openByAsset` 或 `open`。
  - 文本驱动映射到 `chat` / `sendStreamText`。
  - PCM 入口映射到 `sendAudio`，先作为后续语音驱动预留。
- `AppDelegate`
  - 启动时注册 `TencentVirtualmanSDKBridge.registerFactory()`。

`TencentDigitalHumanCloudRuntime` 当前要求后端 session credential 返回 `appkey` / `accesstoken`。缺少凭证时会失败并降级，不在 iOS 侧硬编码长期密钥。

这样做的目的：

1. 当前工程可继续编译。
2. 公开版本仍然不暴露数智人。
3. 后续导入 `VirtualmanStreamSDK.xcframework` 时，只需要新增一个真实 bridge 实现，不需要重写 Echo 主链路。

## 后续接入步骤

1. 获取有效 SDK 包。
   - `VirtualmanStreamSDK.xcframework`
   - 腾讯数智人定制 TRTC podspec：`TXLiteAVSDK_TRTC_shuziren_13.0.20262`
2. 获取真实数智人资产。
   - `asset_virtualman_key` 或 `virtualman_project_id`
3. 后端部署真实配置并更新 `/digital-human/sessions`。
   - session credential 需要返回 `appkey` / `accesstoken`。
   - session payload 需要返回 `providerAssetId` 或 `providerProjectId`。
   - 继续由后端签发或封装 session 合同，不让 iOS 管理长期密钥。
4. 打开 QA gate。
   - 保持公开 release 默认隐藏。
   - QA launch arg 下验证云渲染画面、文本驱动、关闭会话、失败降级。

## 验证入口

- 静态检查：`tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-sdk-handoff-check.sh`
- Runtime 抽象检查：`tmp/visual-qa/prd-stitch-ui/run-digital-human-runtime-abstraction-check.sh`
- Session client 检查：`tmp/visual-qa/prd-stitch-ui/run-digital-human-session-client-check.sh`
- 腾讯云渲染 bridge 检查：`tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-cloud-runtime-smoke.sh`
- 部署后端 cloudRender 合同检查：`RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE=1 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
- 模拟器 smoke：`tmp/visual-qa/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh`

部署后端已配置 `TENCENT_DIGITAL_HUMAN_APP_KEY`、`TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN`，以及 `TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY` 或 `TENCENT_DIGITAL_HUMAN_VIRTUALMAN_PROJECT_ID` 后，验收标准是：

- `/config/runtime.digitalHuman.providerMode=cloudRender`
- `/config/runtime.digitalHuman.realProviderReady=true`
- `/config/runtime.digitalHuman.sdkAdapterLinked=true`
- `/digital-human/sessions` 返回 `credential.appkey` / `credential.accesstoken`
- `/digital-human/sessions` 返回 `providerAssetId` 或 `providerProjectId`
- `silent` lifecycle mode 不创建渲染 session
- 公开 release 仍保持 `defaultReleaseVisible=false`

最近验证：

- `tmp/visual-qa/prd-stitch-ui/run-tencent-digital-human-cloud-runtime-smoke.sh`
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-sdk-real-bridge-build CODE_SIGNING_ALLOWED=NO build`
- `RUN_ID=20260625-tencent-real-bridge-static RUN_STANDARD_BUILD=0 RUN_SIMULATOR_SMOKE=0 RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
