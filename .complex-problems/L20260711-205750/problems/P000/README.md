# Task 26：P0 Knowledge Operation Receipt 保留与最小化

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_26_p0-knowledge-operation-receipt-minimization.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 26：P0 Knowledge Operation Receipt 保留与最小化

## 目标

限制 `kb_operation_receipts.result` 对完整知识图谱和历史文本的无界复制，同时永久保留 operation kind、schema version 和 payload fingerprint，保证 change feed 压缩后相同 operationId 仍不会被重复执行。

## 范围

- 为旧 receipt result 定义不含 graph/原始 mutation 文本的 compact envelope。
- compact receipt 保留 operationId、原始 revision、mutation schema、必要的非文本治理摘要和压缩时间。
- receipt replay 遇到 compact envelope 时，从当前权威 snapshot 重建兼容响应，并标记 `receiptCompacted=true`。
- mutation、governance、archive delete 三类重放保持 payload conflict 检测和 iOS 现有响应合同。
- 新增 dry-run-first Postgres 维护命令；默认不写库，显式 `--apply` 才压缩。
- 与 change-feed compaction 兼容：receipt 行不删除，仍可作为已验证操作屏障。
- 增加后端单测、维护脚本测试、部署 smoke 和跨仓静态 gate；不做真机。

## 验收标准

- compact 后 receipt 不包含 `graph`、实体正文或原始 mutation upserts。
- 同 operationId + 同 payload 重放返回 duplicate、verified，并携带当前权威 graph；revision 不增加。
- 同 operationId + 不同 payload 仍返回冲突。
- governance 重放仍返回合法 summary；archive delete 重放不再次删除或级联。
- change-feed compactor 仍把 compact receipt 视为 receipt，不形成新屏障。
- dry-run 不修改数据库；apply 按用户锁执行、失败按用户回滚并可重复运行。
- 后端测试、跨仓 gate、默认 release regression 与 iOS 两类非真机构建通过。

## 非目标

- 不删除 receipt fingerprint 行。
- 不改变公开 UI。
- 不迁移历史 sourceRef 身份。
- 不做真机验证。


## Success Criteria

- compact 后 receipt 不包含 `graph`、实体正文或原始 mutation upserts。
- 同 operationId + 同 payload 重放返回 duplicate、verified，并携带当前权威 graph；revision 不增加。
- 同 operationId + 不同 payload 仍返回冲突。
- governance 重放仍返回合法 summary；archive delete 重放不再次删除或级联。
- change-feed compactor 仍把 compact receipt 视为 receipt，不形成新屏障。
- dry-run 不修改数据库；apply 按用户锁执行、失败按用户回滚并可重复运行。
- 后端测试、跨仓 gate、默认 release regression 与 iOS 两类非真机构建通过。
