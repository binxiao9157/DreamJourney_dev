# 回响等待回信本地通知 Pending Request Smoke

日期：2026-06-19

## 范围

强化 `DJRunEchoDelayedReplyNotificationSmoke`：

- 不再只验证 delayed reply 持久化和 notification 常量。
- 实际调用 `EchoDelayedReplyNotificationScheduler.shared.schedule`。
- 通过 `UNUserNotificationCenter.current().getPendingNotificationRequests` 查询系统 pending request。
- 校验 pending request 的 identifier、trigger 和 userInfo。

本轮仍不覆盖 APNs provider delivery，也不代表真机通知到达验收。

## 实现说明

模拟器 smoke 使用 provisional notification authorization，避免自动化流程卡在系统授权弹窗上。生产路径仍保留 `EchoDelayedReplyNotificationScheduler.requestAuthorizationIfNeeded` 的原有授权逻辑。

结果 JSON 新增字段：

- `pendingNotificationScheduleSucceeded`
- `pendingNotificationMatched`
- `pendingNotificationIdentifierMatched`
- `pendingNotificationTriggerMatched`
- `pendingNotificationUserInfoMatched`
- `pendingNotificationCount`

## 验证

红灯检查先失败在 AppDelegate 未实际 schedule/query pending request：

```bash
swift tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-check.swift .
```

修复后通过：

```bash
swift tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-check.swift .
```

模拟器 smoke 通过：

```bash
RUN_ID=20260619-echo-pending-notification-query-rerun DERIVED_DATA_PATH=tmp/visual-qa/prd-stitch-ui/DerivedDataEchoPendingNotificationSmokeRerun tmp/visual-qa/prd-stitch-ui/run-echo-delayed-reply-notification-smoke.sh
```

关键结果：

```json
{
  "completed": true,
  "pendingNotificationCount": 1,
  "pendingNotificationIdentifierMatched": true,
  "pendingNotificationTriggerMatched": true,
  "pendingNotificationUserInfoMatched": true
}
```

证据：

- 结果：`tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-smoke/20260619-echo-pending-notification-query-rerun/echo-delayed-reply-notification-smoke-result.json`
- 截图：`tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-smoke/20260619-echo-pending-notification-query-rerun/01-echo-delayed-reply-notification-smoke.png`
