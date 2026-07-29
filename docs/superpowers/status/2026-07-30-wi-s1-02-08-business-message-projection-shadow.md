# WI-S1-02-08 跨账号业务消息影子持久化

日期：2026-07-30

## 本轮范围

本轮在既有 `business-message-notification-v2` 合同之上，新增一个仅内部使用、默认不接业务写入或公开读取的 durable projection shadow。目标是先固定“资源归属”和“收件箱归属”分离后的持久化边界，不提前把跨账号消息暴露到现有消息中心。

后端提交：

```text
main@6d6a7b8 feat(v4): add business message projection shadow
```

新增内容：

1. `async_effects.business_message_projections` 只保存 metadata-only 的 `InAppMessageProjection` 路由坐标、状态、receipt 关联与 projection hash；不保存正文、照片、语音、通知标题、设备 token 或 Provider payload。
2. `InboxAccountSnapshot` 要求调用方显式提供 `inboxSubjectId`、`inboxVaultId`、`accountEpoch` 与 `accessState=active`。本轮不从家庭关系、手机号或 subject 反推 vault，也不把任何关系直接视为授权。
3. Python repository 在写入前重读 `business_receipts`，校验 operation、资源 owner/vault/type/id/version、authority epoch、business target、purpose 和 `completed` 终态；重复同一 receipt、消息种类和收件箱时只幂等返回，不重写状态。
4. 数据库 migration `0059` 增加 `BEFORE INSERT` receipt-coordinate trigger 与 append-only update/delete trigger。直接数据库写入也不能伪造或错配资源坐标。
5. 新增 disposable PostgreSQL smoke，覆盖自收件箱、显式家庭收件箱、重复幂等、account epoch 改变、receipt 坐标漂移、直接错配写入和 append-only 围栏。

## 明确未做

- 不写入、不替换、不读取既有公开 `mailbox_letters`。
- 不接 Time Letter、Echo delayed reply、家庭邀请或关怀提醒的真实业务 writer。
- 不新增 API route、iOS UI、公开消息中心 reader、APNs、本地通知、worker 或 Provider 调用。
- 不实现跨账号 `subject -> vault` 解析器、access grant 判定或家庭关系授权推断。
- 不声称 PostgreSQL、部署、线上 smoke、真实设备通知或跨账号可见性已经验证。

## 验证

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-business-message-projection-contract-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- 专用 projection gate `16` 项通过。
- 全量 `scripts/verify_backend.sh` 通过，包含既有业务消息、Time Letter、Echo、异步 effect、Provider 和 FastAPI smoke 回归。
- `backend-business-message-projection-postgres-smoke.py` 已实现，但本机 `DATABASE_URL` 未配置，未运行 disposable PostgreSQL G2 smoke。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过（本地） | 显式 inbox snapshot、receipt 重校验、独立 resource/inbox 坐标、幂等与直接 DB fail-closed trigger 已验证。 |
| G2A | 已通过（本地影子实现） | 迁移、repository、disposable Postgres smoke 工具已就绪；尚未实际运行 PostgreSQL。 |
| G1 | 未开始 | iOS 和公开消息中心没有消费本影子投影。 |
| G2 | 未验证 | 未部署 migration，未执行 disposable PostgreSQL smoke。 |
| G3/G4 | 未开始 | 没有 APNs、本地通知或真机证据。 |

## 后续前提

在任何 Time Letter/Echo/家庭业务 writer 接入前，需要单独实现并验证：

1. 可审计、fail-closed 的 inbox account/vault resolver；
2. 对应 resource 的真实 access grant / recipient eligibility 证明；
3. 已部署 migration 的 disposable PostgreSQL smoke；
4. 仅在上述条件满足后，才讨论内部 reader、业务 writer 和公开消息中心接入。
