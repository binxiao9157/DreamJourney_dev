# 腾讯云数智人真机云渲染验收记录

日期：2026-06-27

## 目标

在当前部署后端配置下，用真机验证 DreamJourney 的 Echo 数字人面板是否能进入腾讯云渲染 iOS SDK 链路，并明确下一步阻塞点。

## 当前版本

- iOS 仓库：`DreamJourney_dev`
- 分支：`feature/prd-stitch-ui-adaptation`
- 基线提交：`700b5cb`
- 后端环境：`https://dreamjourney-api.liftora.cn`
- 后端数智人模式：`cloudRender`
- 资产模式：`asset`
- 公开发布态：数字人入口默认开启；`DJDisableDigitalHumanLivePanel` 仅用于 QA 隔离普通 Echo

敏感配置不写入仓库。后端继续负责持有腾讯云数智人长期凭证，iOS 只消费 `/config/runtime` 和 `/digital-human/sessions` 返回的会话合同。

## 本轮 iOS 对齐

本轮将部署后端返回的 `providerMode=cloudRender` 接入真实 SDK runtime：

- `DigitalHumanRuntimeFactory`：将 `cloudRender` 视为真实腾讯 SDK provider mode。
- `FeatureFlagService` / `EchoViewController`：数字人面板默认公开，真机 debug / QA 可用 `DJDisableDigitalHumanLivePanel` 临时关闭。
- `EchoViewController`：进入 Echo 后读取 runtime capability，创建 digital human session，并把 TTS 文本发送给数智人 runtime。
- `DigitalHumanLivePanelView`：支持把真实 SDK provider view 挂载到现有数字人面板中。

## 验证命令

已执行：

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-binary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-handoff-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-trtc-compat-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-digital-human-cloudrender-device-build -xcconfig DreamJourney/Config/YXJ.local.xcconfig -allowProvisioningUpdates build
codesign --verify --deep --strict tmp/visual-qa/prd-stitch-ui/tencent-digital-human-cloudrender-device-build/Build/Products/Debug-iphoneos/DreamJourney.app
```

结果：

- 静态检查通过。
- release QA package 检查通过。
- `git diff --check` 通过。
- 真机 Debug 构建通过。
- app 签名校验通过。
- 构建产物已包含 `VirtualmanStreamSDK.framework`。
- 真机安装成功。
- 开发者证书信任后，真机启动成功。

## 真机启动证据

证据目录：

`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260627-tencent-digital-human-cloudrender-device-smoke/`

关键文件：

- `install.json`
- `install.log`
- `launch-after-trust.json`
- `launch-after-trust.log`
- `processes-after-launch.json`
- `processes-after-launch.log`
- `console-after-trust.log`

启动结果：

```text
Launched application with com.yxj.dreamjourney.app bundle identifier.
```

真机日志确认 QA 数字人面板已打开：

```text
[QA] Digital human live panel enabled by launch argument
```

## 当前真实阻塞

真机日志确认 iOS 已经调用到腾讯 SDK，并由 SDK 请求腾讯云渲染网关：

```text
[vhsdk-http] POST url: https://gw.tvs.qq.com/.../createsessionbyasset?appkey=<redacted>
[vhsdk-http] POST status: 200
[vhsdk-http] POST result length: 248
[vhsdk-apaas] createSession failed: code=100014, message=AssetConcurrencyQuotaNotFound: 未找到有效的并发配额，请您申请延期或加购
```

结论：

- 这不是 iOS 没有接入 SDK。
- 这不是后端 runtime 没有同步。
- 这不是 AppKey / AccessToken / asset key 没传到 SDK。
- 当前阻塞是腾讯云数智人资产侧没有有效并发配额，导致 `createsessionbyasset` 建流失败。

## 下一步处理

需要在腾讯云数智人控制台处理其一：

1. 给当前 2D 数智人资产申请延期或加购有效并发配额。
2. 如果并发配额绑定在项目而不是资产上，则切到 `virtualman_project_id` 项目建流模式，并确保 iOS 不再优先走 asset 建流。

配额处理完成后，复跑同一真机 smoke。下一轮验收标准：

- `createsessionbyasset` 或 project 建流不再返回 `100014`。
- SDK 建流成功。
- 真机数字人画面出现首帧。
- Echo TTS 文本可以驱动数智人说话。
- 失败时仍可降级回普通 Echo，不破坏公开主链路。

## 备注

日志里同时出现：

```text
[PushDeviceToken] APNs entitlement missing; skip remote notification registration
```

这是 APNs entitlement 的独立问题，不影响本次数智人 SDK 建流判断。

## 2026-06-28 复测更新

后端重新配置并部署后，已复跑真机数字人 smoke。

证据目录：

`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-no-trtc-duplicate/`

关键文件：

- `install.json`
- `install.log`
- `launch-with-digital-human.json`
- `launch-with-digital-human.log`
- `console-with-digital-human.log`
- `key-events.txt`
- `summary-counts.txt`

本轮确认：

- 真机安装成功，Bundle ID 为 `com.yxj.dreamjourney.app`。
- 签名使用本机可用 Team：`2BTR77V3R8`。
- 默认启动即可打开数字人链路；QA launch arg `DJShowDigitalHumanLivePanel` 仅保留兼容旧脚本。
- 腾讯云渲染会话不再返回 `AssetConcurrencyQuotaNotFound`。
- SDK WebSocket 已打开。
- 真机收到腾讯数智人首帧：`first video frame ... size=1080x1920`。
- `AssetConcurrencyQuota` / `QuotaNotFound` 计数为 0。
- `Class TRTC ... implemented in both` 重复类告警计数为 0。

本轮同时修正了 CocoaPods 链接策略：`TXLiteAVSDK_TRTC` 继续作为编译期依赖保留，但从 App target 的 `OTHER_LDFLAGS` 中剥离，避免 `VirtualmanStreamSDK` 已内置的 TRTC 类被 App 再链接一次。`TXFFmpeg` 和 `TXSoundTouch` 仍保留为运行时依赖。

已执行验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' -xcconfig DreamJourney/Config/YXJ.local.xcconfig -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-digital-human-no-trtc-duplicate-build build
xcrun devicectl device install app --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 tmp/visual-qa/prd-stitch-ui/tencent-digital-human-no-trtc-duplicate-build/Build/Products/Debug-iphoneos/DreamJourney.app
xcrun devicectl device process launch --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 --terminate-existing --console --timeout 120 com.yxj.dreamjourney.app DJShowDigitalHumanLivePanel
```

