# WI-S1-03-07 Echo Audio Owner G1 模拟器 UIQA

## 结论

`WI-S1-03-07` 的模拟器 G1 已通过。验证的是实际 `EchoViewController` 中的音频 owner 接线与 `AudioSessionCoordinator` 顺序，不是单独的纯模型测试。

## 执行命令

```bash
SIMULATOR_NAME='iPhone 17' \
  Scripts/QA/prd-stitch-ui/run-echo-audio-owner-coordinator-uiqa-smoke.sh
```

## 本次证据

- 执行时间：`2026-07-29 03:37`（Asia/Shanghai）
- Bundle ID：`com.yxj.dreamjourney.app`
- Simulator：`F54C960B-005F-434A-81E2-557D21AF14ED`（iPhone 17）
- 结果：`completed=true`，`transitionCount=7`，`finalOwner=none`
- 截图：[01-echo-audio-owner-coordinator-uiqa-smoke.png](/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-audio-owner-coordinator-uiqa-smoke/20260729-033726/01-echo-audio-owner-coordinator-uiqa-smoke.png)
- 结果 JSON：[echo-audio-owner-coordinator-smoke-result.json](/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-audio-owner-coordinator-uiqa-smoke/20260729-033726/echo-audio-owner-coordinator-smoke-result.json)
- 运行报告：[report.md](/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-audio-owner-coordinator-uiqa-smoke/20260729-033726/report.md)

## 断言

1. Echo capture 能取得 lease。
2. 腾讯数字人播放能抢占 capture。
3. 旧 capture 的迟到 release 不会释放腾讯播放 lease。
4. 腾讯播放结束后可恢复 capture。
5. 腾讯激活失败时，已有 capture lease 保持有效。
6. 角色切换后的旧 lease release 不会影响新 role lease。
7. 完成后 injected coordinator 无 active owner，页面显示“音频归属校验完成”。

## 边界

- 使用 simulator-only 注入 driver，不实际启动麦克风、腾讯 session、Provider、系统 `AVAudioSession` 或真实 PCM。
- 因此本记录只关闭 G1 模拟器 UIQA；真机的麦克风、蓝牙/路由、打断、真实腾讯 audio-drive、口型与恢复仍属于 G4，不能由本记录替代。
