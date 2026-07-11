# Archive ID 跨 Owner 冲突保护

## Problem

Postgres `archive_items.id` 是全局主键，通用 upsert 在冲突时会重写 `user_id`；这会让同 ID 素材被另一用户接管，并破坏来源删除的 owner 语义。

## Success Criteria

- Postgres 相同 ID 仅允许同 owner 更新，跨 owner 返回明确 ownership conflict。
- InMemoryStore 与 Postgres 行为一致。
- Archive API 将冲突映射为稳定 409，不泄露原 owner。
- 同 owner timeLetter 更新、普通 archive 创建和既有测试不退化。
