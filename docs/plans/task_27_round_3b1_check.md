# Round 3B1 核心数据与 authority 合同成功检查

## Summary

R021 满足 P028：核心和 optional aggregate 的逻辑字段、状态、版本、证据、owner/vault、约束与 legacy 映射均已定义，且 Source/Memory/Conversation authority 链可执行。未输出生产 DDL 是明确范围，不构成该文档级问题失败。

## Evidence

- Product Spec 第 24 节包含 38 个逻辑对象行和 9 个验收场景。
- 复合 vault FK、terminal decision unique、immutable MemoryVersion、active version composite FK 和 correction lineage 均有明确合同。
- data contract 静态检查通过。

## Criteria Map

- 核心字段/约束：24.1 至 24.7。
- Source → Candidate → Decision → MemoryVersion → Citation/Correction：24.4、24.5。
- 同 vault 约束与 owner 冲突：24.1、24.10。
- 状态/并发/receipt：24.3、24.4、24.10。
- JSONB 范围：24.1。
- optional 独立：24.8。

## Execution Map

- 从当前 Archive/KBLite/memories 冲突出发先定义 Vault/Subject，再构造 authority lineage，最后补 optional 和 legacy 映射。
- 对并发确认/纠正和删除传播增加独立验收场景，未只画 ER 概念图。

## Stress Test

- 不同 vault 使用相同 resource ID、跨 vault citation 均由 DB 约束拒绝。
- 同 command 重试复用 receipt，不同 command 并发 terminal decision 由 row lock + partial unique 阻断。
- Projection 全删可由 MemoryVersion event 重建。
- Optional schema 缺失时核心表无字段变化。

## Residual Risk

- DDL、RLS、索引/容量、migration/backfill 需 Round 3C 和实现任务验证。
- Round 3D 仍需独立数据/隐私审查。

## Result IDs

- R021
