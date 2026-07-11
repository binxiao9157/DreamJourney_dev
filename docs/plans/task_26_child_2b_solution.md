# 实现 Postgres Receipt 分用户维护与 Dry-run CLI

## Problem Definition

历史 full receipt 需要在不删除幂等身份行、不改变 fingerprint、不过度锁表的前提下分批瘦身。维护命令必须默认只读，并在单个用户锁等待或异常时继续处理其他用户。

## Proposed Solution

在 PostgresStore 增加 `maintain_knowledge_operation_receipts`。先只读列出达到 keep-days 的 legacy receipt 用户与候选；每个用户使用独立连接/事务，设置 lock/statement timeout，获取与知识写入一致的 user advisory lock，重新 `FOR UPDATE` 读取候选并调用 P005 纯转换 helper。Dry-run 只计算 canonical JSON bytes；apply 按 batch 更新 result，不修改 kind/schema/hash/created_at。新增 CLI 暴露 apply、keep-days、batch-size 与 timeout，并输出不含正文的结构化报告。

## Acceptance Criteria

- 参数验证完整，keep-days 可为 0，batch-size/timeout 必须为正数。
- Dry-run 不执行 UPDATE/commit 数据变化。
- Apply 分用户事务、advisory lock、lock/statement timeout，并限制每批候选数。
- 单用户 lock timeout、statement timeout 或转换失败记录为 failed/skipped 后继续。
- 报告含 scanned/candidate/updated/alreadyCompact/failed、按 kind 计数和 bytes before/after/saved，不含 result 正文。
- Payload hash 与 receipt 身份列不修改，第二次 apply 幂等。
- CLI 默认 dry-run，非 Postgres store 明确失败。

## Verification Plan

新增 fake database/connection/cursor 测试覆盖 dry-run、apply、幂等、锁超时、用户级回滚、参数校验和 CLI 参数；运行相关单测、py_compile、CLI help 和 diff check。

## Risks

- 真实 Postgres 的 `pg_column_size(jsonb)` 与 Python canonical JSON bytes 不完全相同；报告应明确是估算值，真实线上 P003 再读取数据库尺寸。
- 对候选先列用户再逐用户重查可避免长事务，但维护期间新增 receipt 不保证本轮处理，下一轮可继续。

## Assumptions

- P005 转换 helper 已通过验收。
- Receipt 行不删除，payload hash 永久保留。
