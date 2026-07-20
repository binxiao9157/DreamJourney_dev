# WI-S1-01-03 M0-A Persisted Interview Pacing State

日期：2026-07-20
状态：已完成本子切片；私有、默认关闭、未接公开 Echo UI 或 Provider

## 本轮范围

- 在私有 `InterviewSession` 增加可恢复的 `deepening_turn_count`、`candidate_batch_turn_count` 和 `fatigue`。
- 新增显式、幂等的 `recordInterviewPacing` 命令。它只接受值无关的里程碑事件：完成深挖、完成总结、疲劳保护/耗尽/重置、消费一次跳过。
- owner 消息写入时递增未复盘 batch 计数；深挖、总结、疲劳和跳过的语义由独立 pacing command 记录，不从原始消息内容推断。
- 已部署的 session bridge 改为只从持久化 session 读取 deepening、batch 和 fatigue。调用方不能再用瞬时计数或疲劳值覆盖策略输入。

## 边界与拒绝项

- `deepeningCompleted` 仅在 boundary 为 `open`、fatigue 非 `exhausted`、且未超过深挖预算时允许。
- `skipOnce` 需要单独显式消费，消费后才回到 `open`；重放同一 command 保持幂等。
- 仍不读出 Message 原文，不调用模型或 Provider，不创建 `Source`、`Candidate`、`DecisionReceipt`、`MemoryVersion` 或 review batch。
- 不新增路由、不改公开 Echo 视觉或交互，不把内部 fatigue/pacing 暴露给普通用户。

## 实现与部署

- 后端提交：`DreamJourneyBackend main@d111311`。
- 迁移：`0030_owner_truth_interview_pacing_state`，`expand`、`additive`，`ownerTruthConversationV1` 和 `guidedInterviewM0A` 均保持默认 `false`。
- 迁移扩展 command receipt allow-list，保持 `startInterviewSession`、`appendInterviewMessage`、`setInterviewBoundary` 的既有约束，并为 `recordInterviewPacing` 增加无消息、带 session CAS 的形状约束。
- 服务器已 fast-forward、重建 API 容器、应用并验证迁移；生产 migration head 为 `0030`。

## 验证证据

- `python3 -m unittest tests.test_owner_truth_interview_pacing_state tests.test_owner_truth_interview_pacing_state_migration_contract`：通过。
- `bash scripts/verify_backend.sh`：通过，包括 FastAPI 与既有契约 smoke。
- `git diff --check` 与 Python 编译检查：通过。
- 服务器 API 容器内 `scripts/run-backend-owner-truth-conversation-postgres-smoke.sh`：通过。
  - 临时 Postgres 数据库应用到 `0030`，重启后仍能读取 boundary、deepening 和 batch state。
  - pacing command 的 CAS、重放幂等、owner/vault 隔离、append-only 以及禁止写入 Source/Candidate/MemoryVersion 均保持通过。
- `https://dreamjourney-api.liftora.cn/ready`：database、schema、auth、incident 均为 `ready`。

## 明确未完成

- 未创建 review batch，也未把候选提案或确认决策写入任何 Authority 主干。
- 未实现用户换话题的一轮内切换/暂停旧 thread 的持久化语义。
- 未连接模型、Provider、公开 Echo UI、Message-to-Candidate 或 Candidate-to-MemoryVersion。
- G1 公开/模拟器访谈体验、G3 Provider、G4 产品与外部验收仍未关闭。

## 下一子切片

`WI-S1-01-03-M0A-04-DECISION_ACKNOWLEDGEMENT_AND_REVIEW_BATCH_BOUNDARY`：定义私有、typed、可审计的 review-batch 和决策确认边界。它只能形成待确认批次和 reason summary，不能自动接受、写入 MemoryVersion 或改变公开 Echo UI。