当前剩余未验证项：

- 本轮 120 秒日志没有出现 `sendStreamText`、`TextStart`、`TextOver`，说明还没有捕获到完整 Echo 回复文本驱动腾讯数智人说话的回合。
- 真机截图工具在当前命令行环境不可用，本轮视觉证据以腾讯 SDK 首帧日志为准。
- 下一轮应在真机日志采集窗口内手动触发一次完整 Echo 对话，或新增 Debug/QA-only 真机自动文本驱动 smoke，以验证文本驱动、说话中、TextOver 超时保护和状态回落。

## 2026-06-28 普通重启可见性能力落地

用户反馈：通过真机 smoke 启动时可以看到数字人，但手动关掉 App 再从桌面打开，Echo 页面又回到普通状态，看不到数字人。

根因：

- 旧实现仍依赖 `DJShowDigitalHumanLivePanel`、`DJRunDigitalHumanLivePanelSmoke`、`DJRunTencentDigitalHumanTextDriveSmoke` 这些 QA launch arg 临时打开面板。
- 手动从桌面重新打开 App 时不会带这些 launch arg，因此 `shouldShowDigitalHumanLivePanel` 返回 false，`DigitalHumanLivePanelView` 不会创建。
- 这不是腾讯云会话失败，也不是后端配置丢失，而是公开发布入口没有真正从 QA flag 转成默认公开。

实现：

- `DJFeature.digitalHumanLivePanel` 加入 `FeatureFlagService.defaultEnabled`。
- `FeatureFlagService.currentStorageVersion` 从 9 升到 10，避免旧安装继续沿用历史隐藏状态。
- `EchoViewController.shouldShowDigitalHumanLivePanel` 保留 `DJShow...` / `DJRun...` 兼容旧 smoke，同时新增 `DJDisableDigitalHumanLivePanel` 作为 QA 隔离普通 Echo 的显式关闭参数。
- release feature matrix、digital-human live panel 文档、SDK handoff 文档和静态检查全部更新为“数字人默认公开，失败降级普通 Echo”的口径。

