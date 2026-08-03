# Round 3C4B Runbook Evidence、Decision 与静态门

## Problem

组合 Runbook 需要被明确标记为推荐设计而非生产演练结果，并需要自动门防止 wave 字段、rollback plane、不可逆补偿和退役清单在后续编辑中丢失。

## Success Criteria

- Evidence Matrix 新增 Round 3C4 状态，区分设计、合同、决策和真实演练。
- Decision Register 映射 DR-040 及相关迁移/权限/Provider 决策；不因 Runbook 完成自动升级为 CONFIRMED。
- 新增组合 migration/rollback checker，验证章节、五个 plane、wave 编号、每 wave 九类字段、retirement 类型、go/no-go 字段和至少 18 个故障场景。
- 前述 data backfill/cutover、iOS account/store、API/AuthZ、Job/Outbox、Object/Media、Provider migration 检查继续通过。
- V4 docs、evidence matrix 和 `git diff --check` 通过，并保留真实 restore/canary/provider/生产 cutover 为未验收边界。
