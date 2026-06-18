# 回响等待回信策略

日期：2026-06-18

分支：`feature/prd-stitch-ui-adaptation`

## 目标

补齐公开 MVP 中“回响 2-3 轮后等待回信”的默认实现，保持 Echo 语音优先和现有 Stitch 对齐视觉，不开放文字/图片输入，也不切换到新的 Stitch Echo 变体。

## 当前实现

- `EchoInteractionState` 增加 `thinking` 和 `replied` 状态。
- `EchoReplyPacingPolicy` 集中管理等待策略。
- 当前默认策略：第 3 次用户最终语音后进入 `waitingReply(minutes:)`。
- 前两次用户最终语音后进入 `thinking`，等待 AI 回复。
- 第 3 次进入等待回信后，停止当前语音引擎回调并保留等待 UI，不继续播即时回复。
- `resetToIdle()` 会清空本轮语音会话计数。

## UI 状态

| 状态 | 文案 | 行为 |
| --- | --- | --- |
| idle | 不显示状态胶囊 | 麦克风可点击 |
| listening | `我在听，您慢慢说` | 麦克风可停止 |
| thinking | `我在想一想` | 麦克风暂不可点 |
| speaking | `回响正在抵达` | 播报中 |
| replied | `回信已抵达` | 播报完成后的短暂停留 |
| waitingReply | `约 5 分钟后再听` | 麦克风不可点 |
| error | 错误文案 | 麦克风可重新开始 |

## 产品边界

这次实现的是默认工程策略，不代表 PRD 最终决策已经完全关闭。仍需产品确认：

- “2-3 轮”的长期定义是否就是用户最终语音轮次。
- 是否保持固定第 3 轮触发，还是后续按情绪/内容自适应。
- 等待回信是否需要本地通知或推送通知。
- 等待时长是否继续按当前 5/10/30 分钟轮换。

## 验证

新增检查：

```bash
swift tmp/visual-qa/prd-stitch-ui/echo-waiting-reply-policy-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

本轮模拟器截图：

```text
tmp/visual-qa/prd-stitch-ui/echo-waiting-reply-policy/20260618-current/01-echo-waiting-reply-third-turn.jpg
```

release regression 需要覆盖该检查：

```bash
RUN_ID=20260618-echo-waiting-reply-policy tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```
