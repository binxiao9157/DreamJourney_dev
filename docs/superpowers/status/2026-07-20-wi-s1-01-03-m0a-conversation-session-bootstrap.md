# WI-S1-01-03 M0-A Conversation / InterviewSession Bootstrap

日期：2026-07-20
状态：已完成本子切片；默认关闭，不接公开 UI 或 Provider

## 本轮范围

- 新增私有 `ConversationThread`、`InterviewSession`、`ConversationMessage` 与命令回执 schema。
- 新增 owner/vault/epoch 隔离、`commandId` 幂等、`expectedVersion` CAS、单 Vault 单 active session 与消息顺序约束。
- “不再问”持久化为 paused + `doNotAsk`；未激活 session 拒绝追加消息。
- 消息只留在 Owner Truth 私有访谈域；本切片不创建 `Source`、`Candidate`、`DecisionReceipt` 或 `MemoryVersion`。

## 实现与部署

- 后端提交：`DreamJourneyBackend main@bc7ac93`。
- 迁移：`0029_owner_truth_conversation_session_bootstrap`，`expand`、`additive`、release flags 默认 `false`。
- 服务器已 fast-forward、重建 API 容器并应用/校验迁移；生产 migration head 为 `0029`。

## 验证证据

- `bash scripts/verify_backend.sh`：955 tests 通过，FastAPI smoke 通过。
- `scripts/run-backend-owner-truth-conversation-postgres-smoke.sh`：服务器 API 容器内通过。
  - 隔离数据库迁移与重启读取。
  - owner/vault 跨域读取拒绝。
  - start/append 重放幂等，陈旧版本拒绝。
  - 原始消息 append-only。
  - `sources`、`memory_candidates`、`memories`、`memory_versions` 均未被访谈消息写入。
- `https://dreamjourney-api.liftora.cn/ready`：database/schema/auth/incident 均 `ready`。

## 明确未完成

- 未把 `InterviewOrchestrator` 决策写入或消费持久化 session counters/boundary。
- 未提供任何公开路由、iOS UI、模型调用、自动 Candidate 提取或 MemoryVersion 激活。
- `skipOnce`、cooldown、topic switch、fatigue/deepening 的持久化消费和批量 review 仍待后续子切片。

## 下一子切片

`WI-S1-01-03-M0A-02-ORCHESTRATOR_SESSION_STATE_BRIDGE`：在同一 private/default-off 边界内，将已部署的 provider-neutral `InterviewOrchestrator` 读取已持久化的 session/thread state，输出 value-free action/reason summary；不写 Candidate/MemoryVersion，不改公开 Echo UI。
