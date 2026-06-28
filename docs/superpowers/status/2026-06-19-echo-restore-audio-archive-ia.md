# Echo 等待回信恢复与语音档案 IA

日期：2026-06-19

## 本轮目标

围绕最新 PRD 继续推进两个不依赖真机的闭环：

1. 等待回信持久化：App 重启后仍处于等待状态，本地状态能恢复，到期回信状态能落库并清理等待记录。
2. 语音档案信息架构：`语音档案` 作为档案分类入口保留，录音创建入口继续通过 feature flag / QA-only launch arg 隐藏，release 模式不误暴露。

APNs 真正送达仍然需要真机和 provider delivery 证据，本轮只覆盖模拟器可证明的本地持久化、状态恢复、local notification pending request。

## 实现内容

- `DJRunEchoDelayedReplyNotificationSmoke` 现在会额外验证：
  - 已保存的 `EchoDelayedReply` 可以被新的 `EchoViewModel` 恢复为 `waitingReply`。
  - 恢复后的剩余分钟数在本地倒计时范围内。
  - 恢复出的 `pendingDelayedReply.id` 与持久化 id 一致。
  - 到期的 delayed reply 会切到 `replied`。
  - 到期恢复后会清理 `EchoDelayedReplyStore`。
  - local notification 仍会写入 pending request，并校验 identifier、trigger、userInfo。
- 新增 `archive-audio-ia-release-check.swift`，钉住语音档案 IA：
  - `语音档案` 是档案馆分类卡片，不是录音创建按钮。
  - 空状态文案说明录音创建等待真机录音验收后开放。
  - 录音创建仍受 `archiveAudioUpload` / `DJEnableArchiveHiddenBranches` 控制。
  - 详情页保留本地音频播放结构、时长和波形结构。
  - release matrix 继续把 `录入语音` 标记为隐藏候选。
- `run-release-regression.sh` 和 `release-qa-package-check.swift` 已接入语音档案 IA guard。
- 修正 `release-like-hidden-entries-check.swift` 对当前 `makeSecondaryFeatureTiles(summary:)` 签名的陈旧匹配。

## 验证

已通过：

```bash
swift Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/archive-audio-ia-release-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/archive-feature-card-ia-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/archive-media-entries-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260619-echo-restore-persistence-audio-ia-rerun Scripts/QA/prd-stitch-ui/run-echo-delayed-reply-notification-smoke.sh
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataEchoRestoreAudioIA build
```

Echo smoke 结果：

- `completed`: `true`
- `restoredWaitingState`: `true`
- `restoredWaitingMinutes`: `4`
- `restoredWaitingMinutesInRange`: `true`
- `restoredDelayedReplyIdMatched`: `true`
- `expiredDelayedReplyArrived`: `true`
- `expiredDelayedReplyCleared`: `true`
- `pendingNotificationMatched`: `true`

证据路径：

- 结果 JSON：`tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-smoke/20260619-echo-restore-persistence-audio-ia-rerun/echo-delayed-reply-notification-smoke-result.json`
- 截图：`tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-smoke/20260619-echo-restore-persistence-audio-ia-rerun/01-echo-delayed-reply-notification-smoke.png`
- build log：`tmp/visual-qa/prd-stitch-ui/echo-restore-audio-ia-build.log`

## 已知限制

- `release-qa-package-check.swift` 当前仍依赖本地 final visual QA 截图证据；当前工作区只有 report/source manifest，没有 `app/01-login.png` 等图片，因此该整包检查会在证据文件缺失处失败。本轮没有伪造截图证据。
- APNs provider delivery 和真机通知到达仍不在本轮范围，需要真机验收。
- 语音档案录音创建仍是隐藏候选，公开 MVP 默认不暴露。

## 下一步

建议继续沿着全功能闭环推进语音档案的 hidden QA 录音链路：权限拒绝恢复、本地录音保存、音频详情播放、重新打开 App 后音频档案仍可播放。完成后再决定是否进入真机验收与公开发布评审。
