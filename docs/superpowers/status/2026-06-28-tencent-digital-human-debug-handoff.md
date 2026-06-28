# 2026-06-28 腾讯数智人调试进展与交接说明

## 当前分支

- iOS 工程路径：`/Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- 当前分支：`feature/prd-stitch-ui-adaptation`
- 远程仓库：`origin git@github.com:binxiao9157/DreamJourney_dev.git`
- 本轮目标：把 Echo 页腾讯云渲染数智人从“能显示”推进到“真实对话可测试”，并收敛声音、口型、连续对话、停止/打断语义。

## 当前链路

公开 Echo 页默认展示数字人入口，流程如下：

1. iOS 读取 `/config/runtime` 的 `digitalHuman` capability。
2. iOS 调 `/digital-human/sessions` 获取后端签发的腾讯会话合同。
3. `DigitalHumanRuntimeFactory` 根据合同选择 runtime：
   - `provider=tencent` 且 `providerMode=cloudRender/tencentSDK`，并且 SDK adapter 可用时，走 `TencentDigitalHumanCloudRuntime`。
   - capability 不完整或 SDK adapter 缺失时，回落 `AudioOnlyDigitalHumanRuntime` 或不可用占位。
4. Echo 文本回复通过 `VirtualmanStreamSDK` 的 `sendText(TextParams)` 驱动腾讯数智人，由腾讯云渲染负责声音和口型。
5. 火山 `DialogEngine` 只负责用户 ASR 和上游对话生成；腾讯数智人接管播报时，火山本地 TTS 播放关闭。

## 本轮已解决的问题

### 1. 启动闪出本地女生素材

问题：腾讯云渲染连接前，WebView 本地预览素材会先显示，造成“先出现女生、再切腾讯数智人”的错觉。

处理：

- `DigitalHumanLive.html` 增加 `localPreviewEnabled`，默认不自动播放本地素材。
- `DigitalHumanLivePanelView` 默认隐藏 Web renderer，连接中显示中性 provider placeholder。
- provider fallback 时不再重新展示本地素材，只显示“数字人暂不可用”。

### 2. 腾讯数智人声音被火山链路抢占

问题：火山 ASR/TTS 和腾讯云渲染同时操作音频会话时，会出现没声音、只剩尾音、口型/声音不同步。

处理：

- 腾讯接管播报时关闭 Fire/Volcengine 本地 TTS。
- 发送腾讯文本前暂停 DialogEngine。
- `onChatStreaming` 不再提前 provider prewarm，等待 final/fallback 文本后再发给腾讯，避免提前停止上游生成。
- `TextOver` 后只做短暂 post-audio settle，不再按整句时长二次等待。

### 3. 连续对话自动恢复

问题：数字人说完后停在“回信已抵达”，需要手动重新点麦克风。

处理：

- `TextOver` 后自动恢复 DialogEngine ASR，且 `sendsGreeting=false`，避免火山再播开场白。
- 自动恢复聆听期间显示“正在恢复聆听”，按钮为 `stop.fill`，保留脉冲，避免误解为已停止。
- 用户点停止时走正常停止路径，结束当前连续对话。

### 4. 数字人说话打断

问题：active request 期间可以打断，但腾讯 SDK 可能先发 `TextOver`，实际尾音仍在播放；此时点停止不一定能打断 provider。

处理：

- 新增 `shouldInterruptTencentDigitalHumanOnUserStop`，覆盖 active provider speech 和 post-TextOver 自动恢复窗口。
- `TencentDigitalHumanCloudRuntime.interruptPlaybackIfNeeded(reason:)` 允许在 `.ready / .buffering / .speaking` 状态向腾讯 SDK 发 stop。
- 打断只停止当前发声，不 close/remove 腾讯数智人视图。

### 5. 单音频 owner 规则

当前约束：

- 用户说话时：腾讯远端音频静音，火山 ASR 打开。
- 数字人说话时：火山 DialogEngine 暂停，腾讯云渲染负责声音和口型。
- 停止按钮：优先打断腾讯当前发声或尾音，再停止本地对话状态。

## 关键文件

- `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
  - Echo 状态机、连续对话、音频 owner、停止/打断语义。
- `DreamJourney/Sources/Modules/Echo/DigitalHumanLivePanelView.swift`
  - WebView/provider view hosting、本地预览显隐、snapshot/UIQA。
- `DreamJourney/Resources/web/DigitalHumanLive.html`
  - 本地数字人预览、fallback renderer、QA-only local preview。
- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift`
  - 腾讯云渲染 runtime、远端静音、provider stop。
- `DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift`
  - `VirtualmanStreamSDK` 桥接、`TextStart/TextOver/Sentence*` 状态映射。
- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift`
  - 腾讯 SDK bridge 协议与事件。

