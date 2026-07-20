# WI-S1-01-03 M0-A Orchestrator / Session State Bridge

日期：2026-07-20
状态：已完成本子切片；私有、默认关闭、无公开路由或 Provider 调用

## 本轮范围

- 新增 `OwnerTruthInterviewSessionOrchestrationService`，只读已持久化的 `InterviewSession`。
- 持久化 session 的 owner/vault/thread、authority epoch、状态、用户边界和 owner 轮次是策略的权威输入，调用方不能覆盖。
- 映射到既有 `InterviewOrchestrator` 后只输出 value-free action/reason/review-batch 摘要。
- 调用方只能提交不含原文的短暂策略信号：opaque topic ID、deepening count、布尔状态和 fatigue；原始 Message 内容不被读取或输出。
- `skipOnce` 只返回“本次聆听、待消费”的决策，不偷偷写 session；后续命令切片才负责显式确认消费。

## 实现与部署

- 后端提交：`DreamJourneyBackend main@95ff2e0`。
- 无数据库迁移；仍依赖已部署的 `0029` conversation/session schema。
- 服务器已 fast-forward、重建 API 容器；生产 migration head 仍为 `0029`。

## 验证证据

- 目标单测：4 passed；与 conversation/policy 的组合单测：19 passed。
- `bash scripts/verify_backend.sh`：959 tests 通过，FastAPI 与既有契约 smoke 通过。
- 既有隔离 Postgres smoke 已扩展并在服务器 API 容器内通过：
  - 真实 session owner turn count 驱动 review batch hint。
  - 私有消息原文、session ID 不进入 bridge summary。
  - 持久化 `doNotAsk` fail-closed 为 pause。
  - 原有 owner/vault 隔离、幂等、CAS、append-only 和无 Source/Candidate/MemoryVersion 写入仍通过。
- `https://dreamjourney-api.liftora.cn/ready`：database/schema/auth/incident 均为 `ready`。

## 明确未完成

- `deepeningTurnCount`、fatigue、topic switch 和 review-batch acknowledgement 目前仍是显式、无文本的瞬时信号，尚未作为可恢复 pacing state 写入 session。
- 不接模型、Provider、公开 Echo UI、Message-to-Candidate 或 Candidate-to-MemoryVersion。

## 下一子切片

`WI-S1-01-03-M0A-03-PERSISTED_PACING_STATE`：以 additive schema/typed command 收敛 deepening、fatigue、candidate batch acknowledgement 和可恢复 session pacing state；保持 owner/vault/CAS/append-only 边界，不接公开 UI 或 Provider。
