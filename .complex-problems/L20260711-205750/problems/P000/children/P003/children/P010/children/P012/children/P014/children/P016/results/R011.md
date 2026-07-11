# 线上 Receipt Apply、幂等与关联 Smoke 执行结果

## Summary

线上 12 条历史 receipt 已安全转换为 compact envelope，identity 与 payload hash 聚合不变；二次 dry-run/apply 均为零变更，部署知识、隐私维护和 change-feed 关联回归全部通过。

## Done

- 使用 P015 相同参数执行线上 Postgres receipt apply。
- 采集 apply 后脱敏聚合并与 apply 前基线比较。
- 执行第二次 dry-run 和第二次 apply 验证幂等。
- 运行部署态知识 smoke。
- 运行 privacy metadata maintenance 与 change-feed maintenance 默认 dry-run。
- 部署知识 smoke 新增 receipt 后再次运行 receipt dry-run，验证新 writer 直接写 compact envelope。
- 更新 Task 26 状态文档。

## Verification

- 首次 apply：`status=ok`、`candidate=12`、`updated=12`、`failed=0`、`failedUsers=0`。
- Apply 前后 count、byKind 和 identity 聚合指纹完全一致。
- Result 聚合占用由 15408 字节降至 2396 字节，减少 13012 字节。
- 第二次 dry-run：`candidate=0`；第二次 apply：`updated=0`。
- 部署知识 smoke：完成、冲突/idempotency/tombstone/分页/generation 验证均通过，token 和 user identifiers 已脱敏。
- Privacy dry-run：`status=ok`、`invalidRecordCount=0`。
- Change-feed dry-run：`status=ok`、`skippedUsers=0`、锁与 statement timeout 均为 0。
- 部署知识 smoke 后最终 receipt dry-run：18 条全部 already compact，`candidate=0`。

## Known Gaps

- 没有为 `created_at` 增加新索引；当前线上数据量仅 18 条且 dry-run 延迟正常，保留为规模增长后的监控项，不在本任务盲目变更 schema。
- 没有执行真机测试；本任务为后端数据维护与非真机 QA，不依赖真机。

## Artifacts

- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/first-apply.json`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/after-apply.json`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/second-dry-run.json`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/second-apply.json`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/deployed-knowledge-smoke.log`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/privacy-maintenance-dry-run.json`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/change-feed-maintenance-dry-run.json`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/post-smoke-dry-run.json`
