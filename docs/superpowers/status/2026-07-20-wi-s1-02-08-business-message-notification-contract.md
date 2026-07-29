# WI-S1-02-08 Business Completion、In-App Message 与 Notification Intent 合同

日期：2026-07-20

## 初始 G0 闭环

本次完成 `WI-S1-02-08` 的两个 G0 子闭环：为“业务已完成”到“应用内消息投影”再到“通知意图”建立单向、内容脱敏的合同，并补齐 hash-only DeviceSubscription 的 rotation/revoke 与通知路由围栏。

后端提交：

```text
main@a5b8331 feat(v4): separate business messages from notification intents
main@8517259 feat(v4): add device notification subscription contract
```

新增 `app/async_effects/message_notification_effects.py`，包含：

1. 只有 `businessOutcome=completed` 且 Consumer Inbox 已完成的 receipt 才可生成 `InAppMessageProjection`。
2. 消息投影只含 owner/vault/resource/version/receipt 等路由坐标；固定 `metadataOnly=true`、`contentRedacted=true`，不持久化或返回正文、语音、照片、通知标题或 Provider payload。
3. 每个消息可显式生成 `local`、`apns` 等独立 `NotificationIntent`；创建 intent 不等同于本地已调度、APNs 已受理或设备已到达。
4. `NotificationDeliveryReceipt` 以独立 append-only 观察记录 `accepted`、`failed`、`unknown`、`arrived`；它不修改 Business Completion Receipt，也不改变应用内消息的 `unread/read/archived` 状态。
5. 同一消息、channel、generation 的 intent 标识稳定；重复 channel、跨 operation receipt、未完成业务 receipt 和矛盾晚到观察均 fail-closed。

第二个 G0 子闭环新增：

1. `DeviceSubscription` 只接受已规范化的 `tokenHash`，不接受或导出原始 Device Token；订阅 ID 由 owner/vault/installation/platform 的稳定匿名坐标生成。
2. token hash 变化会进入新的 subscription generation；相同 hash 重放保持幂等，旧 generation 的通知路由会被拒绝。
3. revoke 仅撤销后续投递资格，不删除历史 subscription 身份，也不回写业务完成或应用内消息状态。
4. APNs 路由绑定同时验证 owner/vault/authority epoch、message/resource、notification generation、subscription ID 与 subscription generation；任一不一致均 fail-closed。
5. 当前模块仍不持久化订阅或投递记录，不改 `/devices/push-token` 旧注册路由，不调用 APNs，也不改 iOS 公共 UI。

## 2026-07-30 补充：跨账号收件箱身份拆分（G0 v2）

后端提交：

```text
main@76e87bb fix(v4): separate message resource and inbox identity
```

初始合同中的 `owner/vault` 坐标只足以描述“资源所有者给自己发送消息”。它不能安全描述跨账号时间信件：资源属于写信人，但消息应进入已授权家人的收件箱，且家人的设备账户 epoch 不应与资源 authority epoch 被错误地强制相等。

本次将尚未持久化的 G0 合同升级为 `business-message-notification-v2`：

1. `InAppMessageProjection` 显式分为 `resourceOwnerSubjectId/resourceVaultId` 与 `inboxSubjectId/inboxVaultId`；默认仍投递给资源所有者，跨账号必须同时提供两个 inbox 坐标。
2. 同一个业务 receipt 投递到不同收件箱时生成不同、稳定的 `messageId`，避免 Owner 与家人碰撞成同一条消息。
3. `DeviceSubscription` 改为绑定收件箱账户，而不是资源 Owner；路由分别校验资源 owner/vault/authority epoch、收件箱 subject/vault 和设备账户 epoch。
4. APNs 路由只保留 hash/digest，不含原始 subject、vault、token、正文或 Provider payload；资源授权仍需在点击后由实际读取路径重新验证。
5. 现有 `mailbox_letters`、TimeLetter/Echo 的用户可见消息、旧 `/devices/push-token` 路由及 iOS `InAppMessageCenter` 均未改动，因此不会产生第二条公开消息。

验证：

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-business-message-notification-contract-gate.sh
PYTHON_BIN=.venv/bin/python ./scripts/verify_backend.sh
git diff --check
```

结果：专用合同 gate `10` 项通过，新增跨账号 recipient route、缺失 inbox 坐标、不同 inbox 的稳定 message identity、资源/收件箱/account epoch fail-closed 覆盖；全量后端回归 `1,489` 项通过。该提交尚未推送、部署或运行 PostgreSQL smoke。

## 已验证

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-business-message-notification-contract-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- 专用合同 gate `8` 项通过，覆盖业务完成与通知状态分离、hash-only 注册、rotation/revoke、旧 generation、owner mismatch 与 notification generation mismatch。
- 与 Provider effect、Async Effect Consumer 的组合单测 `27` 项通过。
- 全量后端回归 `809` 项通过，FastAPI memory smoke、既有 Provider G0/G2 gate、知识库及备份合同 smoke 均通过。
- 本次没有数据库 migration、API route、真实 Device Token 写入、APNs 调用或本地通知调度，因此不把它记作 G1/G2/G3/G4 或真实送达证据。

## 后端基线同步

后端已推送并部署到服务器：

```text
origin/main@8517259
server /opt/services/dreamjourney/DreamJourneyBackend@8517259
```

部署过程只重建并重启 `api` 容器，未修改 `.env`、`.env.backup*` 或业务数据。`/ready` 返回 database、schema、auth、incident 均为 `ready`。生产镜像不携带 `tests/`；因此通过将服务器 checkout 的 `tests/` 以只读 volume 挂载到一次性容器，重新运行：

```bash
scripts/run-backend-business-message-notification-contract-gate.sh
```

结果为 `8` 项通过。该验证证明已部署代码可加载并满足 G0 合同；没有添加 migration、没有写入 Postgres projection，也没有调用通知 Provider。

## Gate 边界

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过 | 合同、负例、幂等标识、hash-only subscription rotation/revoke、资源与收件箱身份拆分、独立 resource/account epoch route fencing 与失败不回写业务完成已验证。 |
| G1 | 未开始 | iOS 仍消费既有本地/legacy 消息来源，尚未消费该 server projection。 |
| G2 | 未开始 | 尚未持久化 device subscription、message projection、notification intent 或 delivery receipt。 |
| G3 | 未开始 | 未注册 Device Token、未调用 APNs。 |
| G4 | 未开始 | 未做真机通知、锁屏文案或隐私人工验收。 |

## 下一 Work Item

`WI-S1-02-09` 的 G0/G2 dead-letter、replay request 与 worker-loss 证据已存在，不应重复实现。下一可执行闭环是将已有 readiness manifest 以 machine-only、value-free 方式写入现有 evidence manifest 服务；之后再进入本 Work Item 的消息投影持久化 shadow。两者都不启动真实 worker、不调用 Provider、不会启用 APNs 或公开 UI。
