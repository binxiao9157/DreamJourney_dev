# Round 3D2 后端/数据/异步独立架构复审

## Problem

需要由独立评审者核对 V4 模块化单体、数据 Authority、typed `/v2`、AuthZ、migration、Job/Outbox、Object/Provider 合同是否能从当前 FastAPI/Postgres 代码增量落地，并识别事务、幂等、并发、数据丢失和不可运维点。

## Success Criteria

- 报告引用当前后端源码、schema/migration/test/deploy证据与 Product Spec 具体章节。
- 覆盖 identity/vault、Source/Memory/Projection、Conversation/Inbox/TimeLetter、rights、worker/outbox、object/provider 和 migration/rollback。
- 每项发现有唯一ID、严重度、证据、影响、建议和分类。
- 明确检查共享连接/启动DDL、payload owner、跨vault AuthZ、非原子effect、unknown Provider、历史不可恢复和 schema contract。
- 至少给出一个 crash/concurrency/rollback 压力测试；无 BLOCKER/HIGH 也必须说明残余风险。
