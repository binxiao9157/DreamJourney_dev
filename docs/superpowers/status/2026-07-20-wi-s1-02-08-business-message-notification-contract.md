# WI-S1-02-08 Business Completion、In-App Message 与 Notification Intent 合同

日期：2026-07-20

## 本次子闭环

本次完成 `WI-S1-02-08` 的第一个 G0 子闭环：为“业务已完成”到“应用内消息投影”再到“通知意图”建立单向、内容脱敏的合同。

后端提交：

```text
main@a5b8331 feat(v4): separate business messages from notification intents
```

新增 `app/async_effects/message_notification_effects.py`，包含：

1. 只有 `businessOutcome=completed` 且 Consumer Inbox 已完成的 receipt 才可生成 `InAppMessageProjection`。
2. 消息投影只含 owner/vault/resource/version/receipt 等路由坐标；固定 `metadataOnly=true`、`contentRedacted=true`，不持久化或返回正文、语音、照片、通知标题或 Provider payload。
3. 每个消息可显式生成 `local`、`apns` 等独立 `NotificationIntent`；创建 intent 不等同于本地已调度、APNs 已受理或设备已到达。
4. `NotificationDeliveryReceipt` 以独立 append-only 观察记录 `accepted`、`failed`、`unknown`、`arrived`；它不修改 Business Completion Receipt，也不改变应用内消息的 `unread/read/archived` 状态。
5. 同一消息、channel、generation 的 intent 标识稳定；重复 channel、跨 operation receipt、未完成业务 receipt 和矛盾晚到观察均 fail-closed。

## 已验证

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-business-message-notification-contract-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- 新增合同测试 `5` 项通过。
- 与 Provider effect、Echo delayed reply、TimeLetter delivery 的组合单测 `31` 项通过。
- 全量后端回归 `806` 项通过，FastAPI memory smoke、既有 Provider G0/G2 gate、知识库及备份合同 smoke 均通过。
- 本次没有数据库 migration、API route、Device Token 写入、APNs 调用或本地通知调度，因此不把它记作 G2/G3/G4 或真实送达证据。

## 后端基线同步

后端已推送并部署到服务器：

```text
origin/main@a5b8331
server /opt/services/dreamjourney/DreamJourneyBackend@a5b8331
```

部署过程只重建并重启 `api` 容器，未修改 `.env`、`.env.backup*` 或业务数据。`/ready` 返回 database、schema、auth、incident 均为 `ready`。生产镜像不携带 `tests/`；因此通过将服务器 checkout 的 `tests/` 以只读 volume 挂载到一次性容器，重新运行：

```bash
scripts/run-backend-business-message-notification-contract-gate.sh
```

结果为 `5` 项通过。该验证证明已部署代码可加载并满足 G0 合同；没有添加 migration、没有写入 Postgres projection，也没有调用通知 Provider。

## Gate 边界

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 本子闭环已通过 | 合同、负例、幂等标识与失败不回写业务完成已验证。 |
| G1 | 未开始 | iOS 仍消费既有本地/legacy 消息来源，尚未消费该 server projection。 |
| G2 | 未开始 | 尚未持久化 device subscription、message projection、notification intent 或 delivery receipt。 |
| G3 | 未开始 | 未注册 Device Token、未调用 APNs。 |
| G4 | 未开始 | 未做真机通知、锁屏文案或隐私人工验收。 |

## 下一子闭环

继续 `WI-S1-02-08` 的 G0：补 `DeviceSubscription` token-hash、rotation/revoke 与 notification route 的 owner/generation fail-closed 合同；仍不接 APNs 或真实 Device Token。
