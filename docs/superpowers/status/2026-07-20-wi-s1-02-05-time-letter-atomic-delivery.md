# WI-S1-02-05 TimeLetter 到期投递与 Mailbox 原子闭环证据

日期：2026-07-20

## 已实现边界

该工作项为隐藏、默认关闭的 TimeLetter 业务副作用切片建立了逐目标的原子投递合同；它没有启用 worker、公开路由、APNs 或历史数据迁移。

后端按 `letterId + vaultId + sealedVersion + target` 建立稳定目标键，并在同一个 Postgres Unit of Work 内：

1. 锁定并重读已封存的 TimeLetter；
2. 在执行时重新校验 `openAt`、Owner、family relationship、recipient subject 和精确的 `timeLetter.read` grant；
3. 仅为合法目标写入不含正文和原始标题的 metadata-only mailbox；
4. 为 delivered、skipped 或 blocked 目标写 Consumer Inbox 与业务 receipt；
5. 在所有目标都得到终态后，以版本 CAS 写入 delivery summary。

旧的 legacy due-dispatch 路径显式排除 `time-letter-delivery-v1`，避免新旧路径对同一信件并发处理。该协议目前没有由公开创建路径写入，也没有启动任何新 worker。

## 代码与提交

- `84732cb`：逐收件人 delivery target 合同。
- `3cbce85`：目标 receipt 合同。
- `3167d2`：TimeLetter 原子服务、Postgres UoW 扩展和 G2 smoke。
- `fe37263`：将 G2 smoke wrapper 标为可执行。

相关后端入口：

- `app/services/time_letter_delivery_effects.py`
- `app/services/time_letter_delivery_service.py`
- `app/services/postgres_store.py`
- `scripts/run-backend-time-letter-atomic-delivery-postgres-smoke.sh`

## 验证证据

### G0

本地通过 35 项定向单元/合同测试，覆盖：

- 多收件人和逐目标 receipt；
- 未到期、封存/版本/epoch 变化的 fail-closed 行为；
- grant 撤销或 relationship 失效只跳过对应收件人；
- 并发重放仅有一份 mailbox；
- recipient mailbox 写入异常时 Owner mailbox、receipt 与 summary 一起回滚；
- legacy dispatcher 不处理新的 hidden 协议。

同时通过 `py_compile`、`bash -n` 和 `git diff --check`。

### G2

后端 `main@fe37263` 已推送并部署至 `miao-server`，API 容器已 rebuild/recreate，公网 `/ready` 返回 database/schema/auth/incident 全部 `ready`。

部署容器内运行隔离 PostgreSQL smoke：

```text
time letter atomic delivery postgres smoke passed ownerMailbox=2 recipientMailbox=1 concurrent=deduplicated revokedRecipient=skipped rollback=clean
```

该 smoke 创建并清理临时数据库，不写生产业务数据；其验证并发 dispatch 去重、撤权跳过和跨目标写入回滚。

## 明确未完成

- 新协议的 scheduler/worker admission、shadow compare 和 cohort cutover；
- 对 legacy `delivered` 但缺 mailbox 的历史 reconcile；
- notification outbox、APNs provider 和真机到达证据；
- TimeLetter 的公开发布、产品/隐私关系撤销语义和 G4 批准。

因此本项状态为 `INTERNAL_READY / BACKEND_DEPLOYED / G0_G2_SCOPED_VERIFIED / DEFAULT_OFF`，不能表述为公开产品已完成。

## 后续工作

活动权已切到 `WI-S1-02-06`：为 Echo 延迟回信建立唯一 Answer、Inbox 与业务 receipt，保留 server-off 默认状态，并禁止 iOS 本地 timer/notification 伪造“回信已抵达”。
