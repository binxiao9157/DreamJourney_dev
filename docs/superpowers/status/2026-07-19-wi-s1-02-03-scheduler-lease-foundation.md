# WI-S1-02-03 Scheduler Lease Foundation 证据

日期：2026-07-19

## 本次子闭环

在 worker lease foundation 之后，`WI-S1-02-03` 已补齐 scheduler lease 的
shadow-only 协调基础。它只处理无业务内容的 operation/lease 标识，不创建或
投递任何真实定时任务。

后端现在具备：

1. 对已接受 operation 的幂等 scheduler lease 注册；
2. 数据库时间、`FOR UPDATE SKIP LOCKED`、heartbeat、过期重领、旧 scheduler
   失权和 release；
3. 默认不启动的 `async-effect-scheduler` Compose profile；
4. 只返回 eligible count/scheduler key 的 shadow CLI；未注册 scheduler cohort
   时不会 claim、调度或执行业务；
5. synthetic-only 的 Postgres smoke 覆盖。

## 验证

- 后端实现 commit：`2b23563`。
- SQL 返回列限定修复 commit：`066ead8`。
- 本地 `scripts/verify_backend.sh` 通过：639 tests 及现有 smoke。
- 线上 migration head：`0013`，状态 ready。
- 线上 disposable Postgres smoke 通过：

  ```text
  Async effect Postgres smoke passed: schemaHead=0013
  outcomes=['accepted', 'deduplicated'] sourceOutbox=true workerLease=true
  schedulerLease=true rollback=true terminalGuard=true receiptsAppendOnly=true
  ```

- `/ready` 的 database/schema/auth/incident 均 ready。

## 修复记录

首次部署 smoke 发现 scheduler CTE 的未限定 `RETURNING lease_id` 与 CTE
同名字段冲突；该问题只发生在临时 smoke 数据库。后端已改为 `lease.lease_id`
等限定返回列，并加入静态合同断言后重新部署验证通过。

## 明确未完成

`WI-S1-02-03` 仍在进行。下一子闭环是 typed handler admission、consumer
idempotency 和完成 receipt 边界；Provider、TimeLetter/Echo/APNs、真实定时
投递和任何公开开关仍保持默认关闭。