验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-sdk-handoff-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-session-client-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-digital-human-public-default-build CODE_SIGNING_ALLOWED=NO build
RUN_ID=20260628-digital-human-public-default tmp/visual-qa/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'id=00008150-001402D60A04401C' -derivedDataPath tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-digital-human-public-default-reopen/DerivedData -xcconfig DreamJourney/Config/YXJ.local.xcconfig -allowProvisioningUpdates build
xcrun devicectl device install app --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-digital-human-public-default-reopen/DerivedData/Build/Products/Debug-iphoneos/DreamJourney.app
xcrun devicectl device process launch --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 com.yxj.dreamjourney.app
```

结果：

- 相关静态检查通过。
- `git diff --check` 通过。
- iOS generic build 通过。
- 模拟器 runtime stub smoke 通过，结果 JSON 中 `defaultReleaseVisible=true`。
- 真机构建、安装、普通启动通过，启动时未携带任何数字人 QA launch arg。

证据：

- 模拟器结果：`tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260628-digital-human-public-default/digital-human-runtime-stub-smoke-result.json`

## 2026-06-28 腾讯数智人公开展示与连续对话能力落地

用户真机反馈：

- Echo 启动连接腾讯云渲染前，会先闪出本地女生数字人素材。
- 腾讯数智人说完后，麦克风回到停止状态，需要再次手动点击才能继续说。
- 停止后仍可能残留 provider 语音。
- 首句响应体感偏慢。

根因：

- `DigitalHumanLive.html` 在 WebView `load` 后默认执行 `startRealAssetPreview()`，公开模式下也会先播放 bundled `01.mp4` 本地素材。
- `removeHostedProviderView()` 在 provider fallback 时重新显示本地 Web renderer，导致腾讯连接失败或慢连接时可能暴露非腾讯形象。
- `resumeDialogEngineAfterTencentProviderSpeechIfNeeded` 之前按半双工保守策略直接 `resetToIdle()`，不会在 Tencent `TextOver` 后自动恢复 ASR 聆听。
- 腾讯负责声音时，`onChatStreaming` 一直等待 SDK TTSStarted fallback，不会对已形成完整句的流式文本做提前 provider prewarm。

实现：

- `DigitalHumanLive.html` 新增 `localPreviewEnabled` / `setLocalPreviewEnabled(...)`，本地素材预览改为 QA-only 显式开启；公开启动不再自动播放 `01.mp4`。
- `DigitalHumanLivePanelView` 默认隐藏 Web renderer，新增 `showProviderPlaceholder(...)`，腾讯连接中只显示中性占位，不暴露本地素材。
- provider 失败或 fallback 时只移除 hosted provider view，不再重新显示本地 Web renderer。
- Tencent `TextOver` 后改为调用 `resumeVoiceCaptureAfterTencentProviderSpeech(...)`，自动以 `sendsGreeting: false` 恢复 DialogEngine ASR 聆听，直到用户主动点击停止。
- 用户停止时，如果腾讯 provider 语音仍在播，会调用 `interruptDigitalHumanPlayback(reason: "userStop")` 中断 provider 播放，但不 close/remove 腾讯数智人视图。
- `tencentDigitalHumanDialogResumeDelay` 后续收敛为按回复文本长度估算的安全等待，最短 `2.6s`、最长 `8.0s`。
- 腾讯接管声音时，不再从 streaming 文本提前触发 provider prewarm；provider 文本派发等待 SDK final/fallback 文本，避免提前停止火山上游生成。

验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build CODE_SIGNING_ALLOWED=NO build
```

结果：

- 数字人面板静态检查通过。
- 腾讯单音频 owner / 停止语义检查通过。
- runtime abstraction 检查通过。
- `git diff --check` 通过。
- iOS Simulator Debug 构建通过。
- 真机 Debug 构建通过。
- 真机安装通过，Bundle ID 为 `com.yxj.dreamjourney.app`。
- 普通启动不带 QA launch arg，腾讯 SDK WebSocket 打开，收到并渲染首帧：`first video frame ... size=1080x1920`。

