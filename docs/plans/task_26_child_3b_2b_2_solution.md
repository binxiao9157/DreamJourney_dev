# 小批 Apply、二次幂等与线上关联回归

## Problem Definition

P015 已证明线上有 12 条历史 receipt 可安全转换且 dry-run 不写数据。现在需要实际压缩这些 JSONB，同时证明 identity/hash 不变、重复执行无副作用，并确认知识主链路和相邻维护任务没有回归。

## Proposed Solution

沿用 P015 的 `keep-days=0`、`batch-size=20` 和超时边界执行一次 apply。执行前后采集相同的脱敏聚合，断言 count、byKind、identityHash 不变且 resultBytes 不增加。随后运行第二次 dry-run 和 apply，要求候选与更新数均为 0。最后运行部署知识 smoke、privacy maintenance dry-run 和 change-feed compaction dry-run，保存所有报告到 git 忽略证据目录，并更新 Task 26 状态文档。

## Acceptance Criteria

- 第一次 apply `status=ok`、`failed=0`、`failedUsers=0`，`updated=12`。
- Apply 前后 count、byKind、identityHash 完全一致，resultBytes 降低或保持不变。
- 第二次 dry-run `candidate=0`，第二次 apply `updated=0`。
- 部署知识 smoke 通过。
- Privacy metadata 和 change-feed maintenance 均为 dry-run 且无失败。
- 证据只保存脱敏聚合与维护报告，不包含知识正文、用户标识或凭据。

## Verification Plan

使用 API 容器内维护 CLI 和只读 SQL 聚合生成 JSON 证据；使用本地 Python 断言关键字段；运行现有部署知识 smoke 和两项维护 CLI 的默认 dry-run；最后执行 `git diff --check`。

## Risks

- JSONB apply 属于线上写入；若失败数、未知 kind 或聚合身份变化，立即停止后续步骤并保留报告。
- 两个调度实例并发可能争用锁；使用用户级 advisory lock 和显式 lock/statement timeout 限制影响。

## Assumptions

- P015 的候选数 12 仍是当前线上基线。
- 已部署后端版本 `4c0538b` 包含通过测试的 compact reader/writer 和维护 CLI。
- 线上 Postgres 与 API 容器健康。
