# Receipt Maintenance 脏 Compact 与扫描完整性修复

## Problem

组合审查发现维护器仅凭 `receiptEnvelopeVersion=1` 就跳过行，可能永久保留夹带 graph/mutation/私有扩展字段的脏 compact receipt；operationId 空字符串会被首页游标漏过；用户发现一次性 fetchall 也不满足长期运行的有界扫描要求。这些问题会使 P007 的隐私与组合回归结论不成立。

## Success Criteria

- 每条 receipt 都通过统一转换/canonicalization 判断；只有与 canonical compact envelope 完全一致才计为 alreadyCompact/skipped。
- 带 envelope 版本但夹带 graph、mutation、重复身份或私有 summary 字段的行会成为 candidate，并在 apply 后清除正文。
- 空 operationId 历史行可被扫描；若转换无法安全执行则明确 failed，而不是静默漏过。
- 用户发现采用有界 keyset 分页，不一次性 fetchall 全部用户。
- 新增 fake Postgres 回归覆盖脏 compact、空 operationId 和多页用户发现。
- Receipt 专项和后端全量回归通过。
