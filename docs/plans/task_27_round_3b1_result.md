# Round 3B1 核心数据与 authority 合同结果

## Summary

已将 V4 领域词典落为逻辑关系数据合同：使用随机 Subject 与 Owner Vault 隔离，建立 Source → Candidate → DecisionReceipt → immutable MemoryVersion → Citation/Correction lineage，并为 Projection、Conversation、DataRights 和 Optional Domain 定义独立 authority 边界。该合同可指导后续 DDL/API，不等同于 migration 已实现。

## Done

- 定义 UUID、vault/owner、复合 FK、row version、state/time/delete、JSONB allowlist 和 secret 禁止规则。
- 定义 Identity/Vault/授权、Source、Memory、Conversation、Projection、DataRights/Audit 共 38 个逻辑对象行。
- 定义 Candidate terminal partial unique、DecisionReceipt idempotency、MemoryVersion immutable 与 active-version composite FK。
- 定义 assistant/Visitor output 不自动成为 Source，Correction 必须引用 answer/citation/old version。
- 定义 Publication/Visitor、Voice/DH、Family/Care、TimeLetter 独立可选数据边界。
- 定义 9 类 Legacy 数据映射与 9 个跨 vault、并发、删除、projection 验收场景。
- 新增 `product-v4-data-contract-check.py` 固化章节、对象、约束、optional boundary 和验收数量。

## Verification

- data contract check 通过：38 logical rows、9 acceptance scenarios。
- Product V4 docs check 通过。
- `git diff --check` 通过。
- 当前后端 18 表/JSONB 证据用于反向验证目标没有把 legacy projection 当 authority。

## Known Gaps

- 本轮是逻辑 schema，不是完整 SQL DDL、索引容量或 migration 文件。
- 是否启用 Postgres RLS 仍需 Stage 0 ADR；复合 vault FK/AuthZ/repository scope 不依赖该决定。
- 独立数据 reviewer 未在限定时间内返回，已停止；Round 3D 必须专项检查字段/约束和第三方权利。
- API authorization、job/outbox/provider 字段分别由 P029/P030 完成。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `Scripts/QA/product-v4/product-v4-data-contract-check.py`
- `docs/plans/task_27_round_3b1-data-authority-contracts.md`
- `docs/plans/task_27_round_3b1_solution.md`
- `docs/plans/task_27_round_3b1_result.md`
