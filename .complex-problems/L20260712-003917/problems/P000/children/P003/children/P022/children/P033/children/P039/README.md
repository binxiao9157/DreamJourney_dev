# Round 3C3A Job、Outbox 与 Legacy Timer 迁移

## Problem

当前长任务和定时投递没有统一 worker/outbox；TimeLetter 等流程存在业务状态与副作用非原子，宿主机 timer 状态又不由仓库证明。需要设计从同步/旧 timer 到事务 outbox、租约 worker 和幂等 consumer 的切流，确保旧/new scheduler 不双跑。

## Success Criteria

- 盘点所有同步长任务、宿主机/应用 timer、轮询和 queue-like 表。
- 定义 business command→outbox→job→attempt→consumer receipt 的迁移 wave。
- 定义 one-active scheduler lease、heartbeat、shadow consumer、job-type cutover 和旧 timer retirement。
- TimeLetter/Inbox、Echo reply、notification、rights、voice/DH cleanup 等不重复业务 effect。
- unknown/lease expiry/cancel/reconcile/dead-letter 与 authorityEpoch 明确。
- 至少 12 个 crash、双跑、重复、乱序和 rollback 场景。
- 增加静态门禁并同步 Evidence Matrix。
