# WI-S1-03-07 G1：Echo 音频归属模拟器 UIQA

日期：2026-07-28
Work Item：`WI-S1-03-07`
范围：`IOS_COMPOSITION`，仅 Echo 音频归属运行时边界。

## 本轮完成

在保留生产默认 `AudioSessionCoordinator.shared` 的前提下，为 Echo 加入 QA-only 的可注入 coordinator 路径。新的模拟器启动参数：

```text
DJRunEchoAudioOwnerCoordinatorSmoke
```

该路径使用假 `AudioSessionDriving`，不会打开麦克风、不会配置真实 `AVAudioSession`、不会创建腾讯数智人会话，也不会改公开 Echo 视觉或 Provider 路由。

## 覆盖的 G1 场景

1. Echo 采集获得 lease。
2. 腾讯数智人播放以更高优先级抢占采集。
3. 旧采集 lease 的迟到 release 不会清掉腾讯播放 lease。
4. 腾讯播放结束后可重新获得采集 lease。
5. 腾讯播放 activation 失败时，原采集 lease 保持有效。
6. 角色/运行时 generation 切换后，旧角色 lease 的 release 不会清掉新角色 lease。
7. 结束后假 coordinator 无活动 owner，避免把测试状态带回普通 Echo。

## 一键验证

```bash
bash Scripts/QA/prd-stitch-ui/run-echo-audio-owner-coordinator-uiqa-smoke.sh
```

可选接入 release regression：

```bash
RUN_ECHO_AUDIO_OWNER_COORDINATOR_UIQA_SMOKE=1 \
  bash Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

本次结果：

- `captureAcquired=true`
- `tencentPreemptedCapture=true`
- `staleCaptureReleaseIgnored=true`
- `captureRestored=true`
- `tencentFailurePreservedCapture=true`
- `staleRoleReleaseIgnored=true`
- `finalOwner=none`
- `transitionCount=7`

模拟器证据目录：

```text
tmp/visual-qa/prd-stitch-ui/echo-audio-owner-coordinator-uiqa-smoke/20260728-095420/
```

其中包含 `build.log`、运行日志、JSON 结果和截图 `01-echo-audio-owner-coordinator-uiqa-smoke.png`。

## Gate 结论

`G1 = SCOPED_VERIFIED`：已证明 Echo controller 与 runtime coordinator 的模拟器集成顺序，不等同于物理设备音频验收。

仍未关闭：

- `G4` 真机中断、蓝牙路由、麦克风恢复、腾讯实际播放/打断和配额 fallback。
- 腾讯数智人及声音复刻 provider 的真实网络、音频和口型效果。

因此本轮不声明真机完成、不改变公开发布态，也不触发后端部署。