证据：

- 构建日志：`tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build/build.log`
- 真机证据目录：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/`
- 真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build.log`
- 真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install.log`
- 真机普通启动日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch.log`
- 真机普通启动返回 0 日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console.log`
- 最终包真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build-r2.log`
- 最终包真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install-r2.log`
- 最终包真机普通启动返回 0 日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console-r2.log`

### 2026-06-28 连续对话完整播报能力落地

用户复测反馈：

- 第一轮第一句有声音。
- 后续回合没有声音，或一句话只剩最后一两个字有声音。

根因：

- 上一轮为降低响应延迟，允许 `onChatStreaming` 在检测到完整标点时提前 `scheduleDigitalHumanReplyPrewarm(...)`。
- 但腾讯接管声音时，真正发送 provider 文本前会调用 `pauseDialogEngineForTencentProviderSpeechIfNeeded()`，也就是停止火山 DialogEngine，避免火山和腾讯同时抢音频。
- 如果在 streaming 阶段提前发送，就会在 `SEEventChatEnded` 之前停掉上游生成，导致后续回复文本没有完整生成；真机表现就是第一句有声音，后续没声音或只剩尾音。

实现：

- 腾讯接管声音时，`onChatStreaming` 只更新 UI / pending 文本，不再做 provider prewarm。
- provider 文本派发重新收敛到 ChatEnded / final text 之后的既有 `onTTSStarted(text:)` 兜底路径。
- 连续对话的 TextOver 后自动恢复聆听逻辑保留。

验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

证据：

- 模拟器构建日志：`tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build/build-r3.log`
- 真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build-r3.log`
- 真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install-r3.log`
- 真机普通启动返回 0 日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console-r3.log`
- 模拟器截图：`tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260628-digital-human-public-default/01-digital-human-runtime-stub.png`
- 真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-digital-human-public-default-reopen/device-build.log`
- 真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-digital-human-public-default-reopen/install.log`
- 真机普通启动日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-digital-human-public-default-reopen/launch.log`

### 2026-06-28 连续对话单音频 owner 能力落地

用户继续复测反馈：

- 仍存在连续对话声音异常。
- 表现为第一句可能正常，后续回复前半段无声或只剩尾音。

进一步根因：

- 腾讯 SDK 的 `TextOver` 更接近“文本驱动结束/状态回到 ready”，不能直接等价为“远端音频已经完全从扬声器播完”。
- 之前连续对话在 `TextOver` 后恢复 ASR 的等待窗口过短，火山录音侧重新打开时可能抢占 AVAudioSession，导致腾讯云渲染音频前半段被压掉。
- 自动恢复连续对话路径没有像用户手动点击麦克风一样，先静音腾讯 TRTC 远端音频再打开火山 ASR。

实现：

- `TencentVirtualmanSDKBridge` 将 `WaitingTextOver`、`SentenceStart`、`SentenceNext`、`WaitingTextStart` 映射为 provider speech progress，运行态保持 `.speaking`，便于真机日志诊断腾讯侧语音进度。
- `completeTencentDigitalHumanReplyIfNeeded()` 在 `TextOver` 后保留 reply 文本，按文本长度估算恢复 ASR 的等待时间：最短 `2.6s`，最长 `8.0s`，日志输出 `resumeDelay`。
- `resumeVoiceCaptureAfterTencentProviderSpeech(...)` 自动恢复开麦前调用 `muteTencentProviderRemoteAudioForUserCapture(...)`，只静音腾讯远端音频，不 interrupt、不 close 腾讯会话。
- `sendTextChunk(...)` 在下一次腾讯数字人说话前会重新 `setRemoteAudioMuted(false)`，保持“用户说话时腾讯静音、腾讯说话时火山不开麦”的单音频 owner 规则。

