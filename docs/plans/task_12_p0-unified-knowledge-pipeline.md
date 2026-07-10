# P0 统一知识库主链路

## 背景

当前知识库由 iOS 本地 KBLite 和后端 KB snapshot / Context Packet V2 双轨组成。实际 Echo 仍主要注入本地最近摘要，`/context/build` 只用于 trace；`syncKnowledge` 没有稳定业务调用点，iOS 仍可直接调用 DeepSeek 提取，且 KBLite 单例在进程内切换用户时不会重新加载对应图谱。

## 范围

- 修复 KBLite 进程内用户切换隔离，确保内存图谱与当前用户文件一致。
- 为现有知识图谱补 revision、增量变更和幂等 mutation/change-feed 合同，同时保持 `/kb/sync` 与 `/kb/snapshot/{userId}` 兼容。
- 接通 iOS 自动知识同步，覆盖登录/切换用户、提取完成和前台恢复的稳定触发点。
- 将知识提取默认迁移到后端 `/kb/extract`；本地规则只作为离线/后端失败降级，不再让 KBLite 主链路依赖客户端 DeepSeek key。
- 让 `/context/build` 的 selected context 真正进入 Echo 回复生成；后端不可用时按本轮 query 使用本地 KBLite 降级。
- 防止后端 Context Packet 与旧 `buildContextString(query:nil)` 重复注入。
- 保持当前 ownership、family/time-letter policy、Context V2 trace 和公开 UI 不变。
- 增加后端单测/smoke、iOS 静态或 UIQA smoke、release gate 和状态文档。

## 不在范围

- 独立向量数据库、Mem0、Zep、Kafka 或 LangGraph。
- 完整知识审核/冲突解决公开 UI。
- 将本地 JSON 立即迁移到 Core Data/SQLite。
- 公开家庭知识图谱共享入口。
- 真机验收或产品视觉改版。

## 步骤

- [x] 审计并固定现有 KBLite、KB API、Context Packet 和 Echo 生成调用边界。
- [x] 实现后端 revision、幂等 mutations、change feed 与兼容 snapshot。
- [x] 实现 iOS 用户切换隔离、同步协调器和后端知识提取客户端。
- [x] 将 Context Packet selected context 接入真实 Echo 生成并保留 query-based 本地降级。
- [x] 补隐私、ownership、跨用户隔离、离线降级和重复注入测试。
- [x] 审查后加固：本地 fallback 仅使用 generationAllowed 数据，用户切换同步失效旧 generation。
- [x] 审查后加固：RAG 发送成功后才消费 gate，失败执行有界重试；change feed 失败不推进 revision。
- [x] 审查后加固：Postgres knowledge mutation 使用请求独占事务，旧 `/kb/sync` 不覆盖新 revision。
- [x] 运行后端全量测试、知识库 smoke、release QA、git diff check 和 iOS build。
- [x] 更新实现/验收文档并关闭递归 ledger。

## 成功标准

- 进程内切换用户后，KBLite 不保留上一用户内存图谱。
- 同一 mutation 重试不会重复写入；客户端可按 revision 拉取增量。
- 正常联网知识提取走后端；后端失败时仅执行明确的本地规则降级。
- Echo 正常路径使用 `/context/build` 的 query-scoped selected context，且旧本地摘要不重复注入。
- 后端超时/不可用时，Echo 使用本轮 query 的本地 KBLite 上下文继续工作。
- owner bearer 不能同步、读取、提取或构建其他用户知识上下文。
- Context V2 selected/filtered/ranking trace 和现有 QA evidence bundle 保持兼容。

## 递归 Ledger

- `L20260710-231102-12`
