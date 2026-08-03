# Round 4E1A3：收敛 canonical 引用、计数与跨包追踪边

## Problem

路线图仍混有 `FR-DH-*`、`FR-TIME-*`、`FR-FAM-*`、`FR-CARE`、`FR-MEDIA-*` 等非 canonical 或通配表达，并在 Voice/DH 工作项中误用表示“拒绝 AOS 组件”的 `DR-012`。部分 FR 与架构 finding 也缺少精确工作项边，导致后续追踪矩阵无法可靠判断覆盖、延迟或拒绝。

## Success Criteria

- 路线图中的 `FR-*` 精确 ID 只来自 36 个 canonical FR 集合；非 FR 产品范围必须使用 `SCOPE-*` 标签。
- Voice/DH 不再把 `DR-012` 当实施决定；仅允许以 `ENFORCES_REJECTION` 关系表达对 AOS 组件的拒绝。
- 补齐 `FR-ACC-001`、`FR-SAFE-002`、`IAR-06`、`IAR-07`、`SOR-04` 等已识别精确边，并清除非法 finding 引用。
- `FR-MEM-003/004` 明确标记 `DEFERRED_BY_GATE`，不为追求覆盖率提前创建实现任务。
- 路线总计更新为 115 项/1840 字段，并与 Stage 0、Stage 1、Round 4D 检查器一致。

## Verification

- 从 Product Spec/证据矩阵提取 canonical FR/DR/finding 集合，与路线图做集合差异检查。
- 搜索所有伪 ID、通配 FR、`DR-012` 和非法 BAR 引用。
- 运行全部 `Scripts/QA/product-v4` 检查及 `git diff --check`。

## Boundaries

- 不为了形式覆盖强行把拒绝、外部门或 deferred 目标映射成 implementation Work Item。
- 不改变已经确认的产品决定状态，只修正引用关系和路线语义。
