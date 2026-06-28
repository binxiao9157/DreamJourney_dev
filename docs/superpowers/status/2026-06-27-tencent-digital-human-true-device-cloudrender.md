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

## 2026-06-28 普通重启可见性修复

用户反馈：通过真机 smoke 启动时可以看到数字人，但手动关掉 App 再从桌面打开，Echo 页面又回到普通状态，看不到数字人。

根因：

- 旧实现仍依赖 `DJShowDigitalHumanLivePanel`、`DJRunDigitalHumanLivePanelSmoke`、`DJRunTencentDigitalHumanTextDriveSmoke` 这些 QA launch arg 临时打开面板。
- 手动从桌面重新打开 App 时不会带这些 launch arg，因此 `shouldShowDigitalHumanLivePanel` 返回 false，`DigitalHumanLivePanelView` 不会创建。
- 这不是腾讯云会话失败，也不是后端配置丢失，而是公开发布入口没有真正从 QA flag 转成默认公开。

修复：

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
- 模拟器截图：`tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260628-digital-human-public-default/01-digital-human-runtime-stub.png`
- 真机构建日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-digital-human-public-default-reopen/device-build.log`
- 真机安装日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-digital-human-public-default-reopen/install.log`
- 真机普通启动日志：`tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-digital-human-public-default-reopen/launch.log`
