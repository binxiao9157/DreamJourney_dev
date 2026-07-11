# Store 组合删除事务原语

## Problem

现有 store 只能分别执行知识 mutation 和 archive delete，无法在同一锁/事务内保证二者一致。

## Success Criteria

- Memory/Postgres 提供相同签名的组合删除方法。
- Postgres mutation/change feed/archive delete 在一个 transaction；异常统一 rollback。
- revision conflict、operation duplicate、sealed/missing item 均有稳定结果且不产生半完成状态。
- 旧 `apply_kb_mutation` 行为和测试不退化。
