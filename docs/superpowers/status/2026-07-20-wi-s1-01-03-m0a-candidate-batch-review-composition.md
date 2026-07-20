# WI-S1-01-03 M0A-07：访谈候选审核分组

日期：2026-07-20
状态：已完成、已部署；私有默认关闭，未接公开 Echo UI、真实 Provider 或 MemoryVersion 激活

## 本轮完成

- 已确认的访谈复盘批次可只读组成候选审核视图。
- 普通、显式 `reviewMode=batch` 的 pending Candidate 归入批量审核；敏感或未显式声明 batch 的 Candidate 一律归入单条审核，默认收紧。
- 已把 text-bearing `conversation` Source 纳入既有候选抽取入口，使 M0A-06 产生的会话 Source 能复用既有抽取合同。
- 组合结果只输出候选标识、版本、类别和审核路径；`public_summary()` 不含候选正文或访谈正文。

## 保持的边界

- 只读组合不写 Candidate decision、DecisionReceipt、Memory、MemoryVersion、Projection 或 KBLite。
- 不新增公开路由、Provider 调用、后台 worker 或 iOS UI。
- owner/vault/authority、已确认 review batch、admission provenance、active Source 和 pending extraction result 均须匹配；任一不满足即不组成可审核候选。

## 代码与部署

- 后端提交：`main@93bf9ad`（组合实现）、`main@d45eda3`（线上 smoke fixture 修正）。
- 服务器已运行：`d45eda3`；迁移 head 保持 `0033`，本轮无需新增迁移。
- 主要模块：
  - `app/domain/owner_truth/interview_candidate_review.py`
  - `app/services/owner_truth_interview_candidate_review.py`
  - `app/services/owner_truth_candidate_extraction.py`
  - `scripts/backend-owner-truth-conversation-postgres-smoke.py`

## 验证证据

- `bash scripts/verify_backend.sh`：978 项测试、FastAPI smoke、静态与契约检查通过。
- `git diff --check` 与 Python 编译检查通过。
- 部署后隔离 Postgres smoke：已确认 batch -> conversation Source -> 两个 synthetic Candidate；普通候选为 batch、敏感候选为 single；`memory_candidates` 为 2，`decision_receipts`、`memories`、`memory_versions` 均为 0。
- 线上 `/ready`：database、schema、auth、incident 均为 `ready`。

## 下一子切片

`WI-S1-01-03-M0A-08-PARTIAL_STANDARD_CANDIDATE_DECISION_BOUNDARY`：仅允许已组成 batch 的普通候选做显式、部分接受；敏感候选保持单条审核；复用既有 Candidate 决策/CAS/DecisionReceipt 合同，绝不自动激活 MemoryVersion。
