# 实现知识变更历史压缩与快照恢复闭环

## Problem Definition

现有知识 change feed 永久保留每个 revision 的完整 graph，Postgres 数据会持续增长；一旦人工清理历史，后端会返回 revision gap 500，iOS 严格分页 reducer 会永久停止同步。分页读取还通过两次独立查询获得 snapshot 与 changes，无法与并发 mutation/compaction 保持同一事务视图。

## Proposed Solution

后端新增每用户 change-feed 水位和原子读取合同。维护脚本默认 dry-run，显式 apply 时按保留天数与最少 revision 数计算安全 cutoff，在同一用户知识锁事务中删除有权威 operation receipt 的历史 change 并推进水位。请求早于水位时返回结构化 HTTP 410，成功分页合同保持不变。

iOS 增加严格 snapshot 响应解析和 GET 客户端。Coordinator 仅在收到结构化 compacted 错误时执行一次 snapshot fallback，并继续使用现有 user/generation/pull-session、三方合并、CAS 和本地 pending 保护；其他分页结构错误仍直接失败。

## Acceptance Criteria

- 后端持久化 `minimumSinceRevision`，水位只增不减。
- legacy 与 paginated 请求早于水位均返回精确的 `knowledgeChangeFeedCompacted` 410 合同。
- 200 成功响应与现有客户端合同兼容，分页读取在单一用户锁/事务视图中完成。
- 压缩维护默认不写库；apply 删除与水位更新同事务，失败完整回滚，可重复执行。
- operation receipts 不被删除；无 receipt 的 legacy change 不被物理删除。
- iOS 仅对 compacted 合同执行最多一次 snapshot fallback；身份或 generation 失配不落盘。
- snapshot 恢复后保留本地未同步修改并继续 push；失败不推进 base/pending。
- 后端单测、iOS model/static smoke、release regression、模拟器与 generic iPhoneOS 构建通过。
- 两仓库提交推送，后端部署并通过线上 Postgres smoke；不要求真机。

## Verification Plan

后端先补 in-memory API 合同测试和 Postgres fake-connection 维护测试，再实现 store/route/script；增加部署 smoke 验证正常分页与 compacted 410/snapshot 合同。iOS 先扩展 model smoke 验证 snapshot 和错误分类，再实现 client/coordinator。最终运行知识专项 gate、默认 release regression、`git diff --check`、后端测试和两个 iOS 非真机构建。

## Risks

- 分页中途发生压缩可能改变可读窗口，必须以 410 中断而不是拼接旧页与新 snapshot。
- 删除没有 receipt 的旧 change 会破坏 legacy operation replay，因此只删除可由 receipt 保证幂等的记录。
- 自动 apply 可能造成不可逆历史清理，因此部署后仍保持 dry-run，显式命令才执行。

## Assumptions

- `kb_snapshots` 始终保存当前完整权威 graph。
- 现代知识操作均写入 `kb_operation_receipts`，且本任务不定义 receipt TTL。
- iOS 当前三方合并和 CAS 机制可复用于 snapshot fallback。
