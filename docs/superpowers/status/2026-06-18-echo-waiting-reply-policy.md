# 回响等待回信策略

日期：2026-06-18

分支：`feature/prd-stitch-ui-adaptation`

## 目标

根据最新 PRD 决策更新公开 MVP 中“回响等待回信”的默认实现，保持 Echo 语音优先和现有 Stitch 对齐视觉，不开放文字/图片输入，也不切换到新的 Stitch Echo 变体。

## 当前实现

- `EchoInteractionState` 增加 `thinking` 和 `replied` 状态。
- `EchoReplyPacingPolicy` 集中管理等待策略。
- 最新 PRD 决策：用户发言 + AI 回复算 1 轮。
- 当前默认策略：第 10 次用户最终语音后进入 `waitingReply(minutes:)`，作为 10 轮基线策略。
- 情绪/内容存在问题时，可通过 `shouldTriggerEarlyWait(for:)` 提前进入等待回信。
- 等待时长约束为 5-10 分钟。
- 进入等待回信后，停止当前语音引擎回调并保留等待 UI，不继续播即时回复。
- `resetToIdle()` 会清空本轮语音会话计数。

## UI 状态

| 状态 | 文案 | 行为 |
| --- | --- | --- |
| idle | 不显示状态胶囊 | 麦克风可点击 |
| listening | `我在听，您慢慢说` | 麦克风可停止 |
| thinking | `我在想一想` | 麦克风暂不可点 |
| speaking | `回响正在抵达` | 播报中 |
| replied | `回信已抵达` | 播报完成后的短暂停留 |
| waitingReply | `先去窗边走走，约 5 分钟后我再回信` | 麦克风不可点 |
| error | 错误文案 | 麦克风可重新开始 |

## 产品边界

这次更新吃进了最新 PRD 决策：

- 用户发言AI回复算1轮。
- 默认修改为10轮，情绪/内容存在问题可提前触发。
- 等待时长5-10分钟随机。
- 等待文案往走出去方向引导，一句即可。
- 推送通知和本地通知和app内状态都需要。
- 属于公开MVP。

仍需工程继续补齐：

- 本地通知调度与权限策略。
- 推送通知后端/APNs 合同。
- 真机麦克风与通知验收。

## 验证

新增检查：

```bash
swift tmp/visual-qa/prd-stitch-ui/echo-waiting-reply-policy-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

本轮模拟器截图：

```text
tmp/visual-qa/prd-stitch-ui/prd-decision-echo-policy/20260618-current/01-echo-waiting-reply-ten-round.png
```

release regression 需要覆盖该检查：

```bash
RUN_ID=20260618-prd-decision-echo-policy tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```
