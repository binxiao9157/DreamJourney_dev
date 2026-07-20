# WI-S1-02-10 G0 TimeLetter 本地通知生命周期 Guard

日期：2026-07-20

## 完成的子切片

`WI-S1-02-10-G0-TIME_LETTER_NOTIFICATION_LIFECYCLE_GUARD`

本轮只修复已盘点出的一个本地副作用边界：旧账号 lease 失效、切换账号或退出时，
TimeLetter 待投递本地通知不应遗留到新账号运行期。它不改变时间信件的封存、打开、
服务端投递、worker、host timer、Provider 调用或公开 UI。

## 实现边界

`TimeLetterReminderScheduler` 现在：

1. 通过可注入的 `TimeLetterReminderNotificationRequestCenter` 访问 pending notification
   request，使账户生命周期行为可以用模型 smoke 验证；生产仍使用
   `UNUserNotificationCenter.current()`。
2. 为每条 TimeLetter request 保留 value-free 的 account-lease digest、resource-owner digest
   和 operation digest；identifier 也继续包含 account generation、generation ID 与 epoch。
3. 新增 `teardownForAccountLifecycle(oldAccountLease:completion:)`：仅删除同时满足
   `dj.timeLetter.reminder.`、`kind=timeLetter`、旧 lease identity 以及非空 owner/operation
   证明的 request。证据不足的 request 一律保留。
4. 删除后重新读取 pending requests；仍存在可证明属于旧 lease 的 request 时返回失败，
   不把异步清理误报为成功。
5. `AccountLifecycleRuntimeRegistry.teardownMessageNotificationEffects` 同时等待 Echo
   delayed-reply 和 TimeLetter 的清理结果；任一超时或失败都会 fail closed，保留
   `remainingLocalData=true`。

`scheduleIfNeeded` 通过注入的 runtime port 显式使用
`capture(forSubjectId: nil)`，避免将具体 runtime 类型的 convenience API 泄漏进可测接口。

## 回归检查修复

组合 gate 执行时发现两处已经提交的 QA 基线与现有生产签名不一致。本轮只修正 checker/
model smoke，未改变对应业务行为：

- Echo delayed-reply callsite checker 原本在整个 `EchoViewModel` 中禁止
  `saveArrivedReply`，误伤了“后端已返回 Answer 后”的合法 reconciliation 提交。现在只禁止
  本地 restore path 写 Inbox，并要求 server-backed path 绑定 `answerContract` 的 Answer ID
  和完成时间。
- In-app message owner-scope checker 与 model smoke 未覆盖已存在的
  `sourceAnswerID` 参数。现在检查显式 API、compatibility wrapper、非空归一化以及 owner
  inbox 中的 Answer reference 保留。

这两项让原有 owner-scope gate 能再次实际验证当前源码，而不是降低检查强度。

## 验证证据

```bash
Scripts/QA/product-v4/run-time-letter-notification-lifecycle-gate.sh
```

通过，覆盖：

- 空 old lease 失败且不删除任何 request；
- 旧 generation request 被删除；
- 同一用户的新 generation、其他用户以及缺少 ownership proof 的 request 被保留；
- 删除后第二次 pending read 验证；
- TimeLetter static check、旧 timer/callback inventory、Echo delayed-reply owner/callsite、
  in-app message owner scope、AppDelegate notification 与消息页面 lease gate。

```bash
xcodebuild -quiet -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

均通过。构建仍输出既有的 CocoaLumberjack、`contentEdgeInsets` 和一个 MainActor conversion
warning；本轮没有新增 warning。直接使用 `.xcodeproj` 构建会遗漏 CocoaPods，正确入口是
`DreamJourney.xcworkspace`。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 部分完成 | inventory 与 TimeLetter 生命周期 guard 已完成；retirement candidate manifest 仍待建立。 |
| G1 | 未运行 | 本轮没有公开 UI 或模拟器交互行为变化。 |
| G2 | 未开始 | 尚无 host/process、single-scheduler、drain、zero-use 与 old-binary 证据。 |
| G3 | 未开始 | Provider callback/query 的适用性和授权仍是外部边界。 |

## 后续子切片

`WI-S1-02-10-G0-RETIREMENT_CANDIDATE_MANIFEST`

该子切片只会把已盘点的 timer/callback 生成保守的 retirement candidate manifest，并为每个
候选显式标注所需的 zero-use、drain、host/process、old-binary 和 Provider/Operations 证据。
它不删除、停用、切换或启动任何副作用路径。
