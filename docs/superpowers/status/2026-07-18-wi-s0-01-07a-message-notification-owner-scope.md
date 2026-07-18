# WI-S0-01-07A 消息与通知 Owner Scope 证据

## 1. 状态

- Work Item：`WI-S0-01-07`
- 子闭环：`WI-S0-01-07A Reply / Message / Notification owner scope`
- Authority：`ACCOUNT_LOCAL_STATE`
- 结论：07A 内部实现与 G0 可执行检查完成；`WI-S0-01-07` 仍为 `IN_PROGRESS`，下一子闭环为 Voice / TTS / Digital Human 本地状态和 lifecycle adapter。
- 外部门：G1 真实模拟器 A/B 交互、G3 恢复/回滚证据、G4 产品与安全验收仍保持开放。

## 2. 实现结果

### 2.1 应用内消息与时间信件邮箱

- System notice、Echo reply、消息本地已读/归档状态和时间信件 mailbox 均使用 `AccountLease + resourceOwnerId + operationId` 生成隔离存储键。
- 存储身份绑定 subject、vault、generation、generationId、authority epoch；session refresh 不改变 generation 时允许继续读取，同账号新 generation 和其他账号 fail closed。
- owner 不明确的 care/family/system/Echo source 不进入消息中心。
- 旧 subject-only/global payload 不自动认领，迁入 quarantine 并生成 retirement receipt。
- 时间信件 mailbox 的读改写持有同一递归锁，避免多条归档/已读回调并发覆盖。

### 2.2 消息中心页面

- 页面打开时只捕获一次 AccountLease，snapshot、已读、归档、打开详情和刷新均复用该 lease。
- snapshot provider 每次完整重建 time letter、family invitation、care signal、Echo reply 和 system notice 来源，避免页面返回时用空默认参数覆盖其他来源。
- mutation 只有持久化成功后才刷新页面；账号 generation 变化时清空页面并提示重新打开。

### 2.3 Echo 延迟回信与通知

- 延迟回信创建时生成 `EchoDelayedReplyCallsiteContext`，把原始 AccountLease、resource owner、operation 和 role context 一直传到持久化、恢复、通知、push、抵达和清理阶段。
- 异步回调不重新捕获当前账号；账号 generation、角色或 operation 变化后拒绝旧回调。
- Echo reply inbox 在同一账号 generation 内聚合最近 20 条回信，单条删除不再清空其他回信。
- 本地通知 identifier 与 `userInfo` 只保存不可逆 identity digest 和非敏感枚举，不保存 raw subject、vault、session、generation UUID、resource owner、operation 或 delayed reply ID。

## 3. 提交

- `3e77dd1 feat(WI-S0-01-07): isolate in-app message state`
- `97d6149 feat(WI-S0-01-07): preserve delayed reply scope`

## 4. 验证

- `Scripts/QA/product-v4/run-message-notification-owner-scope-gate.sh`：通过。
- Gate 覆盖 delayed reply store、Echo callsite、in-app message owner scope、AppDelegate callsite、消息页面 lease 和通知 metadata。
- `git diff --check`：通过。
- generic iOS Simulator Debug build：通过，DerivedData 为 `tmp/derived-data/wi-s0-01-07a-simulator`。
- generic iPhoneOS Debug build：通过，使用本机覆盖 `2BTR77V3R8 / com.yxj.dreamjourney.app`。
- iPhoneOS 报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260718-wi-s0-01-07a-owner-scope/report.md`。
- 构建告警来自既有第三方依赖及既有 UIKit deprecated API，本闭环没有新增编译错误。

## 5. 后续交接

下一步继续 `WI-S0-01-07B`：盘点并隔离 Voice clone profile、Memoir TTS cache、Digital Human session/runtime/prompt bridge 的本地状态，保持公开 UI 和 provider 行为不变。
