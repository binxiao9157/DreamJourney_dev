# Round 3C3A Job、Outbox 与 Legacy Timer 迁移方案

## Problem Definition

当前后端没有 worker/outbox 部署单元，TimeLetter 由仓库外 systemd timer 调 `dispatch-due`，业务 delivered 与 mailbox 非原子；Echo delayed reply、Voice/DH、push、maintenance 等以同步接口、轮询或 queue-like JSON 状态存在。迁移时若旧 timer 与新 scheduler/worker 双跑，或先改业务状态后丢副作用，会永久漏发或重复执行不可逆操作。

## Proposed Solution

在 Product Spec 新增 Job/Outbox/Timer migration 章：

1. 编制 15 类目标 Job 的 legacy trigger/state/target owner/dedupe/cutover/retirement 目录。
2. 增加 migration-only scheduler lease 与 job-family ownership：`legacy_observed/shadow/new_active/legacy_retiring/retired`，同一 family 只有一个 active scheduler generation。
3. 先让现有业务 command 在同一事务写最小 outbox；shadow dispatcher/consumer 只生成 would-run compare receipt，不调用 Provider/不写业务副作用。
4. 验证 event count/dedupe/resource/epoch/purpose 后，按 job family 切 active worker；scheduler 只发现/入队，业务模块 completion command 原子写业务状态、Inbox/projection/outbox。
5. 对 sealed/due TimeLetter、pending Echo reply、pending Voice profile、active DH lease、rights/delete 和 maintenance backlog 做 deterministic bootstrap job，不重放已完成 effect。
6. legacy timer 先 drain/禁用并释放 scheduler lease，再激活新 owner；切换以 DB lease/epoch 为准，不靠 systemd service 名或人工约定。
7. rollback 采用 pause/failover/reconcile，不恢复能直接产生 effect 的旧 timer；已提交 outbox/job/Inbox 保留。

## Acceptance Criteria

- 15 类 Job 均有 current trigger、target owner、dedupe、bootstrap、cutover、rollback和retirement。
- 定义 scheduler lease/generation/heartbeat、job family owner 与 one-active 不变量。
- outbox shadow 无副作用，active consumer 有 consumer receipt；业务状态与 outbox 同事务。
- TimeLetter/Inbox/APNs、Echo Answer/Inbox、rights/voice/DH 等完成语义分离且幂等。
- legacy backlog bootstrap 不把 delivered/failed/unknown 状态错误重放。
- 定义至少 9 个 migration waves 和 15 个 crash/双跑/乱序/回滚场景。
- Evidence Matrix 与 `product-v4-job-outbox-migration-check.py` 明确未实现边界。

## Verification Plan

- 静态门禁检查 15 job rows、scheduler state/lease、waves、rollback和场景。
- 对照现有 timer/scripts/routes/queue-like tables，确认每个 legacy producer/consumer有退役路径。
- 独立 reviewer 攻击双 scheduler、lease过期、shadow副作用、completion crash、bootstrap重复和旧 timer恢复。
- 运行全部 V4 门禁与 `git diff --check`。
- 本轮不部署 worker/systemd、不跑真实 Postgres并发；这些进入路线图 implementation/external gate。

## Risks

- 服务器实际 systemd/cron/container 状态未经本轮 SSH，必须在切换前重新 inventory。
- 部分历史状态不足以判断 effect 是否已发生，只能创建 reconcile/manual review job。
- 一次切全部 job family风险高，应先低风险 projection，再业务投递，最后 Provider高风险任务。

## Assumptions

- API/Worker 同模块化单体代码与 schema，但使用独立 process/role。
- Job/Outbox 采用 Round 3B 第26节 at-least-once + idempotency合同。
- Provider具体调用/对象处理由3C3B/3C3C，3C3A只迁队列和业务副作用编排。
