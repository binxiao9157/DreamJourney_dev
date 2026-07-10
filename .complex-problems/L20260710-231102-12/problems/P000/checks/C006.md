# P0 统一知识库主链路成功检查

## Summary

根目标已在约定的 P0 与非真机范围内完成。知识写入、增量同步、用户隔离、受控上下文构建和 Echo 当前轮生成已成为一条可观察、可降级、可回归的主链路，同时保留旧客户端兼容。

## Evidence

- P001、P002、P003、P004 均通过独立成功检查。
- 后端全量验证通过 182 个单元测试及全部基础 smoke。
- iOS 全量 release regression、generic iPhoneOS build 和关键模拟器 smoke 通过。
- 状态文档记录数据流、schema/version、隐私策略、部署命令和剩余风险。

## Criteria Map

- 单一知识主链路：iOS KBLite、后端 mutation/change-feed/context、Echo turn RAG 已串联。
- 用户与权限隔离：按 userId 文件、session/generation guard、generationAllowed 后端过滤覆盖。
- 增量与冲突：revision、operationId 幂等、change feed、409 refresh/retry 覆盖。
- 生成可用：selected context 形成 generationContext，iOS 当前 turn 提交，失败按 query 本地降级。
- 可持续验证：部署态 smoke、release gate、文档和 Closure 台账齐全。

## Execution Map

- R006 汇总四个已验收子问题的结果。
- 复杂筛选和隐私策略由后端负责；iOS 负责用户隔离、同步调度与当前 turn 生命周期。

## Stress Test

- stale revision、重复 operation、后端超时、用户切换、页面退出、迟到回调和不允许生成的档案均有防护或测试证据。
- Archive payload 缺隐私元数据时后端拒绝，补齐后主链路 smoke 通过，证明权限门不是空壳。

## Residual Risk

- 服务器真实 Postgres smoke 与火山真机语义验收仍需部署/真机环境；不将其表述为已完成。
- 大规模分页、删除 tombstone、向量/混合检索留在 P1/P2，不影响当前 P0 闭环。

## Result IDs

- R006
