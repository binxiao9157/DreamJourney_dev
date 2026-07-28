# WI-V0-01-09 G0/G1: Echo AudioOwner / PCM Terminal Fence

日期：2026-07-28

Work Item：`WI-V0-01-09`

## 本轮范围

本轮只收敛 Echo 数字人播放链路的请求级终止边界，不改变 Echo 全屏视觉、公开入口、
Provider 配置或真实播放方案。

此前腾讯 SDK 会分别上报 `TextOver` 与 `AudioOver`。前者仅说明文本已被 Provider
接收或处理完成，后者才是该请求音频播放结束的边界。若在 `TextOver` 就结束回合，
则会过早释放当前 AudioOwner / 恢复麦克风；若旧角色或旧回合的回调迟到，也可能影响
新的请求。

本轮实现以下 fail-closed 规则：

- `DigitalHumanSessionState.completed` 必须携带 `requestID`；
- 腾讯 `TextOver` 只记录“等待音频完成”，不结束 Echo 回合；
- 只有与当前 `currentRequestID` 精确匹配的腾讯 `AudioOver` 才依次发出
  `.completed(requestID:)` 和 `.ready`；
- 缺失、空白、旧请求或无当前请求的终止事件全部忽略并写入最小化诊断；现有超时恢复
  机制负责收敛该异常，而不是猜测归属；
- `DigitalHumanConversationCoordinator` 只有在相同 `requestID` 下才清除 provider
  request；`EchoViewController` 也只响应 request-specific completion；
- Tencent stub 与 audio-only fallback 使用同一 completed -> ready 顺序，保持非真机
  模型和生产桥接的状态合同一致。

这补上的是“不能由旧回调提前结束当前音频”的 G0 合同。既有
`AudioOwnerLease` 的 owner 互斥、停止不销毁 session、以及页面退出才释放 runtime 的
边界保持不变。

## 变更文件

- `DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntime.swift`
- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift`
- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanRuntimeStub.swift`
- `DreamJourney/Sources/Services/DigitalHuman/AudioOnlyDigitalHumanRuntime.swift`
- `DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift`
- `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- `DreamJourneyTests/AudioOwnerLeaseModelTests.swift`
- `Scripts/QA/product-v4/echo-runtime-session-coordinator-model-smoke.swift`
- `Scripts/QA/product-v4/product-v4-ios-echo-runtime-session-coordinator-check.py`
- `Scripts/QA/product-v4/run-ios-echo-runtime-session-coordinator-gate.sh`

## 验证

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
python3 Scripts/QA/product-v4/product-v4-ios-echo-runtime-session-coordinator-check.py
Scripts/QA/product-v4/run-ios-echo-runtime-session-coordinator-gate.sh
Scripts/QA/product-v4/run-ios-audio-owner-lease-gate.sh
git diff --check
```

结果：全部通过。

- runtime-session 静态 gate 钉住 request-specific completion、`TextOver` / `AudioOver`
  分离、回合匹配清理及现有 session/interaction callback fence；
- 模拟器 XCTest `TencentDigitalHumanCloudRuntimeTests` 用 fake Tencent bridge 覆盖
  `TextOver`、缺失/错配 `AudioOver`、角色切换后的旧 `AudioOver`、以及停止后的迟到
  `AudioOver`；只有当前 request 的 `AudioOver` 能发出一次 `.completed(requestID:)`；
- 已运行 `run-echo-audio-owner-coordinator-uiqa-smoke.sh`，以注入式音频 driver 覆盖
  capture -> Tencent playback preempt -> stale release ignored -> capture recovery；
- runtime-session gate 和 audio-owner lease gate 均完成通用 `iPhoneOS`
  `build-for-testing`；
- 本轮未运行腾讯真实 Provider、火山合成或真机。

## 未关闭 Gate

- `G1`：本轮请求终止和 AudioOwner 交互回归已在模拟器确认；真实 SDK callback
  时序、PCM/timeline 实际播放仍属于 G3/G4，不能用 fake bridge 替代；
- `G3`：没有腾讯真实 `AudioOver`、火山复刻 PCM、Provider receipt、配额或成本证据；
- `G4`：没有真机扬声器/听筒/蓝牙、打断、系统中断、前后台、连续对话、麦克风恢复及
  产品听感验收。

因此本项状态为 `INTERNAL_READY / SCOPED_G0_G1`。它不表示真实腾讯数字人有声、口型同步、
复刻音色已生效，不能据此公开 Voice 或 Digital Human 能力。
