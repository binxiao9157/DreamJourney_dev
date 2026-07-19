# WI-S1-03-09 Notification / Deeplink Runtime Owner Routing

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-09`
- Authority lock：`IOS_COMPOSITION`
- 当前结果：`INTERNAL_READY / G0_OWNER_ROUTING_VERIFIED / IOS_LOCAL_COMMITTED / G1_G3_G4_OPEN`
- 本切片把本地通知、远程通知和 deeplink 统一接入一个仅内存的 owner-scoped route inbox。

本结论只证明通知/深链在本地 G0 边界不会把旧账号、错误账号、旧 generation 或篡改 owner digest
交给当前私有 UI；不证明 APNs 已送达、不证明后端资源授权已重新确认，也不代表时间信件或家庭的
跨账号内容已经可以打开。

## 实现边界

1. `NotificationRuntimeRoutePayload` 只接收 version、route action、route kind、账户/租约/owner 的单向
   digest 和 opaque operation identity；不写入 raw subject、vault、session、资源 ID 或正文。
2. `AppDelegate` 负责本地/远程通知 ingress，`SceneDelegate` 负责 cold start、URL 和 user activity ingress。
   两者只将 payload 放入 inbox，不直接进入业务页面。
3. `NotificationRuntimeRouteInbox` 在 AccountLease 的 `request`、`runtime`、`ui` checkpoint 全部通过后才
   交付 route；消费后删除，账户切换时仅清理旧 lease 的 pending route，不持久化到 `UserDefaults`。
4. `AppCoordinator` 仅在私有主界面已创建后消费 route，`TabCoordinator` 只选择中性 Tab。通知不能启动
   Echo、VoiceClone、MemoirTTS、Digital Human 或任何 audio runtime。
5. 当前 v1 router 对 `resourceOwnerIdentity` 采用“必须等于当前 subject”的严格策略。家庭、受托或跨账号
   时间信件 route 需要后端返回新的授权结果后才可扩展；当前一律 fail closed。
6. Echo 延迟回信 scheduler 的 notification metadata 增加 route schema/action，并同步既有 owner-scope
   allowlist smoke，防止 schema 演进被误判为 raw data 泄露或被静默放宽。

## G0 覆盖

- 冷启动时先入队、账户 ready 后才消费。
- 相同 opaque route 去重。
- A 账号 route 在 B 账号、旧 generation 和篡改 owner digest 下均不可交付。
- 账户生命周期 teardown 只清理旧 A route，不清理 B route。
- 完整 opaque deeplink 可走同一路由；缺字段 deeplink 被拒绝。
- 既有 delayed reply、message lifecycle 和 message owner-scope gate 保持通过。

## 验证

```bash
bash Scripts/QA/product-v4/run-notification-runtime-route-owner-gate.sh
bash Scripts/QA/product-v4/run-message-notification-widget-account-lifecycle-gate.sh
bash Scripts/QA/product-v4/run-message-notification-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-echo-delayed-reply-owner-scope-gate.sh
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
python3 Scripts/QA/product-v4/product-v4-docs-check.py
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。通用 iOS 构建存在既有第三方依赖 warning，但未由本 Work Item 引入。

## 未关闭 Gate

- G1：模拟器冷启动、多消息列表、已读/归档 UI 交互和公开 release 暴露复核。
- G3：后端 device subscription/message/deeplink capability、APNs 凭据与服务端资源 AuthZ receipt。
- G4：真实设备通知到达、锁屏隐私、错误账户点击、APNs token 轮换/撤销和产品验收。

本 Work Item 没有后端改动，因此不需要部署。

## 后续交接

下一项为 `WI-S1-03-10`：将 AppDelegate/Echo 中残留的 UIQA scenario、seed 和导出编排逐步迁到
QASupport/launch configuration，并补 layer/old-path guard。该项不得改动当前三 Tab、Stitch 全屏视觉或
将 QA bypass 带入 Release artifact。
