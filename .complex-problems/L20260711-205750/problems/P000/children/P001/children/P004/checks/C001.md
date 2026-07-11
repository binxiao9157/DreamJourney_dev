# Compact Receipt 标记与最小 envelope 验收

## Summary

修复结果满足跟进问题的全部标准：compact envelope 已去除重复身份字段，两条重放路径使用一致诊断语义，legacy/full 与历史 compact 双读保持兼容，且相关与全量回归均通过。

## Evidence

- `compact_knowledge_operation_receipt_result` 只写版本、revision、mutation schema、可选时间/兼容标记和 ID-only governance summary。
- `rebuild_compact_knowledge_operation_result` 在 change 与 snapshot 两条分支之后统一设置 `receiptCompacted=true` 和 envelope 原始 revision。
- 内存和 Postgres 测试明确断言 envelope 不含 user/operation identity、graph、mutation 与私有正文。
- 218 项相关测试及 289 项后端全量回归通过。

## Criteria Map

- 最小 envelope：已由内存/Postgres 持久化断言覆盖。
- 一致 compact replay 标记：change 与 snapshot 两条路径均有断言。
- Legacy/full 与历史 compact 兼容：保留 dual-read，历史额外字段不会影响 reader。
- Governance/archive duplicate：summary、幂等与无正文断言通过。
- API/iOS parser 兼容：对外仍返回 graph/revision/mutation，仅增加可选诊断字段。

## Execution Map

- R001 完成 helper、store 与测试修正。
- P002 负责历史 full receipt 迁移，不作为本跟进问题的未完成项。

## Stress Test

- 使用不同 baseRevision 重放同 operation，验证 fingerprint-first duplicate。
- 删除关联 change 后重放，验证当前 snapshot + 空 V2 mutation fallback。
- 同 operation ID 更换 payload，验证在查询 change/snapshot 前即 conflict。

## Residual Risk

- 尚未在真实 Postgres 上执行历史迁移；该风险属于 P002/P003，且 P001 不会单独部署。

## Result IDs

- R001
