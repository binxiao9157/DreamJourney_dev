# 时间信件公开投递闭环

日期：2026-06-21

## 产品边界

- 创建入口：用户自己的记忆档案馆，通过“封存新记忆 -> 时间信件”创建。
- 支持内容：文字 + 图片。
- 暂不支持内容：视频、音频。
- 打开时间：用户创建或编辑草稿时设置 `openAt`。
- 收件人：可选择本人和家庭亲友中的一位或多位，保存为 `recipients`。
- 封存规则：封存后不可删除、不可修改。
- 提醒规则：到达打开时间后，生成本地通知和应用内提醒入口。
- 后端合同：通过 `/archive/items` 持久化 `openAt`、`recipients`、`sealedAt`、`deliveryStatus`；通过 `/archive/time-letters/dispatch-due` 扫描到期信件并写入 `/mailbox/letters/{userId}` 应用内提醒。

## 当前实现

- `DJFeature.timeLetters` 已进入默认公开 feature set，schema version 升级到 6。
- `MemoryArchiveTextEntryViewController` 提供时间信件创建/编辑 UI：
  - 正文输入
  - 打开时间选择
  - 收件人选择
  - 单张图片选择
  - 草稿保存
  - 封存
- `MemoryArchiveItem` 固定 metadata 合同：
  - `openAt`
  - `recipientIds`
  - `recipientNames`
  - `sealedAt`
  - `deliveryStatus`
  - `deliveryNotificationScheduled`
- `MemoryArchiveRepository`：
  - 封存 timeLetter 本地禁止删除。
  - 封存后调度 `UNNotificationRequest`。
  - 通过 `dueTimeLetters()` 输出尚未投递的本地到期提醒。
  - 通过 `refreshTimeLetterMailboxReminders()` 触发后端 `dispatch-due`，再拉取 mailbox unread reminder。
  - `timeLetterReminderCount()` 合并本地 due 与后端 mailbox，避免 delivered 信件重复提醒。
  - 通过 `inAppMessageCenterSnapshot()` 将 mailbox reminder 聚合为统一 `InAppMessage`。
  - 通过 `markTimeLetterMailboxReminderRead()` 将打开过的 mailbox reminder 标记为已读。
  - 通过 `markTimeLetterMailboxReminderArchived()` 将处理过的 mailbox reminder 归档收起。
- `MemoryArchiveViewController`：
  - 有到期信件时显示应用内提醒入口。
  - 点击提醒入口进入“消息中心”列表，当前真实来源为时间信件提醒。
  - 消息中心分为“收件箱”和“已归档”，支持滑动归档和一键归档已读提醒。
- `MemoryArchiveDetailViewController`：
  - 草稿可编辑、封存、删除。
  - 封存后只展示锁定状态，不能删除或修改。
  - 有图片附件时展示图片预览。
- 后端：
  - `/archive/items` 接收并回传时间信件字段。
  - `DELETE /archive/items/{userId}/{itemId}` 对 sealed timeLetter 返回 409。
  - `POST /archive/time-letters/dispatch-due` 幂等扫描 due sealed timeLetter，将 `deliveryStatus` / `deliveryExecutionState` 更新为 `delivered`。
  - dispatch 只为本人和已接受的家庭收件人创建 `timeLetterReminder` mailbox 记录。
  - 未到 `openAt` 的 timeLetter 不会写入收件人 mailbox。
  - mailbox reminder 只包含元数据，`metadataOnly=true`、`contentRedacted=true`，不暴露信件正文。
  - `POST /mailbox/letters/{userId}/{letterId}/read` 将单封应用内提醒标记为已读，并保持幂等。
  - `POST /mailbox/letters/{userId}/{letterId}/archive` 将单封应用内提醒标记为已归档，并保持幂等。

## 2026-07-02 服务端到期投递更新

- 新增后端 due dispatch 合同：
  - `POST /archive/time-letters/dispatch-due`
  - 请求：`now`、`limit`
  - 响应：`status=dispatched`、`itemCount`、`reminderCount`、`items`、`reminders`
- 幂等策略：
  - 只扫描 `deliveryStatus=scheduled` 的 sealed timeLetter。
  - 已投递后状态变为 `delivered`，重复扫描 `itemCount=0`、`reminderCount=0`。
- 应用内提醒策略：
  - owner 收到 `recipientRole=owner` 的 mailbox reminder。
  - accepted family recipient 收到 `recipientRole=recipient` 的 mailbox reminder。
  - pending/failed/revoked family recipient 不创建提醒。
