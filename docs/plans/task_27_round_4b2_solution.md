# 规划 Postgres UoW/恢复与 Access-First 数据权利

## Problem Definition

当前 PostgresStore长期缓存单连接、startup隐式DDL、`/health`无DB/schema探测且没有真实backup/restore；账号soft delete不立即撤销session，purged tombstone还能被restore/login upsert激活，purge只是同步删表清单且无对象/Provider/备份回执。路线必须先修数据地基，再构建不伪报完成的数据权利流程。

## Proposed Solution

1. 为 `WP-S0-04` 建立5项：pool/UoW、versioned migrator、live/ready、backup manifest、isolated restore/replay。
2. 为 `WP-S0-05` 建立6项：Rights schema/API、access-first revoke、restore/purge/hold、module executors、object/provider/backup adapters、iOS Data Rights状态面。
3. 使用独立DB/Rights审计的真实路径和已执行探针结果，不把memory/fake test视为G2。
4. 每项填写16字段，明确Stage0 internal-ready与Stage1 async/G2/G3/G4完整退出边界。
5. 部署采用expand-first、独立migrator、先撤访问、module receipt异步推进；物理删除和已撤访问只forward-fix，不回滚历史事实。

## Acceptance Criteria

- `WI-S0-04-01..05`与`WI-S0-05-01..06`连续唯一，176字段完整。
- DB覆盖UoW/migrator/readiness/backup/restore-replay，并明确真实Postgres gate。
- Rights覆盖request/receipt、全session/grant撤销、terminal purge、retention hold、module/object/provider/backup状态和iOS披露。
- 删除后旧token、purged恢复、删除receipt被purge、provider产物只本地tombstone等已知风险均有独立任务和负例。
- migration/restore/delete rollback遵循不可逆边界；没有down migration或“恢复已删除事实”。

## Verification Plan

1. 对照explorer路径、当前304项memory test与缺失real-PG证据。
2. 检查11个ID、176字段、路径和依赖。
3. 对照BAR-02/07、SOR-05/08、CR-04/10和Spec 24/27/28/34。
4. 运行data contract/backfill/cutover/composite、review、link和diff检查。

## Risks

- UoW改造与现有局部专用连接可能重复；先统一port/contract再迁调用点。
- access-first与30日恢复易混淆；撤权立即，恢复窗口只保留最小内部数据和强验证通道。
- Provider不支持删除时只能partial/unsupported，不能为了完成率写completed。
- backup恢复若不重放deletion ledger会复活已删除数据，必须作为readiness blocker。

## Assumptions

- 本票只写路线，不执行真实删除、备份或生产迁移。
- Provider/Backup/G4文案和SLA保持外部门。
