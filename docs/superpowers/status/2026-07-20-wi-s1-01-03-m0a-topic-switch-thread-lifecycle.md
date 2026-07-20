# WI-S1-01-03 M0-A 话题切换与线程生命周期边界

日期：2026-07-20
状态：已完成本子切片；私有、默认关闭，未接公开 Echo UI 或 Provider

## 本轮范围

- 新增 typed 命令 `pauseInterviewForTopicSwitch`。它只携带 command、thread、session 和双版本 CAS；不接收、不保存话题文本、话题 ID、模型结论或 Candidate payload。
- 当前 owner 明确换话题时，旧 `ConversationThread` 与 `InterviewSession` 在同一持久化单元内同步转为 `paused`，并各自推进 row version。
- 旧线程暂停后不能继续 append message；现有 `startInterviewSession` 只能由后续显式命令创建新的 active session，未自动推断或创建替代话题。
- 命令保留 owner/vault/authority epoch 校验、command id 幂等回执、thread/session 双 CAS 和 append-only receipt。

## 严格边界

- 本轮不创建或修改 `Source`、`Candidate`、`DecisionReceipt`、`MemoryVersion`，不更新 KBLite、公开上下文或访客查询域。
- 不自动结束或确认既有 review batch；暂停旧 thread 只建立生命周期围栏，review batch 仍需独立确认。
- 不新增 HTTP route、模型/Provider 调用、后台任务或公开 UI；普通 Echo 用户不可见内部状态、版本或切换原因。
- `ConversationThread` 被暂停后，只有显式的新 session start 才能恢复自然输入；这避免旧 thread 在异步回调或重试中继续接收消息。

## 实现与部署

- 后端提交：`DreamJourneyBackend main@23c807a`。
- 迁移：`0032_owner_truth_interview_topic_switch`，`expand`、`additive`。
- `ownerTruthConversationV1`、`guidedInterviewM0A`、`ownerTruthInterviewTopicSwitchM0A` 均保持默认 `false`。
- 服务器已 fast-forward、重建 API 容器、应用并验证 `0032`；生产 migration head 为 `0032`。

## 验证证据

- 定向：`python3 -m unittest tests.test_owner_truth_interview_topic_switch tests.test_owner_truth_interview_topic_switch_migration_contract`，3 项通过。
- 全量：`bash scripts/verify_backend.sh`，969 项后端单测、FastAPI smoke、静态/契约 gate 通过。
- `git diff --check` 和 Python 编译检查通过。
- 服务器 API 容器：`python scripts/migrate_db.py --apply --build-id 23c807a` 与 `--verify` 均为 `ready`，head=`0032`。
- 服务器 API 容器：`scripts/run-backend-owner-truth-conversation-postgres-smoke.sh` 通过。
  - 在隔离 Postgres 数据库中验证 topic switch 的 thread/session 双暂停、幂等 replay、暂停后旧线程拒绝写入、显式新 session 可启动、review batch 生命周期、重启恢复、owner/vault 隔离和禁止写入 Source/Candidate/MemoryVersion。
- `https://dreamjourney-api.liftora.cn/ready`：database、schema、auth、incident 均为 `ready`。

## 未完成与下一步

- 当前命令仅暂停旧 thread，不负责话题检测、恢复被暂停 thread 或创建 replacement topic。
- review batch 仍只表示“待查看边界”；尚未把已确认 batch 受控转换为 Candidate proposal，也没有实现部分接受、修正、拒绝或 MemoryVersion 激活。
- G1 公开/模拟器访谈体验、G3 Provider、G4 产品与外部验收仍未关闭。

下一子切片：`WI-S1-01-03-M0A-06-REVIEW_BATCH_TO_CANDIDATE_PROPOSAL_BOUNDARY`。目标是把已确认 review batch 接到既有 Owner Truth Candidate 权威入口的受控 admission/proposal 边界；必须逐项保留证据与用户确认，不得直接激活 `MemoryVersion` 或改变公开 Echo UI。
