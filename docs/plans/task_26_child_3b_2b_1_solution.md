# 采集脱敏聚合并审计线上 Dry-run

## Problem Definition

需要在不读取/输出知识正文和用户标识的前提下证明线上历史数据可安全转换，并将 dry-run 设为 apply 的机器可判定硬门。

## Proposed Solution

在 API 容器内执行只读 SQL，计算 receipt count、按 kind count、identity+payload_hash 有序 md5 和 `pg_column_size(result)` 总量。将 JSON 保存到本地 ignored 证据目录。运行 keep-days=0 receipt maintenance 默认 dry-run并保存报告；本地脚本断言 mode/status/failures/kinds。再次采集 baseline，确认 count/hash 不变。

## Acceptance Criteria

- Before/after-dry-run count、byKind、identityHash 完全一致。
- Dry-run mode=dryRun、status=ok、failedUsers=0、failed=0。
- byKind 只含四种允许值，报告不含敏感正文或标识。
- Candidate/bytes 明确，为 P016 提供硬门证据。

## Verification Plan

保存三个 JSON 并使用本地 Python 断言；只在所有断言通过后关闭 P015。

## Risks

- 未知 kind 或 partial 时停止，不创建 apply ticket执行结果。

## Assumptions

- API 容器包含维护脚本和 psycopg。
