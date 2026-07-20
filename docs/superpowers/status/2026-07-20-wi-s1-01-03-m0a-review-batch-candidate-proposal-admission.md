# WI-S1-01-03 M0-A 已确认复盘批次到 Candidate 提案边界

日期：2026-07-20
状态：已完成本子切片；私有、默认关闭，未接公开 Echo UI、模型或 Provider

## 本轮范围

- 新增显式 Owner 命令 `admitInterviewReviewBatchForCandidateProposal`。只有状态为 `acknowledged` 的 review batch 才可进入该命令；查看/确认 batch 本身不会自动创建 Source。
- 命令只收集该 frozen batch 内的 `owner` message，生成一条不可变 `SourceKind.conversation` Source；assistant/system message 不会成为候选证据。
- 新增 append-only `owner_truth.interview_review_batch_candidate_admissions`，以 review batch、conversation Source 与既有 `ownerTruth.source.created` / `candidateExtraction` effect 相连。
- Source metadata 只保留 batch/thread/session、消息数量与序列范围等 provenance；不复制原始消息正文到 metadata、effect 或 public receipt。
- 已复用既有 Candidate extraction effect 合同，worker/provider 仍默认关闭；本轮没有实际模型生成或公开路由。

## 严格边界

- admission 要求同一 active Vault、同一 Owner、authority epoch、已确认 batch 和 review-batch 版本 CAS；command replay 幂等，一条 batch 最多一条 admission。
- 数据库触发器再次校验 batch 已确认、Source 属于同一 owner/vault、Source type 为 `conversation`、Source 为 active，且 metadata 的 `reviewBatchId` 匹配。
- 本轮只创建 Source 与 default-off extraction effect；不创建 `memory_candidates`、Candidate decision、`decision_receipts`、`memories`、`memory_versions`、projection、KBLite 或访客查询数据。
- 不新增 HTTP route、后台 provider worker、模型请求或公开 Echo UI，因此普通用户默认不可见。

## 实现与部署

- 后端提交：`DreamJourneyBackend main@0174aa1`，已推送并部署。
- 迁移：`0033_owner_truth_interview_candidate_proposal_admission`，`expand`、`additive`。
- `ownerTruthConversationV1`、`guidedInterviewM0A`、`ownerTruthInterviewCandidateProposalM0A` 均保持默认 `false`。
- 对已有普通 text Source 保持原 command/source hash 形状；只有新的 conversation Source 显式写入 `sourceKind=conversation`。
- 服务器 API 容器已应用并验证 migration head=`0033`。

## 验证证据

- 定向单测：新 admission、迁移合同、review batch、topic switch、Candidate extraction 共 15 项通过。
- 全量：`bash scripts/verify_backend.sh` 通过，974 项后端单测、FastAPI smoke 和静态/契约 gate 均通过。
- `git diff --check` 与 Python 编译检查通过。
- 服务器 API 容器：`python scripts/migrate_db.py --apply --build-id 0174aa1` 与 `--verify` 为 `ready`，head=`0033`。
- 服务器 API 容器：`scripts/run-backend-owner-truth-conversation-postgres-smoke.sh` 通过。
  - 隔离 Postgres 中确认：ack 前 Source 数量为 0；显式 admission 后恰有一条 conversation Source 和一条 extraction effect；重放幂等；候选、决策回执、MemoryVersion 均为 0；重启后访谈状态仍可读取。
- `https://dreamjourney-api.liftora.cn/ready`：database、schema、auth、incident 均为 `ready`。

## 未完成与下一步

- 该 effect 仍未由真实 provider/worker 消费，尚未根据访谈文本生成实际 Candidate proposal。
- 现有单 Candidate review/activation 合同仍未组成 review-batch 的部分接受体验；敏感候选逐条确认也尚未接入 M0-A 组合边界。
- G1 公开/模拟器访谈体验、G3 Provider、G4 产品与外部验收仍未关闭。

下一子切片：`WI-S1-01-03-M0A-07-CANDIDATE_BATCH_REVIEW_COMPOSITION_BOUNDARY`。目标是在不启用 Provider、不开公开 UI 的前提下，将 admission 产生的候选按 batch 组成可审计的 review composition，并明确部分接受与敏感候选逐条确认的已有 Authority 调用边界；不得直接激活 `MemoryVersion`。
