# Receipt 转换与 Privacy 兼容实现结果

## Summary

已建立 legacy full receipt 到最小 compact envelope 的纯转换层，并修复 privacy maintenance 对 compact V2 receipt 的误判；不涉及数据库事务或部署。

## Done

- 新增四类 operation 支持的历史 receipt 转换 helper。
- 转换结果移除 graph、mutation、实体正文和重复身份字段，保留原始 revision/schema/可选兼容标记及 ID-only governance summary。
- Compact envelope canonicalizer 可去除旧版重复身份与非白名单 summary 字段，再次执行保持幂等。
- 非法 revision/schema、未知 operation kind、缺失治理摘要等情况 fail closed。
- Privacy canonicalizer 识别 compact V2 envelope，不再要求 mutation。
- Compact V2 receipt 的 payload hash 原样保留；legacy full V2 继续走原有 canonical mutation/hash 逻辑。

## Verification

- 新增 receipt maintenance 纯函数测试 6 项。
- `STORE_BACKEND=memory` 下 receipt/privacy/core/Postgres/governance 组合测试 230 项通过。
- 新模块 py_compile 与 `git diff --check` 通过。

## Gaps

- Postgres 扫描、用户级事务、CLI 和 bytes 报告由 P006 实现。
- 组合 smoke、全量回归和运维说明由 P007 实现。

## Artifacts

- `app/services/knowledge_receipt_maintenance.py`
- `app/services/knowledge_privacy_maintenance.py`
- `tests/test_knowledge_receipt_maintenance.py`
