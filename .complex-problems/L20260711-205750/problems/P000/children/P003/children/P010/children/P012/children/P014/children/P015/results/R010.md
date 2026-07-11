# 线上 Receipt Baseline 与 Dry-run 执行结果

## Summary

线上 Postgres receipt baseline 与只读 dry-run 硬门已通过。执行识别出 12 条可压缩历史记录，但没有修改线上数据，也没有输出用户标识、知识正文或访问凭据。

## Done

- 在生产 API 容器内通过只读聚合查询采集 receipt 基线，未导出用户 ID、知识正文、访问凭据或数据库连接信息。
- 使用线上 Postgres 执行 `keep-days=0`、`batch-size=20` 的 receipt maintenance dry-run。
- 对 dry-run 报告执行状态、失败数、允许 kind 和候选统计检查。
- dry-run 后重新采集聚合基线，并与执行前结果逐项比较。

## Verification

- 脱敏基线为 receipt 总数 15、result 总字节数 15408、`kb.mutation=10`、`kb.sync=5`，identity 聚合指纹为 `eb00fd53d6e74181132fd89f0b2cceb8`。
- Dry-run 返回 `mode=dryRun`、`status=ok`、`scanned=15`、`candidate=12`、`alreadyCompact=3`、`failed=0`、`failedUsers=0`。
- 预计可将候选记录从 12371 字节压缩到 1760 字节，预计节省 10611 字节。
- 报告中的 kind 仅包含 `kb.mutation` 与 `kb.sync`，均在允许集合内。
- Dry-run 前后 receipt 总数、kind 分布、identity 聚合指纹和 result 总字节数完全一致，证明本轮没有写入。

## Known Gaps

- 未运行 `--apply`，线上仍有 12 条可压缩历史 receipt。
- 未执行 P016 的 apply、二次幂等和关联 smoke 验收。

## Artifacts

- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/before.json`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/first-dry-run.json`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/after-dry-run.json`
