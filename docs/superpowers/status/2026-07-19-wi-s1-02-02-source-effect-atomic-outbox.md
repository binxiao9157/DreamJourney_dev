# WI-S1-02-02 CreateSource 原子 Outbox 证据

日期：2026-07-19

## 完成范围

本 Work Item 选择 Owner Truth 的 `CreateSource` 作为首个低风险、
shadow-only 的异步副作用生产者。它没有接入公开路由，不改变 Archive
兼容行为、公开 UI、TimeLetter、Echo、Provider 或 APNs。

同一个 request/job Unit of Work 内会：

1. 写入幂等 Source 与 Source command receipt；
2. 生成值无关的 `ownerTruth.source.created` operation；
3. 写入 operation、outbox event 与 effect receipt。

重复 command 返回原 Source/effect receipt；effect 写入或外层 UoW 失败时，
Source 与 effect records 一起回滚。

## 事务边界修复

部署验证发现根 `DatabaseUnitOfWork` 未在进入时显式开始事务，导致
`create_owner_truth_source()` 内的 Psycopg `connection.transaction()` 可以
提前提交 Source。后端已在 UoW 进入时开启根事务，使嵌套 transaction 变成
savepoint；Source、operation、outbox 与 receipt 现在受同一根事务控制。

## 验证证据

- 后端 producer commit：`2c22673`。
- 根事务修复 commit：`aee1572`。
- 后端证据 commit：`2e87416`。
- 本地 `scripts/verify_backend.sh` 通过：622 tests，FastAPI/部署/知识库 smoke
  均通过。
- 线上 PostgreSQL smoke 通过：

  ```text
  Async effect Postgres smoke passed: schemaHead=0013
  outcomes=['accepted', 'deduplicated'] sourceOutbox=true rollback=true
  terminalGuard=true receiptsAppendOnly=true
  ```

- `https://dreamjourney-api.liftora.cn/ready` 返回 ready，database/schema/auth/
  incident 均 ready。

## 明确未完成

Worker lease、scheduler、attempt、consumer inbox、业务完成 receipt 和
Provider 执行仍未开启，属于后续 `WI-S1-02-03` 及之后工作项。
