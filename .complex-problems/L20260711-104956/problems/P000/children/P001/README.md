# 后端稳定 target revision 分页

## Problem

`/kb/changes` 和两个 store 当前返回 sinceRevision 后全部记录，没有响应上界、limit 或固定读取水位。

## Success Criteria

- 无 limit 保持 legacy 响应；显式 limit 返回 target/next/hasMore/pageLimit。
- 首次固定 target，后续只读到该 target，不追逐新写入。
- Memory/Postgres 使用相同边界和 revision ASC。
- 参数异常、三页、固定 target、空终页和用户隔离测试通过。
- 后端全量验证通过。