## 回归检查

本轮主要守护脚本：

- `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift`
  - 检查单音频 owner、TextOver 恢复、远端静音、停止打断、UI 过渡态。
- `tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift`
  - 检查 runtime/provider abstraction 和腾讯 SDK bridge 状态映射。
- `tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift`
  - 检查 WebView/local preview/provider placeholder 显隐策略。
- `tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift`
  - 汇总 release QA package 静态门。

本轮已跑过的关键验证：

```bash
swift tmp/visual-qa/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-runtime-abstraction-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/digital-human-live-panel-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'id=<device-id>' -xcconfig DreamJourney/Config/YXJ.local.xcconfig -allowProvisioningUpdates build
```

真机 r8 证据路径：

- `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-build-r8.log`
- `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-install-r8.log`
- `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260628-tencent-digital-human-continuous-dialog/device-launch-no-console-r8.log`

## 同事拉代码后能否直接使用

结论：同事可以直接拉当前分支获得代码改动和腾讯 iOS SDK 二进制。只要本地 CocoaPods、后端访问配置和真机签名配置齐全，就可以编译真实腾讯数智人链路。

### 已随仓库提交：腾讯 iOS SDK 二进制

项目引用：

- `Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework`

该 SDK 已从 `.gitignore` 放出并随仓库提交，团队成员拉取当前分支后不需要再手动放置 `VirtualmanStreamSDK.xcframework`。后续 SDK 升级时，直接替换该目录并提交即可。

### 必需：CocoaPods 依赖

项目依赖 `TXLiteAVSDK_TRTC`、`SpeechEngineToB`、`Moya` 等 Pod。

同事拉代码后需要执行：

```bash
pod install
```

然后使用 `DreamJourney.xcworkspace` 构建。

### 必需：后端运行配置

iOS 不直连腾讯数智人密钥。真实会话由后端通过 `/config/runtime` 和 `/digital-human/sessions` 下发。

后端需要具备：

- 腾讯数智人 `appkey`
- 腾讯数智人 `accesstoken`
- `virtualmanProjectId` 或 `asset_virtualman_key`
- provider mode 为 `cloudRender` 或 `tencentSDK`
- `/config/runtime` 返回 `digitalHuman.enabled=true`、`realProviderReady=true`
- `/digital-human/sessions` 返回 `credential.appkey`、`credential.accesstoken` 和项目/形象 ID

如果后端 capability 不完整，iOS 会自动回落到普通回响或 audio-only，不会暴露本地假数字人素材。

### 必需：iOS 本地配置

本地私密配置不提交。需要从 example 复制：

```bash
cp DreamJourney/Config/Backend.example.xcconfig DreamJourney/Config/Backend.local.xcconfig
cp DreamJourney/Config/VoiceSDK.example.xcconfig DreamJourney/Config/VoiceSDK.local.xcconfig
```

需要填入：

- `DREAMJOURNEY_BACKEND_BASE_URL`
- `DREAMJOURNEY_BACKEND_API_TOKEN`
- `VOLCENGINE_APP_ID`
- `VOLCENGINE_APP_KEY`
- `VOLCENGINE_APP_TOKEN`

真机构建还需要同事自己的签名配置，例如创建本地 `*.local.xcconfig`：

```text
#include "Backend.local.xcconfig"
#include "VoiceSDK.local.xcconfig"

DREAMJOURNEY_DEVELOPMENT_TEAM = <your team id>
DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER = <your bundle id>
```

本机当前使用的 `YXJ.local.xcconfig` 是私有文件，不提交。

### 可选：后端本地或部署环境

如果使用已部署后端，同事只需要填部署 URL 和 token；不需要在 iOS 本地配置腾讯数智人的 `appkey` / `accesstoken`。

如果本地跑后端，还需要在后端仓库配置腾讯数智人环境变量，并确认：

```bash
GET /health
GET /config/runtime
POST /digital-human/sessions
```

返回符合 iOS 解析合同。

## 当前剩余风险

- 真机“听感”仍需要人工验收，自动化只能证明代码合同、构建和启动。
- 腾讯 SDK `TextOver` 与真实音频结束之间仍可能有 provider 内部时序差异；当前通过短 settle delay、尾音 stop 和远端静音规避。
- 腾讯 SDK 二进制已纳入 Git；后续需要注意 SDK 授权范围和仓库体积增长。
- 若后端切换 `asset_virtualman_key` / `virtualmanProjectId`，iOS 不需要改代码，但需要重新跑真机回归。
