# 后端保留水位与压缩成功检查

## Summary

P001 的代码、合同、维护入口和本地验证均满足原问题；真实 Postgres 部署验收明确属于 P003，不阻断本子问题成功。

## Evidence

- 专项 17 个测试和 API smoke 通过。
- 全量 281 个后端测试与 `verify_backend.sh` 通过。
- 独立审查 findings 已修复并重新验证。

## Criteria Map

- memory/Postgres 原子 page 与水位：store 测试覆盖。
- legacy/paged 410 与 200 兼容：API 测试和 delta smoke 覆盖。
- dry-run/apply/回滚/legacy barrier：compaction 专项测试覆盖。
- 后端专项测试与 smoke：均通过。

## Execution Map

- R000 对应 P001 唯一 one-go ticket T001。
- 改动限定在后端仓库，未越过 iOS/交付边界。

## Stress Test

- 覆盖非零水位二次压缩、分页中途压缩第二页 410、锁超时隔离、单用户失败不回滚已完成用户、无 receipt 前缀阻断。

## Residual Risk

- 真实 PostgreSQL 锁和 SQL 适配将在 P003 部署 smoke 验证；不影响 P001 本地实现闭环判定。

## Result IDs

- R000
