# WI-S1-03-07 AudioOwnerLease

日期：2026-07-23

## 当前状态

- Work Item：`WI-S1-03-07`
- Authority lock：`IOS_COMPOSITION`
- 当前结果：`INTERNAL_READY / G0_ECHO_AUDIO_SESSION_COORDINATOR_ENFORCEMENT_VERIFIED / G1_G4_OPEN`
- 本次完成切片：`WI-S1-03-07-G0-A-ECHO_AUDIO_SESSION_COORDINATOR_ENFORCEMENT`
- 范围：只迁移 Echo capture、普通 Echo 本地 TTS、腾讯数智人播放；不改变 Echo 全屏 UI、Provider 路由、声音复刻产品策略或公开发布范围；Archive、Profile、Memoir 继续保留既有直接路径。

## 已实现

- 保留既有纯 `AudioOwnerLeaseModel`：lease 显式记录 owner、purpose、route、account/runtime generation、priority、state 与 issuedAt；旧 generation、旧 lease、旧 interruption/resume 都不能改写较新的 owner。
- 新增可注入 `AudioSessionCoordinator` 与 `AudioSessionDriving`。iOS 真正的 `AVAudioSession` 读写只留在 `SystemAudioSessionDriver`；命令行 smoke 和单元测试使用 fake driver，不触碰系统音频会话。
- coordinator 只在 driver 成功激活后提交模型状态。腾讯播放抢占 Echo capture 失败时会尝试恢复旧 capture driver 状态，并保留旧 lease；停用失败时也不会清空当前 owner。
- Echo 不再直接调用 `AVAudioSession.setCategory` / `setActive`。capture、普通本地 TTS、腾讯播放分别经 coordinator acquire/preempt/release；腾讯播放激活失败会明确降级，而不会继续发送 provider 音频。
- Echo 在启动 DialogEngine 前必须取得并传递精确 active lease。`DialogEngineManager` 检测到该 lease 后只复用它，不再第二次直接配置或恢复会话；它对非 Echo 调用仍保留原有直接路径，避免扩大迁移范围。
- interruption、resume、route-change、角色切换、fallback、后台释放和页面退出都继续使用精确 lease token；迟到旧回调不会释放或恢复新 owner。
- 直接 `AVAudioSession` inventory 仍为 7 个文件，但从 `EchoViewController` 转移到 `AudioOwnerLeaseCoordinator`。其余 6 个非 Echo 写入点未在本切片迁移。

## 验证

执行：

```bash
python3 Scripts/QA/product-v4/product-v4-ios-audio-owner-lease-check.py
bash Scripts/QA/product-v4/run-ios-audio-owner-lease-gate.sh
git diff --check
```

结果：`PASS`。

- 静态 gate 验证纯模型未依赖音频框架、Echo 不再直接配置 `AVAudioSession`、DialogEngine 的受管 lease guard 存在，并钉住 7 个直接 configurator 的清单。
- fake-driver smoke 与 XCTest 编译覆盖：腾讯播放抢占 capture、旧 capture release 不可停掉腾讯、腾讯激活失败回滚旧 capture、当前 interrupted lease 才能 resume、deactivate 失败保留 owner。
- `Debug`、`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功，输出为 `TEST BUILD SUCCEEDED`。
- `git diff --check` 通过。

本次只证明 G0 的代码合同和通用 iOS 构建。没有运行模拟器交互或真机，因此不能声明蓝牙、听筒/扬声器、打断、无声、口型、前后台或麦克风恢复已经验收。

## 仍然开放的 Gate

- G1：需要模拟器 UIQA 覆盖 Echo capture -> 腾讯播放 -> capture 恢复、失败 fallback 和角色切换。
- G4：需要真机连续对话、打断、路由变化、蓝牙、后台恢复以及腾讯数智人/复刻声音实际听感证据。
- 非 Echo 音频模块的统一迁移不属于本 Work Item，后续必须独立选择和验证。

## 暂停点

本轮按用户要求在 `G0-A` 提交后暂停。恢复后先决定是否补 G1 UIQA 或转入另一个计划内 Work Item；不得把本证据自动提升为 G4。
