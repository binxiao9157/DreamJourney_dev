# 时间信件后端草稿/封存合同 smoke

日期：2026-06-19

## 目标

本轮把隐藏时间信件的本地生命周期和后端 `/archive/items` metadata 合同对齐，不改变公开 MVP 入口：

- 草稿创建：`deliveryState=draft`、`timeLetterStatus=draft`。
- 草稿编辑：同一个 `id` 再次 POST 到 `/archive/items` 时必须更新，而不是新增重复记录。
- 草稿封存：同一个 `id` 更新为 `deliveryState=sealed`、`timeLetterStatus=sealed`、`deliveryPolicy=pending_product_decision`。
- 草稿/封存删除：`DELETE /archive/items/{userId}/{itemId}` 删除对应后端记录。
- 隐私过滤：`metadata.localPath` 不进入后端回传，timeLetter 仍保持 `metadataOnly=true`。

## 后端合同

- `POST /archive/items` 对相同 `id` 执行 upsert。
- `GET /archive/items/{userId}` 返回每个 `id` 的最新一条记录。
- `DELETE /archive/items/{userId}/{itemId}` 只删除指定用户下的指定条目。
- 删除不存在的条目返回 `404 archive item not found`。

## iOS 对齐

- `DreamJourneyBackendClient.deleteArchiveItem(userId:itemId:)` 固定删除调用合同。
- `MemoryArchiveItem.archiveBackendPayload(...)` 对 `kind == .timeLetter` 显式输出：
  - `deliveryState`
  - `timeLetterStatus`
  - `deliveryPolicy`
  - `metadataOnly`
- 默认公开 MVP 仍不暴露时间信件入口；该链路只服务隐藏功能 QA 和后续全功能开发。

## 验证脚本

部署后端 smoke：

```bash
RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

单独运行：

```bash
RUN_ID=20260619-time-letter-lifecycle \
Scripts/QA/prd-stitch-ui/run-backend-time-letter-lifecycle-smoke.sh
```

静态 guard：

```bash
swift Scripts/QA/prd-stitch-ui/archive-time-letter-backend-lifecycle-check.swift \
  /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

## 暂不覆盖

- 真实投递时间规则。
- 收件人、家庭成员权限策略。
- 本地通知或 APNs 投递。
- 公开入口和正式产品文案。
