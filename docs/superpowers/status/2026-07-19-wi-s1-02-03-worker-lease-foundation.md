# WI-S1-02-03 Worker Lease Foundation 证据

日期：2026-07-19

## 本次子闭环

`WI-S1-02-03` 已完成第一段默认关闭的 worker lease foundation。它只提供
异步副作用作业的协调基础，不会启动真实业务消费、Provider 调用、TimeLetter
或 Echo 投递，也不改变公开 UI 或权限边界。

后端新增：

1. PostgreSQL worker lease：使用数据库时间和 `FOR UPDATE SKIP LOCKED`，
   保证同一作业同一时刻只能被一个 worker 获取。
2. heartbeat、过期租约重领、旧 attempt 标记 `unknown`、旧 worker 失权，
   以及取消请求围栏。
3. `async-effect-worker` Compose profile：默认未启动；当前 worker 只输出
   值无关的 eligible job 数量和类型，未注册 handler 时不会 claim/执行任务。
4. 可丢弃 Postgres smoke：只创建 synthetic job，验证并发抢占、心跳、过期
   重领、stale heartbeat 拒绝与取消后的 heartbeat 拒绝。

## 验证

- 后端实现/部署 commit：`e5888ef`。
- 本地 `scripts/verify_backend.sh` 通过：631 tests 及现有 backend smoke。
- `git diff --check` 通过。
- 部署服务器迁移头为 `0013`，状态 `ready`。
- 部署后 smoke 通过：

  ```text
  Async effect Postgres smoke passed: schemaHead=0013
  outcomes=['accepted', 'deduplicated'] sourceOutbox=true workerLease=true
  rollback=true terminalGuard=true receiptsAppendOnly=true
  ```

- 公共 `/ready` 返回 database/schema/auth/incident 均 ready。

## 明确未完成

本 Work Item 尚未整体关闭。scheduler leader lease、真实 handler admission、
consumer inbox、Provider retry/receipt、dead-letter，以及 TimeLetter/Echo/APNs
执行仍未实现且保持默认关闭。下一子闭环仍属于 `WI-S1-02-03`，只会继续补
scheduler shadow/lease 协调和 handler 准入边界。
