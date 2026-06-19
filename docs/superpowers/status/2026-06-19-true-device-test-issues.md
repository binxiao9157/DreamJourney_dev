# 真机测试问题记录

日期：2026-06-19

分支：`feature/prd-stitch-ui-adaptation`

目标：记录近期真机测试中暴露的问题、根因、处理状态和后续验收边界，避免后续继续把同一类问题当成新缺口反复排查。

## 问题 1：APNs 注册失败

现象：

```text
[PushDeviceToken] remote notification registration failed: 未找到应用程序的“aps-environment”的授权字符串
```

根因：

- 当前真机构建使用的签名描述文件没有 `aps-environment` entitlement。
- Personal Team 不支持 Push Notifications capability。
- 这不是后端 token 注册失败，也不是 APNs provider delivery 失败。

处理状态：

- 已通过 `1a65922 fix: gate APNs registration by entitlement` 收敛。
- App 启动时检测 embedded provisioning profile；缺少 `aps-environment` 时跳过 APNs 注册并输出受控日志。
- 当前 Personal Team 真机验收不再被 APNs entitlement 缺失阻塞。

仍未完成：

- APNs 真实 device token 返回。
- iOS 端真实 token 注册到后端。
- 后端 provider delivery。
- 真机远程通知到达截图和日志。

后续条件：

- 付费 Apple Developer Team。
- 当前 Bundle ID 开启 Push Notifications。
- 包含 `aps-environment` 的 provisioning profile。
- APNs provider 证书或 token 配置。

详细记录：

- `docs/superpowers/status/2026-06-18-apns-true-device-registration-report.md`

## 问题 2：回响提示“生产语音服务尚未完成配置”

现象：

```text
生产语音服务尚未完成配置，请先注入火山语音 AppID、AppKey 和 Token
```

根因：

- 真机包最初使用了工程默认 build settings。
- 默认值仍是占位符：
  - `VOLCENGINE_APP_ID = YOUR_VOLCENGINE_APP_ID`
  - `VOLCENGINE_APP_KEY = YOUR_VOLCENGINE_APP_KEY`
  - `VOLCENGINE_APP_TOKEN = YOUR_VOLCENGINE_APP_TOKEN`
- `DialogEngineManager` 从 app `Info.plist` 读取 `VolcEngineAppID`、`VolcEngineAppKey`、`VolcEngineAppToken`，因此占位符会被正确识别为未配置。

处理状态：

- 已用本地私密配置生成临时 xcconfig，重新构建并安装真机 Debug 包。
- 构建后已删除临时 xcconfig。
- 构建日志已脱敏，并扫描确认没有残留私密配置值。
- 这次处理不改变源码，只修正真机验收包的注入方式。

当前状态：

- 已确认真机包内 `Info.plist` 的语音配置和后端配置均为已配置状态。
- 仍不能据此声明生产语音闭环完成；还需要真机验证麦克风授权、ASR/TTS 质量、播放路由、网络错误恢复和前后台恢复。

证据：

- `tmp/visual-qa/prd-stitch-ui/true-device-build/20260619-device-debug-build-voice-config/report.md`
- `docs/superpowers/status/2026-06-19-production-voice-sdk-readiness-boundary.md`

## 问题 3：封存的相册详情看不到之前照片

现象：

- `档案详情` 的 `相册影像` 卡片显示占位图。
- 页面仍显示 `本地已保存`。
- 设备容器中 `Documents/archive-images` 下的 JPG 文件实际还存在。

根因：

- 档案条目保存的是旧 app 数据容器的绝对路径。
- iOS 覆盖安装或重装后，app 数据容器 UUID 会变化。
- 旧路径类似：

```text
/var/mobile/Containers/Data/Application/00F86A9C-.../Documents/archive-images/<filename>.jpg
```

- 当前容器里同名文件仍在，但详情页之前只按旧 `localPath` 读取图片。
- `本地已保存` 文案之前只判断 `localPath != nil`，没有校验文件是否可读。

处理状态：

- 已通过 `17cd86e fix: recover archive local media paths` 修复。
- `MemoryArchiveItem` 新增本地文件路径恢复：
  - 先使用原路径。
  - 原路径失效时，按文件名从当前 `Documents/archive-images`、`archive-audio`、`archive-video`、`archive-video-thumbnails` 恢复。
- `MemoryArchiveRepository` 读取档案时会把恢复后的当前路径写回本地存储。
- 档案列表、详情页、图片重新分析、音频播放、视频缩略图均改为使用恢复后的真实可读路径。
- `本地已保存` 改为基于真实可读路径判断。

真机验证：

- 修复前设备 Preferences 中的照片路径容器 UUID 为 `00F86A9C-...`。
- 修复后重新安装启动，Preferences 中同一条照片路径已迁移到当前容器 UUID `1AE68982-...`。
- 文件名保持不变，说明照片文件未丢失，只是旧绝对路径失效。

新增回归门：

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-local-file-path-recovery-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

该检查已接入：

- `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
- `tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift`

证据：

- 真机构建/安装/启动：`tmp/visual-qa/prd-stitch-ui/true-device-build/20260619-photo-path-debug/`
- 新增 guard：`tmp/visual-qa/prd-stitch-ui/archive-local-file-path-recovery-check.swift`

## 当前真机验收边界

已收敛：

- Personal Team 下 APNs entitlement 缺失不再阻塞启动。
- 真机 Debug 包可注入语音和后端私密配置。
- 覆盖安装后，封存照片的本地路径可自动恢复。

仍需继续验收：

- 麦克风授权允许、拒绝、恢复。
- 相册权限和真实照片导入完整流程。
- 生产 ASR/TTS 质量与错误恢复。
- TTS / 语音档案播放路由。
- 前后台切换后的回响状态、档案状态、本地媒体文件状态。
- APNs provider delivery 和真机通知到达。