- iOS 状态策略：
  - `delivered` 优先于本地 `openAt <= now` 的 `ready` 推导。
  - delivered timeLetter 不再重复进入本地 due notification/data source。
  - Archive 页提醒入口以 `timeLetterReminderCount()` 合并本地 due 和 mailbox unread。

## 2026-07-02 应用内提醒中心更新

- Archive 页顶部提醒入口不再只打开单条提醒或简单筛选列表。
- 新增“消息中心”二级列表：
  - 未读提醒优先展示。
  - 支持多封已到达时间的信件。
  - 每封提醒展示标题、收件角色、送达时间、未读/已读状态。
  - 点按单封提醒后打开对应时间信件详情。
- 已读策略：
  - 成功打开详情后，本地缓存立即标记已读。
  - 后端配置可用时同步调用 `POST /mailbox/letters/{userId}/{letterId}/read`。
  - 只标记当前打开的提醒，不影响其它未读信件。
- 归档策略：
  - 用户可在提醒中心滑动归档单封提醒。
  - 用户可一键归档全部已读提醒。
  - 已归档提醒仍保留在提醒中心历史分组，不再进入未读计数。
  - 后端配置可用时同步调用 `POST /mailbox/letters/{userId}/{letterId}/archive`。
- QA 覆盖：
  - iOS reminder smoke 构造两封 mailbox reminder，打开并归档一封后断言另一封仍未读，未读数保持 1。
  - 后端 lifecycle smoke 覆盖 read/archive endpoint，确认 Postgres/部署环境下 mailbox 状态回传为 `read` / `archived`。

## 2026-07-02 统一 InAppMessage 聚合壳层

- 新增 `InAppMessageCenter.swift`：
  - `InAppMessageKind` 固定 `timeLetter`、`familyInvitation`、`careSignal`、`systemNotice` 四类。
  - `InAppMessageStatus` 固定 `unread`、`read`、`archived` 三态。
  - `InAppMessageCenterSnapshot` 输出收件箱、已归档、未读数、类型计数。
- 当前公开真实来源：
  - `timeLetterReminder` mailbox 记录映射为 `InAppMessage.kind=timeLetter`。
  - 保留 `metadataOnly=true`、`contentRedacted=true`，提醒列表不暴露正文。
- 暂不公开来源：
  - `systemNotice` 只保留 hidden candidate / routing guard。
  - 默认 release 不生成系统消息，不改变系统通知现有入口。
- QA 覆盖：
  - 新增 `in-app-message-center-shell-check.swift`，接入 release regression 静态 guard。
  - `run-time-letter-dispatch-reminder-smoke.sh` 额外验证 `inAppMessageCenterKindCounts.timeLetter=2`、未读数和归档数。

## 2026-07-02 家庭邀请接入 InAppMessage

- 真实 provider：
  - `FamilyMember` 实现 `FamilyInvitationMessageSource`。
  - `MemoryArchiveRepository.inAppMessageCenterSnapshot(familyInvitationSources:)` 合并家庭邀请消息。
- 入消息中心规则：
  - `invitationStatus=pending` 或 `accessStatus=pending`：进入消息中心，显示“等待对方加入”。
  - `invitationStatus=failed` 或 `accessStatus=failed`：进入消息中心，显示失败原因。
  - `invitationStatus=accepted` 且 `accessStatus=active`：不进入消息中心，避免已加入家人造成提醒噪音。
- 状态策略：
  - 家庭邀请消息使用本地 `InAppMessage` read/archive 缓存。
  - 时间信件仍以后端 mailbox read/archive 状态为准。
- 点击策略：
  - 点击家庭邀请消息后进入家人管理上下文。
  - 如果本地能解析到对应 `FamilyMember`，直接打开家人详情；否则回到 `FamilyCircleViewController`。
- QA 覆盖：
  - `in-app-message-center-shell-check.swift` 验证 `FamilyInvitationMessageSource`、`fromFamilyInvitation`、`familyInvitationMessages`、`openFamilyInvitationMessage`。
  - `run-time-letter-dispatch-reminder-smoke.sh` 构造 pending / failed / accepted 三种家庭状态，断言 pending + failed 计数为 2，accepted 不进入消息中心。

## 2026-07-02 关怀提醒接入 InAppMessage

