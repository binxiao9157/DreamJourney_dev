# 线上 Receipt Baseline 与 Dry-run 验收

## Summary

P015 验收通过，并作为后续 P016 apply 的硬门证据。P015 本身没有执行任何线上写入。

## Evidence

- `before.json`、`first-dry-run.json`、`after-dry-run.json` 保存了脱敏聚合与 dry-run 报告。
- Dry-run 返回 `status=ok`、`failed=0`、`failedUsers=0`。
- Before/after 聚合比较全部通过。

## Criteria Map

- 基线脱敏：只保存 count、byKind、identityHash、resultBytes，满足。
- Dry-run 硬门：mode/status/failure 断言满足。
- Kind 白名单：报告仅包含 `kb.sync`、`kb.mutation`，满足。
- 无写入证明：四项 before/after 聚合完全一致，满足。
- 候选与收益：12 条候选，预计节省 10611 字节，满足。

## Execution Map

- 生产 API 容器内执行只读 SQL 聚合。
- 执行 receipt maintenance 默认 dry-run。
- 重新执行相同聚合并本地断言相等。

## Stress Test

- 使用 `keep-days=0` 覆盖全部历史 receipt，确保所有现有 kind 都进入扫描范围。
- 对 unknown kind、failed user 和 failed row 设置硬失败判定；本次均未触发。

## Residual Risk

- Apply 尚未执行，真实 JSONB 更新、二次幂等和关联 smoke 仍属于 P016。
- 该风险不影响 P015 的只读 dry-run 目标，但不能据此宣称整个 Task 26 完成。

## Result IDs

- `T015` 对应执行结果。

## 暂停边界

线上共识别 12 条可压缩历史 receipt。Apply 属于下一独立任务 P016；P015 没有触发任何线上写入。
