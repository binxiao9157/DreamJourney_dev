# WI-S1-01-03 M0A-09：敏感/单条候选审核

日期：2026-07-20
状态：已完成、已部署；私有默认关闭，未接公开 Echo UI、真实 Provider 或 MemoryVersion 激活

## 本轮完成

- 为已确认且已 admission 的访谈复盘批次新增私有单条 Candidate 审核命令。
- `sensitive` Candidate 与显式 `reviewMode=single` 的普通 Candidate 可走单条 `accept`、`reject` 或 `correct`。
- 普通 `reviewMode=batch` Candidate 被明确拒绝进入单条命令，必须继续走部分批量确认。
- 单条命令复用既有 Candidate 的 Owner/CAS/不可变 `DecisionReceipt` 合同；根命令复用已存在的 value-minimized 账本，重放时不重新组合已经 terminal 的 Candidate。
- 单条 `correct` 使用 Candidate 自身已验证的内容 schema；不使用写死 schema，避免后续 ontology 演进产生静默漂移。

## 保持的边界

- 不调用 `activate_memory_version`，不创建 `MemoryRecord`、`MemoryVersion`、Projection 或 KBLite。
- 不新增公开路由、iOS UI、Provider 请求、后台 worker 或数据库 migration。
- root 命令与 review batch、admission、active vault、Owner、authority epoch 绑定；Candidate 终态决定仍在同一数据库 UoW 内执行 Source/Vault/CAS/receipt 校验。
- 回放只接受相同 command/payload/Owner/batch/selection count；修改语义的 command reuse fail closed。

## 代码与部署

- 后端提交：`main@85a5647`，已推送并部署。
- 主要模块：
  - `app/domain/owner_truth/interview_candidate_single_review.py`
  - `app/services/owner_truth_interview_candidate_single_review.py`
  - `tests/test_owner_truth_interview_candidate_single_review.py`
- 复用：`interview_review_batch_candidate_decisions` 根命令账本与既有 Candidate review repository；无新增 migration。

## 验证证据

- `bash scripts/verify_backend.sh`：990 项单测、FastAPI smoke、静态和契约 gate 通过。
- 定向单测覆盖：敏感单条接受、显式单条普通候选、批量候选拒绝绕过、CAS stale 拒绝、`correct`、terminal 后 root command 重放。
- `git diff --check` 与 Python 编译检查通过。
- 服务器：`main@85a5647`，迁移 apply/verify head=`0034`、`ready`。
- 服务器隔离 Postgres smoke：普通 batch Candidate 与敏感 single Candidate 各生成一条 `DecisionReceipt`，两类根命令重放均为 `deduplicated`；`memories` 与 `memory_versions` 均为 0。
- 线上 `/ready`：database、schema、auth、incident 均为 `ready`。

## 下一子切片

`WI-S1-01-04-G0-CANDIDATE_REVIEW_AUTHORITY_BASELINE`：盘点既有 Candidate review、MemoryVersion activation、correction 与 iOS typed review 入口的 authority gap；只先形成可验证的 G0 基线，不提前声明 G1/G2/G4 已完成。
