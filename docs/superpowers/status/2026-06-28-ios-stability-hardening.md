# 2026-06-28 iOS 工程稳定性加固

## 背景

本轮目标是把当前 iOS 工程从“能跑”继续收敛到“同事拉代码后更容易判断环境、QA 脚本位置稳定、数字人状态更不容易漂移”的状态。

## 已完成

### 1. QA 脚本迁出 tmp

- 长期维护的 PRD/Stitch/UIQA/smoke 脚本已迁移到：
  - `Scripts/QA/prd-stitch-ui/`
- `tmp/visual-qa/prd-stitch-ui/` 保留为运行产物目录：
  - 截图
  - 日志
  - JSON 结果
  - 可重新生成的构建缓存
- 新增 `Scripts/QA/prd-stitch-ui/qa-script-location-check.swift`，防止后续再把长期脚本放回 `tmp/`。

### 2. iOS doctor 环境检查

- 新增：
  - `Scripts/doctor-ios.sh`
  - `Scripts/QA/prd-stitch-ui/ios-doctor-check.swift`
- doctor 覆盖：
  - `DreamJourney.xcworkspace`
  - CocoaPods 安装状态
  - `Vendor/TencentDigitalHuman/VirtualmanStreamSDK.xcframework`
  - `Backend.local.xcconfig`
  - `VoiceSDK.local.xcconfig`
  - 签名覆盖配置：`DREAMJOURNEY_DEVELOPMENT_TEAM` / `DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER`
  - 后端 `/health`
  - 后端 `/config/runtime`
- doctor 不打印密钥正文，只输出 `value intentionally omitted`。

### 3. 数字人会话状态 coordinator

- 新增：
  - `DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift`
- 从 `EchoViewController` 收敛出的状态：
  - 当前回合 ID
  - 腾讯数智人 provider request ID
  - 等待完成的 provider reply
  - 去重用的最近 reply text
  - provider 说话期间暂停火山/本地 DialogEngine 的标记
  - provider 说完后是否恢复聆听
- 新增：
  - `Scripts/QA/prd-stitch-ui/digital-human-conversation-coordinator-check.swift`
- 已更新数字人音频 owner 检查，使其检查 coordinator 语义，而不是继续依赖 `EchoViewController` 的散落私有字段。

## 当前约定

- 长期 QA 脚本放 `Scripts/QA/prd-stitch-ui/`。
- 运行产物、截图、临时日志放 `tmp/visual-qa/prd-stitch-ui/`。
- `tmp/` 默认可清理；不要在其中新增需要长期维护的源码脚本。
- 同事拉代码后先跑：

```bash
Scripts/doctor-ios.sh
```

如果 doctor 报错，优先补本地配置或 SDK 包，再跑构建。

## 验证入口

```bash
swift Scripts/QA/prd-stitch-ui/qa-script-location-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/ios-doctor-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/digital-human-conversation-coordinator-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift "$PWD"
```

## 后续注意

- 如果继续改腾讯数智人连续对话，不要绕过 `DigitalHumanConversationCoordinator` 直接新增散落状态。
- 如果新增 QA 脚本，优先放到 `Scripts/QA/prd-stitch-ui/` 并接入 release QA package。
- 如果新增临时截图/日志，放 `tmp/visual-qa/prd-stitch-ui/`，不要提交大体积产物。
