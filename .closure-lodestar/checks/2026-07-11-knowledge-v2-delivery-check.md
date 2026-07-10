# 知识 V2 跨仓库交付成功检查

## Summary

R002 满足 P003 的组合 gate、部署形态合同、文档和提交要求；公网部署明确不在本轮自动执行范围内。

## Evidence

- release regression 报告证明全部静态 guard、iOS/后端 diff checks 与部署形态 V2 smoke 同次通过。
- HTTP smoke 输出明确包含 `mutationSchemaVersion=2`、`tombstoneVerified=true`、幂等、Context 和冲突证据。
- 状态文档列出 iOS/后端提交、命令和未部署边界。

## Criteria Map

- 部署态 v2 合同：已由本地 FastAPI HTTP 进程和 deployed smoke 验证。
- 单开关组合 gate：`RUN_KNOWLEDGE_V2_SYNC_GATE` 强制部署 smoke，模型 smoke 始终执行。
- 防回退静态检查：release QA package 断言 runner、开关和后端强制逻辑。
- 文档与版本：Task 13 专项状态文档完成。
- 全量验证：195 后端测试、iOS generic Simulator/iPhoneOS build、diff checks 均通过。

## Execution Map

- 后端 deployed smoke 负责持久化合同与 Context 结果。
- iOS release regression 负责本地模型和跨仓库编排。
- 状态文档负责明确上线前命令及未部署状态。

## Stress Test

- stale v1 `/kb/sync` 不能恢复已 tombstone 的实体。
- 重放相同 v2 operationId 不推进 revision，mutation metadata 保持一致。
- stale base 必须返回 409；一般 v2 校验错误不触发 iOS fallback。

## Residual Risk

- 公网 Postgres 环境要在后端推送和部署后再运行同一开关；该外部状态不影响本地交付物完整性。
- 具体模拟器 destination 的 MCP 映射异常仍存在，但 generic iOS Simulator 编译成功。

## Result IDs

- R002
