# 建立音色槽持久化与原子独占分配

## Problem

内存与 Postgres store 目前没有 provider speaker 的所有权记录，训练入口只能通过哈希选择配置中的 `S_` 槽，无法阻止并发碰撞或跨 profile 覆盖。

## Success Criteria

- 两种 store 都能同步配置槽、独占分配、查询和更新槽状态。
- Postgres 使用带锁/原子更新，两个并发分配不会取得同一槽。
- 重复分配同一逻辑 profile 返回原槽。
- 容量耗尽返回空结果供 API 映射为 409。
- 删除后的槽可标记 retired，且不再被分配。
- store 单元测试覆盖分配、重用、容量和退休行为。
