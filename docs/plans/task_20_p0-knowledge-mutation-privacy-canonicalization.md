# Task 20：P0 Knowledge Mutation / Receipt 隐私 Canonicalization

## 目标

消除知识 V2 mutation 的隐私旁路：客户端提供的 `privacyMetadata.sourceRefs[].title` 不能进入首次响应、change feed、operation receipt 或持久化 JSONB。Snapshot、delta、receipt 和 replay 必须使用同一服务端 canonical mutation，同时安全、幂等地清洗已经落库的历史标题。

## 审计结论

- `apply_kb_mutation_v2` 会对最终 graph 调用 `filter_syncable_graph`，因此 snapshot 中的 source title 已被服务端 canonical 化。
- `normalize_kb_mutation_v2` 当前仍保留原始 entity/source metadata；该 mutation 随后进入响应、`kb_changes.mutation` 与 `kb_operation_receipts.result`。
- 因此同一操作可能出现 `graph.title=对话来源`，但 `mutation.title=<客户端原始标题>`，形成存储、同步与回放隐私旁路。
- 现有 source-ref audit 只扫描最新 snapshot，无法证明 change/receipt 历史没有原始标题。

## P0 合同

1. V2 mutation 在 payload fingerprint、graph merge、响应和持久化前执行一次 canonicalization。
2. source ref 的 `kind/id` 保持证据身份；`title` 由服务端 `source_ref_title(kind)` 生成，客户端 title 不可信。
3. 相同 operation ID 的 raw-title/canonical-title 重试应视为同一语义 payload；kind/id 或实体正文变化仍必须冲突。
4. change feed、receipt replay 与首次响应返回完全相同的 canonical mutation。
5. 存量清洗只规范 graph/mutation/result 中的隐私 metadata，不改 entity/source ID、正文、revision、operation ID 或 createdAt。
6. 存量 `kb.mutation` V2 receipt 的 payload hash 随 canonical mutation 更新；其他 operation kind 的 hash 不猜测重算。
7. 清洗支持 dry-run、apply、幂等重跑、事务回滚和聚合报告；报告不输出知识正文、source ID 或 token。

## 实现范围

### 后端

- 在 knowledge/privacy service 中新增可复用的 entity/mutation canonicalizer。
- InMemory/Postgres 新写入统一使用 canonical mutation 计算 fingerprint、写 snapshot/change/receipt 和响应。
- 新增 Postgres 存量 audit/apply maintenance service 与 CLI；使用 advisory lock 和单事务。
- 新增 sentinel 测试覆盖首次响应、重复回放、change feed、receipt、Fake Postgres JSONB 和 maintenance 幂等/回滚。

### iOS / QA

- iOS 不改变公开 UI；继续消费 canonical mutation。
- 新增跨仓静态/合同 gate，防止 response/change/receipt 再次分叉。
- release regression 和状态文档记录本轮隐私边界。

## 验收清单

- [x] raw source title 不出现在首次响应、duplicate replay、change feed 或 receipt result。
- [x] raw-title 与 canonical-title 的同 operation ID 重试保持幂等。
- [x] kind/id/正文变化仍触发 payload conflict。
- [x] 存量 dry-run 不写库，apply 只改 canonical metadata，第二次 apply 更新数为 0。
- [x] Postgres 迁移在异常时完整回滚，报告只含聚合计数。
- [x] 后端全量测试、跨仓 gate、release regression、Simulator/generic iPhoneOS build 通过。
- [x] 分仓提交推送；后端部署并先 dry-run、再 apply、再 dry-run 验证存量清洗归零。
- [x] 不做真机，不改 Stitch UI，不迁移 source identity。

## 非目标

- change-feed retention/compaction 与 snapshot fallback。
- Widget 共享隐私、iOS 文件保护和语义缓存隔离。
- KBPerson/FamilyMember 权限域解耦。
- 历史 `conversationSession/archiveImageAnalysis` source identity 迁移。
- 公开知识治理页面或真机验证。
