# WI-S1-03-10：QA Support 音频归属抽离 G0/G1

日期：2026-07-29
Work Item：`WI-S1-03-10`
Authority lock：`IOS_COMPOSITION`

## 范围

这是 `QA Support 抽离、Progressive Strangler 与 iOS 集成门` 的首个最小切片。
仅将 Echo 音频归属模拟器 smoke 使用的注入 driver 从
`EchoViewController` 移至 `AudioOwnerLeaseQASupport`；不改变公开 Echo UI、
真实 `AVAudioSession`、麦克风、腾讯数智人、语音 Provider 或后端接口。

## 已实现

- `AudioOwnerLeaseQASupport.EchoAudioOwnerDriver` 仅在
  `UI_QA_SIMULATOR && targetEnvironment(simulator)` 编译，不能进入 Release
  artifact。
- `EchoViewController` 只消费该 QA support driver，不再定义内联 smoke driver。
- Echo 音频归属 smoke 的结果写出已直接委托给
  `QAScenarioResultWriter.writeAndLog`；`AppDelegate` 不再保留该场景的
  JSON 写出转发方法。
- 同一写出边界已覆盖连续回合、Echo trace/diagnostics/evidence 导出，以及
  Owner Truth 自然输入的 Echo surface smoke；通用
  `writeEchoQAExportSmokeResult` 已从 `AppDelegate` 删除。
- 新增 `product-v4-ios-qa-support-isolation-check.py`，守住编译隔离、调用方向和
  target 包含关系。
- 新增 `run-ios-qa-support-isolation-g0-gate.sh`，串联 isolation 检查与既有
  Echo 音频 owner lease gate。

## 验证

```bash
bash Scripts/QA/product-v4/run-ios-qa-support-isolation-g0-gate.sh
SIMULATOR_NAME='iPhone 17' \
  Scripts/QA/prd-stitch-ui/run-echo-audio-owner-coordinator-uiqa-smoke.sh
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .
git diff --check
```

结果：通过。

第二切片模拟器运行证据：

```text
tmp/visual-qa/prd-stitch-ui/echo-audio-owner-coordinator-uiqa-smoke/20260729-035253/
```

模拟器运行证据：

```text
tmp/visual-qa/prd-stitch-ui/echo-audio-owner-coordinator-uiqa-smoke/20260729-034623/
```

关键断言：

- capture acquisition、Tencent playback preemption、failed Tencent activation
  preservation、capture restore 与 stale release rejection 均为 `true`。
- 最终 `audioOwner=none`，没有遗留 injected lease。
- 截图仍是原有全屏 Echo；QA-only 状态文字为“音频归属校验完成”。
- Result JSON 仍写入同一 simulator Documents 路径，shell smoke 的消费合同不变。

## 未完成事项

- 这不是完整的 `WI-S1-03-10`。AppDelegate 的大批场景分发、其他 Echo UIQA
  seed/导出编排、旧路径计数和组合 G1 仍需分批迁移。
- 不代表真实语音、数字人、APNs 或真机 G4 已验收。
