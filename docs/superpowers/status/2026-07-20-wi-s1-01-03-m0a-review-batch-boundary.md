# WI-S1-01-03 M0-A 私有复盘批次与确认边界

日期：2026-07-20
状态：已完成本子切片；私有、默认关闭，未接公开 Echo UI 或 Provider

## 本轮范围

- 为私有 `InterviewSession` 增加 `pending_review_batch_id`，防止同一会话同时出现多个待确认批次。
- 新增 `InterviewReviewBatch`：只保存 owner/vault/session/thread、触发原因、轮次窗口、截止消息序号、策略版本和 authority epoch；不保存消息原文、不产生事实结论。
- 新增两个显式幂等命令：
  - `createInterviewReviewBatch`：仅在未复盘 owner turn 达到 5 轮，或会话已暂停/结束且仍有未复盘 turn 时允许。
  - `acknowledgeInterviewReviewBatch`：只确认“已查看此批次”；不等同 Candidate 的接受、修正或拒绝。
- 确认时从当前未复盘计数中扣除冻结窗口。待确认期间新进入的 owner turn 会保留给下一批，不会因旧批次确认丢失。
- 已将 `pending_review_batch_id` 传入只读访谈策略 bridge；有待确认批次时不重复提示同一批次已到期。

## 严格边界

- 仍不创建 `Source`、`Candidate`、`DecisionReceipt`、`MemoryVersion`，也不改变 KBLite、公开上下文或访客查询域。
- 不新增 HTTP route、模型/Provider 调用、后台任务或公开 UI；普通 Echo 用户不可见内部批次、计数或疲劳状态。
- 每个写入保留 owner/vault/authority epoch 校验、session CAS、review batch CAS、command id 幂等回执和 append-only receipt。
- 非 Owner 不能读取或确认批次；批次身份、轮次窗口、策略版本和 authority epoch 不可修改；确认是唯一允许的终态转换。

## 实现与部署

- 后端提交：`DreamJourneyBackend main@1b8083f`。
- 迁移：`0031_owner_truth_interview_review_batches`，`expand`、`additive`。
- `ownerTruthConversationV1`、`guidedInterviewM0A`、`ownerTruthInterviewReviewBatchM0A` 均保持默认 `false`。
- 服务器已 fast-forward、重建 API 容器、应用并验证 `0031`；生产 migration head 为 `0031`。

## 验证证据

- `python3 -m unittest tests.test_owner_truth_interview_review_batch tests.test_owner_truth_interview_review_batch_migration_contract tests.test_owner_truth_interview_pacing_state tests.test_owner_truth_interview_session_orchestration tests.test_owner_truth_interview_orchestration`：20 项通过。
- `bash scripts/verify_backend.sh`：通过，包含 966 项后端单测、FastAPI smoke、既有 contract gate 与静态检查。
- `git diff --check`、Python 编译检查：通过。
- 服务器 API 容器：`python scripts/migrate_db.py --apply --build-id 1b8083f` 和 `--verify` 均为 `ready`，head=`0031`。
- 服务器 API 容器：`scripts/run-backend-owner-truth-conversation-postgres-smoke.sh` 通过。
  - 在隔离 Postgres 数据库中验证 `0031` 迁移、会话退出批次、创建/确认幂等、重启恢复、owner/vault 隔离和禁止写入 Source/Candidate/MemoryVersion。
- `https://dreamjourney-api.liftora.cn/ready`：database、schema、auth、incident 均为 `ready`。

## 未完成与下一步

- 当前批次仅是私有 review boundary；Message-to-Candidate 生成、Candidate 的部分接受/修正/拒绝和 MemoryVersion 激活仍沿用独立 Authority 主干，尚未接入本批次。
- 尚未实现用户换话题后的一轮内切换/暂停旧 `ConversationThread` 的持久化语义。
- G1 公开/模拟器访谈体验、G3 Provider、G4 产品与外部验收仍未关闭。

下一子切片：`WI-S1-01-03-M0A-05-TOPIC_SWITCH_AND_THREAD_LIFECYCLE`。目标是用私有、typed、CAS 的 thread 生命周期记录用户主动换话题，旧 thread 必须在一轮内暂停或结束，不能借机生成 Candidate、调用 Provider 或改变公开 Echo UI。
