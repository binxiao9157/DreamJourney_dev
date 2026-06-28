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
- 后端合同：通过 `/archive/items` 持久化 `openAt`、`recipients`、`sealedAt`、`deliveryStatus`。

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
  - 通过 `dueTimeLetters()` 输出应用内提醒数据源。
- `MemoryArchiveViewController`：
  - 有到期信件时显示应用内提醒入口。
  - 点击提醒入口筛选到“时间信件”列表。
- `MemoryArchiveDetailViewController`：
  - 草稿可编辑、封存、删除。
  - 封存后只展示锁定状态，不能删除或修改。
  - 有图片附件时展示图片预览。
- 后端：
  - `/archive/items` 接收并回传时间信件字段。
  - `DELETE /archive/items/{userId}/{itemId}` 对 sealed timeLetter 返回 409。

## 验证入口

```bash
swift Scripts/QA/prd-stitch-ui/time-letter-delivery-policy-shell-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

```bash
RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 部署状态

- 本地后端单测已覆盖 sealed timeLetter 删除返回 409。
- 2026-06-21 部署后端 smoke `20260621-time-letter-public-delivery-backend` 暴露服务器仍返回 200 删除 sealed timeLetter，说明线上尚未部署本轮后端删除保护。
- 后端部署后需重跑：

```bash
RUN_ID=20260621-time-letter-public-delivery-backend \
Scripts/QA/prd-stitch-ui/run-backend-time-letter-lifecycle-smoke.sh
```

## 待后续验收

- APNs/provider 级远程推送送达证据。
- 真机通知权限、前后台、锁屏提醒实测截图和日志。
- 收件人端跨账号提醒读取和消息中心聚合策略。
