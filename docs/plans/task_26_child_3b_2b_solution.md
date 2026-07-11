# 以聚合指纹守护真实 Postgres Receipt 最小化

## Problem Definition

需要在真实 Postgres 将历史 full receipt result 转为 compact envelope，同时证明 receipt identity/payload hash 不变、失败为零、二次运行幂等，并验证相关维护任务和在线知识链路。

## Proposed Solution

在 API 容器内通过 settings 连接 Postgres，输出 receipt 总数、按 kind 计数、identity+payload_hash 有序聚合摘要和 result bytes 总量，不输出正文/用户 ID。使用 keep-days=0、batch-size=20 执行默认 dry-run并在本地保存 JSON。通过硬门后 apply，重复采集聚合并比较 count/hash；再运行 dry-run和第二次 apply，要求 candidate/updated=0。最后执行 deployed knowledge smoke、privacy maintenance dry-run和change-feed compaction dry-run。

## Acceptance Criteria

- First dry-run status=ok、failedUsers=0、failed=0、byKind 仅包含四种允许 kind。
- Apply status=ok，updated 与 first candidate 一致，result bytes 下降或不增加。
- 前后 receipt count、按 kind count、identity+payload_hash aggregate 完全一致。
- Second dry-run candidate=0，second apply updated=0。
- Deployed knowledge smoke、privacy dry-run、change-feed dry-run通过。
- 所有本地证据文件脱敏，不含正文、token、DSN或用户 ID。

## Verification Plan

保存 before/first-dry-run/first-apply/after/second-dry-run/second-apply JSON，使用本地 Python 仅打印安全摘要并做断言；运行远程 smokes 和最终 diff/status。

## Risks

- First dry-run partial/failed/未知 kind 时立即停止 apply。
- Bytes 为 JSON/数据库估算，物理表空间不会立即回收。

## Assumptions

- Reader-first P013 已通过。
