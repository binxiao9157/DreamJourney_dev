# 后端知识 Mutation V2 实施票

## Problem Definition

在已部署的 v1 revision/full-graph mutation 上增加实体级 upserts/tombstones，同时保证历史数据、旧客户端、ownership、幂等和 Postgres 并发事务不回归。

## Proposed Solution

新增纯函数合同模块负责 v2 校验与 delta 应用；store 增加 `apply_kb_delta_mutation`，复用请求独占事务和 revision lock；`kb_changes` 增加 nullable mutation JSONB，InMemory 使用同结构；路由按 `mutationSchemaVersion=2` 分发并返回权威 graph。新增 v2 API/store/Postgres 测试与独立 smoke，v1 路径保持原样。

## Acceptance Criteria

- upserts/tombstones 校验和原子应用符合 Task 13 固定合同。
- idempotency、409、历史 nullable mutation、ownership 与 v1 返回不回归。
- Postgres 迁移幂等且事务连接始终 commit/rollback/close。
- 全量后端测试、v1/v2 smoke、py_compile 和 diff check 通过。

## Verification Plan

先补 InMemory/API/Postgres fake-connection 失败测试，再实现；运行目标测试、`scripts/verify_backend.sh` 和新增本地 FastAPI v2 smoke。

## Risks

- partial upsert 不能通过局部 privacy 过滤破坏指向已有实体的关联 ID，应在应用到当前 graph 后统一过滤并验证 upsert ID 仍存在。
- tombstone 类型或 ID 未严格限制会产生跨类型误删。

## Assumptions

- server snapshot 仍是每个 revision 的权威完整图谱。
- v2 change metadata 仅用于同步/审计，不进入 Context generation 文本。
