# WI-S1-02-08 Time Letter 跨账号收件人准入影子层（G0）

日期：2026-07-30

## 本轮范围

`business_message_projections` 已具备默认关闭的 durable projection shadow，`legacy_identity_aliases` 已能在 fail-closed 条件下解析已验证的 Subject 到活跃收件箱账户。本轮只在两者之间增加一个不写入的 Time Letter 收件人准入判定层，确认未来的跨账号 writer 是否具备最小授权前提。

后端提交：

```text
main@8214666 feat(v4): add time letter recipient admission shadow
main@d33fb45 test(v4): add recipient admission deployed smoke
main@5823d24 fix(v4): accept hash effect resources in message projections
```

## 新增内部合同

1. `TimeLetterRecipientMessageAdmissionService.evaluate_shadow(..., enabled=False)` 默认关闭。关闭时在解析收件箱 bridge、取得关系 scope 或调用授权前直接返回 `admissionDisabled`，不写 access receipt、业务消息、legacy mailbox、通知或 Provider。
2. 启用的 shadow 只接受同一个已完成、已到期的 Time Letter 收件人 target：
   - `messageKind=timeLetter`；
   - consumer 必须是 `timeLetter.deliveryTarget`；
   - typed completion 必须是 `DELIVERED`；
   - completion/source/intent/target receipt 必须一致；
   - `openAt` 必须已经到达；
   - 原始 completion source 必须仍为 owner inbox 坐标。
3. bridge 解析和 delegated access revalidation 在同一 `delegated_access_relationship_scope` 内执行。只有已验证且活跃的收件人 Subject/Vault/account 解析成功，且 exact `timeLetter.read` / `READ` / `TIME_LETTER` grant 的资源 ID 等于实际 `letterId` 时，才返回 `wouldAdmit`。
4. shadow 授权明确使用 `record_receipt=False`。family relationship 只是授权的前置条件，不能代替 exact grant。
5. 结果和证据摘要只保留 hash/状态/原因；本层不连接 projection writer、`mailbox_letters`、公开 API、iOS UI、APNs、对象存储或 Provider。

## 明确未做

- 不启用真实跨账号业务消息 writer，不向 `business_message_projections` 或 legacy `mailbox_letters` 写入。
- 不改现有 Time Letter 到期投递、提醒中心 reader、公开 API、登录/refresh、family 关系或 iOS UI。
- 不处理 legacy mailbox 和 future business-message projection 的双写/切换；该切换必须单独设计、验证并具备回滚证据。

## 验证

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-business-message-recipient-admission-g0-gate.sh
.venv/bin/python -m unittest \
  tests.test_time_letter_delivery_effects \
  tests.test_time_letter_delivery_service \
  tests.test_delegated_access \
  tests.test_business_message_projection_repository
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- 专用 Gate 通过 6 项测试：关闭态零副作用、exact grant、无 grant、错误 resource/purpose、已撤销 relationship、未到期/非标准 completion、owner/source/bridge mismatch。
- 相关 Time Letter、delegated access、delivery service、projection repository 回归共 36 项通过。
- 全量 `scripts/verify_backend.sh` 通过：`1,588` 项单测及既有 contract、migration、FastAPI、知识库、Provider 和静态边界 Gate。

部署 `main@5823d24` 后，API 容器内执行：

```bash
bash scripts/run-backend-time-letter-recipient-admission-postgres-smoke.sh
```

结果：

```text
Time Letter recipient-admission Postgres smoke passed
(shadow only; no mailbox, message projection, worker, notification, session, or Provider effect).
```

该 disposable PostgreSQL smoke 创建并销毁独立的合成数据库，验证：

1. 已验证 legacy inbox bridge 与 exact `timeLetter.read` grant 同时存在时，due/delivered 的收件人 target 只返回 `wouldAdmit`；
2. grant、relationship、bridge 或收件箱状态不满足时 fail-closed；
3. 全程不写 access receipt、`mailbox_letters`、`business_message_projections`、worker 或通知；
4. Time Letter 稳定 target hash 即使以数字开头，也可以安全生成 value-free 消息投影摘要，不改变既有 async-effect operation ID、stable key 或去重语义。

API 容器重启后 `/ready` 返回 database、schema、auth、incident 均为 `ready`。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过（本地） | 默认关闭的准入影子合同、exact grant 和 fail-closed 路径已验证。 |
| G1 | 未开始 | 没有 iOS、reader 或公开 UI 接入。 |
| G2 | 已通过（受限 deployed smoke） | 后端 `main@5823d24` 已部署，独立 recipient-admission disposable PostgreSQL smoke 已通过；仍未启用 writer、reader 或通知。 |
| G3/G4 | 未开始 | 没有 Provider、通知或真机行为。 |

## 后续前提

任何真实 writer 讨论前，必须先完成并分别验收：

1. legacy `mailbox_letters` 与 future business-message projection 的单写/双写/切换和回滚策略；
2. 受控 writer、内部 reader 和实际 access receipt 的独立 G0/G2 证据；
3. 最后才是公开消息中心可见性和通知投递。
