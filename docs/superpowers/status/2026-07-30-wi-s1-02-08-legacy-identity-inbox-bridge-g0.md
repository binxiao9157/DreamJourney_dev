# WI-S1-02-08 Legacy Identity Inbox Bridge（G0）

日期：2026-07-30

## 本轮范围

跨账号业务消息需要区分“资源归属”和“收件箱账户归属”。此前的 durable projection shadow 已要求调用方显式给出收件箱坐标，但尚没有一条可审计的 `legacy users.id -> verified Subject -> Vault` 桥接链路。本轮只补齐这条内部解析前提，不把它当作资源授权，也不将任何跨账号消息接入公开消息中心。

后端提交：

```text
main@5f90da0 feat(v4): add legacy identity inbox bridge
```

## 新增内部合同

1. migration `0060_legacy_identity_inbox_bridge` 新增 additive、默认关闭的 `legacy_identity_aliases` 表。它只保存 legacy account、alias hash、Subject、Vault、身份凭证和 claim 状态之间的受约束坐标；没有 backfill `INSERT`，也没有启用 release flag。
2. 只有 `verified` alias、匹配的 identity proof、active Subject、active Vault、匹配的 Vault owner，以及 active legacy account lifecycle 同时成立时，`PostgresLegacyInboxAccountResolver` 才返回内部 `InboxAccountSnapshot`。
3. `claim_pending`、身份凭证错配、Subject/Vault 非 active、账户 soft-delete/suspend、epoch 缺失或 Vault owner 错配均 fail-closed。
4. 数据库 trigger 要求已验证 alias 的 proof 与 Subject 匹配；桥接坐标不可变，状态只能单向收敛，更新必须推进 row version。
5. resolver 只读既有 bridge，不创建 claim、不签发登录 session、不读取 family relationship/access grant，也不把 resolver 结果当作 resource authorization。

## 明确未做

- 不创建任何 `legacy_identity_aliases` 数据行，不自动迁移或合并历史账号。
- 不改登录、refresh token、身份绑定、家庭关系、Time Letter、Echo、业务消息 writer、`mailbox_letters`、公开 API 或 iOS UI。
- 不通过手机号、家庭关系或默认授权推断收件人身份；未来业务 writer 仍必须单独证明 exact resource/purpose 的 access grant。
- 不接入跨账号 writer、reader 或公开消息中心；bridge resolver 虽已完成独立
  PostgreSQL disposable smoke，仍不代表跨账号消息可见或可投递。

## 验证

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-legacy-identity-inbox-bridge-contract-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- 专用 gate `11` 项通过，覆盖已验证正常路径、缺失/重复 bridge、claim pending、身份/Subject/Vault/账户生命周期失效、value-free summary、只读 Postgres 查询边界和 disposable smoke runner。
- 全量 `scripts/verify_backend.sh` 通过，包含既有业务消息、异步 effect、Owner Truth、Provider、知识库、迁移、FastAPI 与静态边界回归。
- 后端 `main@fe9eefa` 已部署，API 容器执行
  `scripts/run-backend-legacy-identity-inbox-bridge-postgres-smoke.sh` 通过。该脚本仅创建、迁移和删除独立临时数据库，验证 active 解析、account suspend/soft-delete fail-closed、坐标不可变、value-free summary，以及零 `mailbox_letters` / business-message projection 写入；`/ready` 的 database、schema、auth、incident 均为 `ready`。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过（本地） | 内部 identity/account/vault 桥接与 fail-closed resolver 合同已验证。 |
| G1 | 未开始 | 没有 iOS 或公开 reader 使用 bridge。 |
| G2 | 范围内通过 | `main@fe9eefa` 的 API 容器已执行 resolver disposable PostgreSQL smoke；只证明读桥的 fail-closed 边界。 |
| G3/G4 | 未开始 | 没有 Provider、通知或真机行为。 |

## 后续前提

这个 bridge 只解决“受验证 Subject 对应哪个活跃收件箱账户”的内部解析问题。真正的跨账号业务消息仍需单独满足：

1. 对 exact resource、purpose、recipient 的 `DelegatedAccessService` 授权决定；
2. 业务完成 receipt 与业务目标的一致性重校验；
3. recipient admission 的独立 disposable PostgreSQL smoke；
4. 仅在前三项具备后，才讨论受控 writer、内部 reader 与公开消息中心接入。
