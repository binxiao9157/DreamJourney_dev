# WI-S0-04-02 Versioned Migrator 与 Startup DDL 退役

日期：2026-07-16
Work Item：`WI-S0-04-02`
状态：`INTERNAL_READY / DEPLOYED / G2_PRODUCTION_BASELINE_VERIFIED / DATA_SRE_APPROVAL_PENDING`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`DB_RECOVERY`
Lease：`ACTIVE`

## 已实现

- 新增独立 `PostgresMigrator`，按 `version/name/phase/compatibility/checksum` 加载 SQL 与 JSON manifest。
- `schema_migrations` ledger 记录 version、checksum、running/applied/failed、started/applied time、build ID、execution mode 和 machine-safe error code。
- migration apply 使用全局 advisory lock，且在获取锁前设置 lock/statement timeout；并发 runner 只能执行一次。
- checksum drift、数据库 head 超前、migration 未应用、partial schema 和未显式授权的现有 schema adoption 均 fail closed。
- fresh database 执行 `0001_existing_schema_baseline.sql`；现网完整 schema 只能通过 `--adopt-existing-baseline` 写 receipt，不重放 baseline DDL。
- baseline manifest 枚举 19 张表、18 个显式索引、全部业务列和 append-only trigger；SQL 不含 ALTER/DROP/TRUNCATE/DELETE。
- API startup、`PostgresStore` 和 `store_factory` 已移除全部业务 schema DDL；API 只打开 pool 并执行既有运行时 session drain。
- Docker 镜像显式打包 `db/migrations`；CLI 提供 dry-run/apply/verify/adopt，README 写明先 migration 后 API 的部署顺序。
- 新增真实 Postgres fresh/repeat/concurrent G2 smoke，临时数据库在 finally 中清理。

## 验证

- migrator 单测覆盖 fresh、repeat、existing adoption、partial mismatch、checksum drift、old binary head、failed restart、并发锁、timeout 顺序和 baseline 破坏性 SQL guard。
- 后端全量 `371` 项测试通过；凭据边界、FastAPI、知识库 smoke、Python compile、shell syntax 和 `git diff --check` 通过。
- 实现提交 `89fe5a5` 与 smoke 修复 `d4fb9ec` 已推送；服务器当前部署 `d4fb9ec`。
- 生产 dry-run 返回 `baselineAction=adoptExplicitly`、pending `0001`，无 partial mismatch。
- 生产使用显式 adoption 写入 `0001/applied/adopted/build=89fe5a5`，随后 verify 返回 `expectedHead=appliedHead=0001`。
- baseline SQL checksum：`8f97e876d8d259765d342ccdb4ba955fd304fe0209bf904514d68c872e1eeb13`。
- fresh 临时 Postgres 创建 19 张表，ledger 为 `applied/execute`，重复执行 no-op，append-only trigger 存在。
- 两个真实并发 migrator 的结果为 apply `1`、skip `1`。
- API 切换前后生产 ledger receipt 完全一致，证明 API startup 没有重写 migration 或执行隐式 schema 修复。
- 新 API 健康检查、migration verify、数据库 UoW deployed smoke 均通过。

## 未关闭边界

- 本轮是 additive baseline/ledger，不包含 legacy contract migration，也没有自动 down migration。
- 生产 baseline adoption 已真实演练，但正式 Data/SRE migration window、审批和容量制度仍需外部确认。
- backup manifest、隔离 restore 和 receipt replay 属于 `WI-S0-04-04/05`，不能用本轮临时数据库 smoke 替代。
- schema head 尚未接入流量 readiness；该合同属于下一项 `WI-S0-04-03`。
- worker/deploy automation 目前依赖明确执行 CLI；在 `/ready` 与部署 gate 完成前，不宣称自动化发布闭环已完成。

## 下一步

进入 `WI-S0-04-03`：新增 `/live` 与 `/ready`，使 DB checkout、migration head/checksum、required auth config 决定流量 readiness，并保留旧 `/health` 兼容语义。
