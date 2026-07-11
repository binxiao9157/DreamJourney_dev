# Task 23：P1 本地知识文件保护与语义缓存隔离

## 目标

保证本地知识图谱、远端 base、pending mutation 和 governance outbox 使用统一的原子写入、文件保护和备份排除策略；同时让离线语义检索缓存严格绑定当前账号与知识 generation，实体内容变化或账号切换后不得复用旧向量。全部使用非真机模型、静态门禁和 iOS 构建验收，不改变公开 UI。

## 现状审计

- `KBLiteSemanticSearch.embeddingCache` 只以实体 `id` 为 key；不同账号、不同实体类型若复用 ID，可能错误复用旧向量。
- 实体正文变化但 ID 不变时，旧缓存不会失效。
- `warmCache` 在全局并发队列异步写共享字典，没有锁；账号切换后旧预热任务仍可能写回。
- `isCacheWarm` 是全局布尔值，首个账号预热后会阻止后续账号预热。
- graph/base/pending/outbox 已大多使用 atomic write，但目录、文件保护和 iCloud backup 排除策略分散且不完整。
- graph 位于 Documents，base/pending/outbox 位于 Application Support；本轮不移动路径，避免引入迁移风险。

## P1 合同

1. 语义缓存必须绑定不可逆 owner key 和 KBLite user generation；登出、账号切换或 generation 变化时立即清空当前缓存并使旧异步预热失效。
2. cache key 至少包含 entity kind、entity ID 和 searchable text fingerprint；跨类型 ID 冲突和同 ID 内容更新不得复用旧向量。
3. cache 的读取、写入、激活和失效必须线程安全；旧 scope 的异步任务不得写入新 scope。
4. 语义搜索只能使用当前 KBLite scope；scope 缺失或不匹配时 fail closed 到既有关键词检索。
5. graph、remote base、pending mutation、governance outbox 和 legacy sync history 使用统一 `KnowledgeLocalStoragePolicy`：atomic write、`completeUntilFirstUserAuthentication`、目录/文件排除备份。
6. 对既有文件采用就地 best-effort 加固，不改文件名和 envelope，不自动删除用户数据。
7. 不在日志、文件名或缓存 key 中暴露原始 userId、知识正文或 sourceRef。

## 实现范围

### 语义缓存

- 为 `KBLiteSemanticSearch` 增加 owner digest + generation scope、锁和内容指纹 cache key。
- `KBLiteManager` 在 init/switch/save/search 路径传递当前 scope；旧 generation 的 warm task 被拒绝。
- 移除全局 `isCacheWarm`，允许新实体和内容更新增量预热。

### 本地文件

- 新增 `KnowledgeLocalStoragePolicy`，集中处理目录创建、备份排除、文件保护和原子写入。
- 接入 `KBLiteManager`、`KBLiteMultiUser`、`KnowledgeRemoteBaseStore`、`KnowledgePendingMutationStore`、`KnowledgeGovernanceOutboxStore`。
- 保留依赖注入的临时目录测试能力；不把保护失败静默解释为业务写入成功。

### QA / 文档

- 先新增语义缓存 scope/content/concurrency 静态或纯模型门禁。
- 新增知识文件保护静态门禁，确认所有敏感持久化入口使用统一策略。
- 接入 release regression/release QA package，运行相关 gates、Simulator/generic iPhoneOS build 与 `git diff --check`。

## 验收清单

- [x] 相同 entity ID 在不同账号、类型或内容下生成不同 cache key。
- [x] 切换账号/登出后旧预热任务不能污染新 scope。
- [x] 缓存并发读写不再直接访问无锁字典。
- [x] graph/base/pending/outbox/sync history 都通过统一保护策略写入。
- [x] 原有 envelope、路径和账号隔离行为兼容。
- [x] generation Context 在 ranking 前完成 persona/privacy/evidence 候选过滤，并保留排名后二次过滤。
- [x] 新 gates、release QA、Simulator/generic iPhoneOS build 与差异检查通过。
- [ ] 代码、文档提交推送；后端无变化时明确无需部署。

## 最终非真机证据

- Full release regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task23-knowledge-storage-cache-final3/report.md`
- Simulator Debug build：通过。
- Generic iPhoneOS build：通过。
- Archive -> Echo Simulator smoke：通过。
- Echo delayed reply notification smoke：通过。
- Task 23 五条新增 model/static gates：通过并接入默认 release regression。
- 独立审查发现的旧摘要 fallback、post-commit 加固结果歧义和并发 scope activation 排序问题均已修复并进入 final3。
- 后端：本轮无代码或合同变化，不需要重新部署。

## 非目标

- 不引入 pgvector、第三方向量数据库、Core ML 模型或网络 embedding provider。
- 不迁移现有 JSON 到数据库，不实现端到端文件加密或用户自管密钥。
- 不修改 Echo/Stitch UI，不做真机验证。
- 不处理 change-feed retention/compaction、历史 sourceRef 迁移或公开知识治理页面。
