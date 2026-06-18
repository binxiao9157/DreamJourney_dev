# APNs True Device Registration Report

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Commit under test: `1a65922 fix: gate APNs registration by entitlement`

Scope: 真机启动时的 APNs 注册失败定位、修复和回归验证。

## Summary

本轮处理的是连接真机启动后出现的 APNs 注册失败：

```text
[PushDeviceToken] remote notification registration failed: 未找到应用程序的“aps-environment”的授权字符串
```

结论：

- 当前失败不是后端 token 注册问题，也不是 APNs provider delivery 问题。
- 根因是当前开发签名描述文件没有 `aps-environment` entitlement。
- 继续强行调用 `registerForRemoteNotifications()` 会在 Personal Team 构建里稳定触发系统级失败。
- 直接在默认工程里强制启用 Push Notifications capability 会导致当前 Personal Team 真机构建失败。
- 当前修复策略是：运行时检测 embedded provisioning profile 是否包含 `aps-environment`；没有 entitlement 时跳过 APNs 注册，并输出受控日志。

这让当前 Personal Team 真机验收不再被 APNs entitlement 缺失卡死，同时保留后续付费 Apple Developer Team 开启 Push Notifications 后的正式 APNs 接入入口。

## Root Cause

真机安装包缺少 APNs 所需 entitlement：

```text
aps-environment
```

进一步验证发现：

- 当前 provisioning profile 不包含 `aps-environment`。
- Apple Personal development team 不支持 Push Notifications capability。
- 如果默认项目配置强制 `CODE_SIGN_ENTITLEMENTS` 和 Push capability，真机构建会失败，典型错误包括：
  - `Personal development teams ... do not support the Push Notifications capability.`
  - `Provisioning profile ... doesn't include the Push Notifications capability`
  - `doesn't include the aps-environment entitlement`

所以当前阶段不能把“真实 APNs 注册成功”作为 Personal Team 真机验收门槛；它必须进入单独的 paid Team / Push profile 验收门。

## Code Changes

本轮对应提交：

```text
1a65922 fix: gate APNs registration by entitlement
```

主要改动：

- 新增 `DreamJourney/DreamJourney.entitlements`
  - 声明 `aps-environment=development`
  - 作为后续付费开发者账号启用 Push Notifications 的配置入口
- 更新 `DreamJourney/Sources/AppDelegate.swift`
  - 启动时读取 app 内 embedded provisioning profile
  - 如果 profile 中没有 `aps-environment`，不再调用 `registerForRemoteNotifications()`
  - 输出受控日志：`APNs entitlement missing; skip remote notification registration`
- 新增 `tmp/visual-qa/prd-stitch-ui/apns-entitlement-readiness-check.swift`
  - 静态检查 entitlement 文件、AppDelegate gate、APNs lifecycle 回调和文档边界
- 更新真机/后端/PRD 静态 guard 和验收说明
  - 明确 APNs provider delivery 仍是独立外部验收门

## Verification

已执行并通过的检查：

```bash
swift tmp/visual-qa/prd-stitch-ui/apns-entitlement-readiness-check.swift .
swift tmp/visual-qa/prd-stitch-ui/true-device-voice-readiness-check.swift .
swift tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift .
swift tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift .
git diff --check
```

真机 preflight：

```bash
RUN_ID=20260618-apns-gated-registration-preflight-r2 \
tmp/visual-qa/prd-stitch-ui/run-true-device-voice-preflight.sh
```

结果：

- 真机 signed build 通过。
- app 可安装并启动。
- 生产语音 SDK 初始化日志仍存在。
- 旧 APNs 系统失败日志不再出现。
- 新的受控跳过日志出现。

模拟器构建验证：

```bash
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataAPNsSimulatorBuildPostCommit \
  build
```

结果：

```text
** BUILD SUCCEEDED **
```

## Evidence

真机日志证据：

```text
tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260618-apns-gated-registration-launch/console-output.log
```

关键日志：

```text
7:[PushDeviceToken] APNs entitlement missing; skip remote notification registration
40:[DialogEngine] ✅ 引擎初始化成功
```

旧失败日志检查结果：

```text
remote notification registration failed
```

在本次 gated registration 真机日志中未再出现。

模拟器构建日志：

```text
tmp/visual-qa/prd-stitch-ui/apns-entitlement-readiness/build-simulator-post-commit.log
```

## Acceptance Status

当前已接受：

- Personal Team 真机启动不会再触发 APNs entitlement 缺失导致的系统注册失败。
- app 在缺少 `aps-environment` 时进入受控降级路径。
- 当前公开 MVP 的真机启动和语音 SDK 初始化不再被 APNs 注册失败阻塞。

当前未接受：

- APNs 返回真实 device token。
- iOS 端把真实 APNs token 注册到后端。
- 后端 provider 调用 APNs 并完成 delivery。
- 真机收到远程推送通知。

这些未接受项需要以下外部条件：

- 付费 Apple Developer Team。
- App Identifier 开启 Push Notifications capability。
- 包含 `aps-environment` 的 development / distribution provisioning profile。
- provider side APNs 证书或 token 配置。
- 真机通知到达截图和日志证据。

## Follow-up

当切换到支持 Push Notifications 的 paid Team 后，建议按以下顺序验收：

1. 在 Apple Developer 后台为当前 Bundle ID 开启 Push Notifications。
2. 重新生成包含 `aps-environment` 的 provisioning profile。
3. 在 Xcode signing 配置中启用 `DreamJourney/DreamJourney.entitlements`。
4. 真机构建并确认 `registerForRemoteNotifications()` 返回 APNs device token。
5. 验证 `DreamJourneyBackendClient.registerPushDeviceToken` 写入后端。
6. 跑 delayed reply dispatch，并确认 provider delivery attempted。
7. 真机截图确认远程通知到达。

在这些条件满足前，当前发布态应维持“APNs 缺 entitlement 时受控跳过”的行为。