验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'id=B7887DD8-3561-5F2A-8D62-A3FEACDC80D9' -derivedDataPath tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/DerivedData -xcconfig DreamJourney/Config/YXJ.local.xcconfig -allowProvisioningUpdates build
xcrun devicectl device install app --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/DerivedData/Build/Products/Debug-iphoneos/DreamJourney.app
xcrun devicectl device process launch --device B7887DD8-3561-5F2A-8D62-A3FEACDC80D9 --terminate-existing com.yxj.dreamjourney.app
```

证据：

- 模拟器构建日志：`tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build/build-r4.log`
- 真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build-r4.log`
- 真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install-r4.log`
- 真机普通启动返回 0 日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console-r4.log`
- 补充远端静音能力后的模拟器构建日志：`tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build/build-r5.log`
- 补充远端静音能力后的真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build-r5.log`
- 补充远端静音能力后的真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install-r5.log`
- 补充远端静音能力后的真机普通启动返回 0 日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console-r5.log`

### 2026-06-28 自动恢复聆听过渡态能力落地

用户复测反馈：

- 声音已经正常。
- 但腾讯数智人说完后会长时间显示“回信已抵达”，期间无法继续对话。

根因：

- 上一轮为避免声音截断，`TextOver` 后按回复文本长度估算等待时间，最短 `2.6s`、最长 `8.0s`。
- 但 `TextOver` 已经是 provider 文本驱动结束/接近音频结束后的事件，再按整句时长等待会造成二次等待。
- `markReplyDelivered()` 会进入 `.replied`，该状态 UI 显示“回信已抵达”并禁用麦克风，所以等待窗口内看起来像卡住。

实现：

- `TextOver` 后恢复 ASR 改为短 post-audio settle delay：默认 `1.2s`，长回复额外 `0.6s`，不再按整句播放时长等待。
- 自动恢复期间的 `.replied` UI 改为“准备继续听您说”，麦克风按钮保持可用，用户可手动提前继续。
- 手动提前继续仍会走腾讯远端静音 + 火山 ASR 启动路径，避免重新引入音频 owner 抢占。

验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

证据：

- 模拟器构建日志：`tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build/build-r6.log`
- 真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build-r6.log`
- 真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install-r6.log`
- 真机普通启动返回 0 日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console-r6.log`

### 2026-06-28 自动恢复聆听停止语义能力落地

用户复测反馈：

- 虽然文案显示“准备继续听您说”，但按钮仍是麦克风开始样式，会误解为对话已经停止。

实现：

- 自动恢复聆听的 `.replied` 过渡态文案改为“正在恢复聆听”。
- 按钮图标改为 `stop.fill`，并保持脉冲动画，表达当前仍处于连续对话流程。
- 过渡期间点击按钮不再表示“继续语音”，而是复用正常停止路径，结束当前连续对话。

验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

证据：

- 模拟器构建日志：`tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build/build-r7.log`
- 真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build-r7.log`
- 真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install-r7.log`
- 真机普通启动返回 0 日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console-r7.log`

### 2026-06-28 数字人说话打断能力落地

能力目标：

- 目标体验是数字人说话时可以点击停止打断。
- 之前 active request 仍在时可以打断，但腾讯 SDK 可能先发 `TextOver`，实际尾音仍在播放；此时 `activeRequestID` 已清空，点击停止只会结束本地状态，不一定会向腾讯 SDK 发送 stop。

实现：

- 新增 `shouldInterruptTencentDigitalHumanOnUserStop`，把 active provider speech 和 post-TextOver 自动恢复窗口都纳入用户停止打断范围。
- `interruptDigitalHumanPlayback(...)` 对腾讯云渲染 runtime 改用 `interruptPlaybackIfNeeded(reason:)`。
- `TencentDigitalHumanCloudRuntime.interruptPlaybackIfNeeded(...)` 允许在 `.ready`、`.buffering`、`.speaking` 状态调用 provider stop，用于截断 TextOver 后仍在播放的尾音；不 close/remove 数字人视图。

验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

证据：

- 模拟器构建日志：`tmp/visual-qa/prd-stitch-ui/tencent-digital-human-continuous-dialog-build/build-r8.log`
- 真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build-r8.log`
- 真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install-r8.log`
- 真机普通启动返回 0 日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console-r8.log`
