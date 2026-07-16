# WI-S0-04-01 Connection Pool 与 Request/Job Unit of Work

日期：2026-07-16
Work Item：`WI-S0-04-01`
状态：`INTERNAL_READY / DEPLOYED / G0_G2_FUNCTIONAL_VERIFIED / CAPACITY_BASELINE_PENDING`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`DB_RECOVERY`
Lease：`ACTIVE`

## 已实现

- `PostgresStore` 删除长期共享 `_connection`，所有普通 repository 访问通过 request/job-scoped `DatabaseUnitOfWork` checkout、commit/rollback、return。
- 新增基于 `psycopg_pool` 的正式 pool adapter，以及只用于单元测试/兼容测试的 factory pool adapter。
- FastAPI 最外层 middleware 为除 `/health` 外的请求建立唯一 UoW；成功响应 commit，错误响应 rollback，异常回滚后再归还连接。
- pool exhaustion 返回稳定 `503 database_pool_exhausted`，不回落 memory store 或新建共享连接。
- 每个数据库请求返回无业务内容的 correlation ID；system-only `/ops/release-policy/observations` 暴露 checkout、commit、rollback、failure、pool exhaustion 和 return failure 计数。
- 应用 startup 显式打开 pool，shutdown 关闭 pool；知识维护与时间信件脚本也显式管理 pool 生命周期。
- pool 参数通过 `DB_POOL_MIN_SIZE/DB_POOL_MAX_SIZE/DB_POOL_TIMEOUT_SECONDS` 配置，默认 `1/10/5s`。
- release handoff 新增可选/交接强制的 `RUN_BACKEND_DB_UOW_SMOKE=1`。

## 验证

- G0 fake contract 覆盖成功 commit、异常/错误响应 rollback、rollback-only、statement failure reset、pool exhaustion、repository 内部不提前 commit、startup/shutdown 顺序。
- 后端全量 `362` 项测试通过；凭据边界 4 项、FastAPI smoke、知识库 smoke、Python compile、shell syntax 和 `git diff --check` 通过。
- 后端提交 `dfdff1d` 已推送并部署，服务器运行 `production/postgres`。
- 容器内真实 Postgres smoke 通过：2 个并发 work unit 使用 2 个独占 backend connection 和不同 transaction ID。
- `SELECT 1 / 0` 触发 statement failure 后，单连接 pool 的下一 work unit 可成功执行 `SELECT 1`，证明 aborted transaction 已 rollback/reset。
- 单连接 pool 被占满时在 timeout 后 fail closed，并记录一次 `poolExhausted`，未建立旁路连接。
- 部署 API smoke 通过：成功路径 `commit +2`、422 路径 `rollback +1`、pool/return failure 增量均为 `0`。
- smoke 后真实 Postgres `idle in transaction=0`；常驻 API 指标无 failed、pool exhausted 或 connection return failure。

## 未关闭边界

- 默认 pool 大小只是保守技术基线，尚未完成生产并发压测、峰值连接预算和 Operations 容量批准，因此不宣称容量 Gate 完成。
- `/health` 仍只表示进程健康；DB/schema/auth readiness 属于 `WI-S0-04-03`，本项不提前扩展健康合同。
- API startup 仍执行现有 additive DDL；versioned migrator 和 startup DDL 退役属于 `WI-S0-04-02`。
- backup、隔离 restore 和 receipt replay 基线属于后续 `WI-S0-04-04/05`，本项没有伪造恢复证据。
- maintenance job 的多批次事务保持原有每用户/每批边界；本项没有把长任务强行合并为单个大事务。

## 下一步

1. 进入 `WI-S0-04-02`，建立 version/checksum/lock/ledger 的 migrator，并把 startup DDL 迁出 API 生命周期。
2. 之后完成 `WI-S0-04-03` 的 `/ready` DB/schema/auth readiness。
3. Operations 在独立窗口完成 pool 容量基线；在此之前保持当前默认值，不以单次 smoke 代替负载验收。