- 真实 provider：
  - `ProfileCareSignalMessageStore` 复用“我的/心境追踪”已加载的 `ProfileCareSnapshot`。
  - `MemoryArchiveRepository.inAppMessageCenterSnapshot(careSignalSources:)` 合并关怀提醒消息。
- 入消息中心规则：
  - `failed`：进入消息中心，标题为“关怀信号加载失败”。
  - `stale` / `expired`：进入消息中心，标题为“关怀信号可能过期”。
  - `needsAttention` / `attention` / `watch`：进入消息中心，标题为“心境状态需要关注”。
  - `available + normal`、`loading`、`empty`：不进入消息中心，避免正常状态造成提醒噪音。
- 状态策略：
  - 关怀提醒消息使用本地 `InAppMessage` read/archive 缓存。
  - 关怀数据本身仍由 Profile 关怀快照和后端 `/care/snapshot/latest` 合同提供。
- 点击策略：
  - 点击关怀提醒消息后标记已读，并切换到“我的/关怀”上下文。
  - 不新增公开首页入口，不改变关怀页当前视觉和交互。
- QA 覆盖：
  - `in-app-message-center-shell-check.swift` 验证 `CareSignalMessageSource`、`fromCareSignal`、`careSignalMessages`、`openCareSignalMessage`。
  - `run-time-letter-dispatch-reminder-smoke.sh` 构造 failed / stale / needsAttention / normal 四种关怀状态，断言前三类计数为 3，normal 不进入消息中心。

## 2026-07-02 统一消息中心入口 badge

- Archive 页入口从“时间信件提醒”语义升级为统一“消息中心”入口。
- 入口 accessibility id 固定为 `archive-in-app-message-center`。
- 入口文案由 `InAppMessageCenterSnapshot.entryButtonTitle(timeLetterReminderCount:)` 统一生成：
  - 有任意未读消息时，展示跨类型未读总数，例如 `8 条消息待处理 · 查看`。
  - 只有本地到期时间信件时，仍保留 `N 封时间信件已到打开时间 · 查看` 的兜底。
  - 只有历史消息时，展示已归档或历史入口。
- QA 覆盖：
  - `in-app-message-center-shell-check.swift` 验证入口标题由 snapshot 统一生成。
  - `run-time-letter-dispatch-reminder-smoke.sh` 验证 timeLetter + familyInvitation + careSignal + systemNotice 共 8 条未读时，入口文案为 `8 条消息待处理 · 查看`。

## 2026-07-02 系统通知接入 InAppMessage

- 最小 provider：
  - 新增 `SystemNoticeMessageSource` 和本地 `SystemNoticeMessageStore`。
  - 默认 release 不预置系统通知；只有业务侧写入 `published` / `active` 状态的通知时才进入消息中心。
- 入消息中心规则：
  - `systemNoticeStatus=published` 或 `active`：进入消息中心。
  - `draft` / `disabled` / 其它未发布状态：不进入消息中心。
- 点击策略：
  - 点击系统通知后标记已读，并用最小弹窗展示标题和摘要。
  - 不新增系统通知详情页，不引入后端公告合同。
- QA 覆盖：
  - `in-app-message-center-shell-check.swift` 验证 `SystemNoticeMessageSource`、`fromSystemNotice`、`systemNoticeMessages`、`openSystemNoticeMessage`。
  - `run-time-letter-dispatch-reminder-smoke.sh` 构造 published + draft 两类系统通知，断言 published 计数为 1，draft 不进入消息中心。

## 验证入口

```bash
swift Scripts/QA/prd-stitch-ui/time-letter-delivery-policy-shell-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

```bash
swift Scripts/QA/prd-stitch-ui/in-app-message-center-shell-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

```bash
RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

```bash
RUN_TIME_LETTER_DISPATCH_REMINDER_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 部署状态

- 本地后端单测已覆盖 sealed timeLetter 删除返回 409。
- 2026-07-02 新增 due dispatch / mailbox reminder 合同，后端部署后需重跑：

```bash
RUN_ID=20260702-time-letter-dispatch-mailbox \
Scripts/QA/prd-stitch-ui/run-backend-time-letter-lifecycle-smoke.sh
```

## 待后续验收

- APNs/provider 级远程推送送达证据。
- 真机通知权限、前后台、锁屏提醒实测截图和日志。
- 将系统通知接入 `InAppMessage` 的真实 provider 和后端合同。
