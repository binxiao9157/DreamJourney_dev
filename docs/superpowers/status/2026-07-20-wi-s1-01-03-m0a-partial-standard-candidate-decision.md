# WI-S1-01-03 M0A-08：普通候选部分确认

日期：2026-07-20
状态：已完成、已部署；私有默认关闭，未接公开 Echo UI、真实 Provider 或 MemoryVersion 激活

## 本轮完成

- 为已确认、已 admission 的访谈复盘批次新增私有“部分接受”命令。
- 仅显式选择的普通 batch Candidate 可被接受；未选择的普通候选继续 pending。
- 敏感或显式 single Candidate 一律拒绝进入批量命令，保留单条审核路径。
- 每个选中的 Candidate 复用既有 CAS 和不可变 `DecisionReceipt`；新增的批次命令账本只保存 command/payload hash、数量、owner 和 authority epoch，不保存候选正文。
- 同一 root command 重放时严格校验语义，不会新增 `DecisionReceipt`。

## 保持的边界

- 不调用 `activate_memory_version`，不创建 `MemoryRecord`、`MemoryVersion`、Projection 或 KBLite。
- 不新增公开路由、iOS UI、Provider 请求或后台 worker。
- root 命令与 review batch/admission/current authority 绑定；Candidate 决策仍在同一数据库 UoW 内逐条检查 Source、Vault、CAS 和回执幂等。

## 代码与部署

- 后端提交：`main@ef32088`，已推送并部署。
- 新增 migration：`0034_owner_truth_interview_candidate_batch_decisions`，`expand`、`additive`、默认 feature flags 全部关闭。
- 主要模块：
  - `app/domain/owner_truth/interview_candidate_batch_decision.py`
  - `app/services/owner_truth_interview_candidate_batch_decision.py`
  - `db/migrations/0034_owner_truth_interview_candidate_batch_decisions.sql`

## 验证证据

- `bash scripts/verify_backend.sh`：984 项单测、FastAPI smoke、静态和契约 gate 通过。
- `git diff --check` 与 Python 编译检查通过。
- 服务器迁移 apply/verify：head=`0034`，状态 `ready`。
- 服务器隔离 Postgres smoke：标准 Candidate 仅生成一条 `DecisionReceipt`，重放为 deduplicated；敏感 Candidate 仍在 single review；`memories` 与 `memory_versions` 均为 0。
- 线上 `/ready`：database、schema、auth、incident 均为 `ready`。

## 下一子切片

`WI-S1-01-03-M0A-09-SENSITIVE_CANDIDATE_SINGLE_REVIEW_BOUNDARY`：为 admitted review batch 中的 sensitive/single Candidate 固定私有单条审核入口，继续复用既有决策/CAS/回执合同，不自动激活 MemoryVersion，也不开放公开 UI。
