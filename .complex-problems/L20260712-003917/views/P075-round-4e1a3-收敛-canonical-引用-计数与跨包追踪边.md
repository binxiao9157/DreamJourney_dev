# P075: Round 4E1A3：收敛 canonical 引用、计数与跨包追踪边

Status: done
Parent: P071
Root: P000
Source Ticket: T069 (split)
Source Check: none
Package: problems/P000/children/P004/children/P055/children/P069/children/P071/children/P075
Body: problems/P000/children/P004/children/P055/children/P069/children/P071/children/P075/README.md
Ticket(s): T072

## Problem
路线图仍混有 `FR-DH-*`、`FR-TIME-*`、`FR-FAM-*`、`FR-CARE`、`FR-MEDIA-*` 等非 canonical 或通配表达，并在 Voice/DH 工作项中误用表示“拒绝 AOS 组件”的 `DR-012`。部分 FR 与架构 finding 也缺少精确工作项边，导致后续追踪矩阵无法可靠判断覆盖、延迟或拒绝。

## Success Criteria
- 路线图中的 `FR-*` 精确 ID 只来自 36 个 canonical FR 集合；非 FR 产品范围必须使用 `SCOPE-*` 标签。
- Voice/DH 不再把 `DR-012` 当实施决定；仅允许以 `ENFORCES_REJECTION` 关系表达对 AOS 组件的拒绝。
- 补齐 `FR-ACC-001`、`FR-SAFE-002`、`IAR-06`、`IAR-07`、`SOR-04` 等已识别精确边，并清除非法 finding 引用。
- `FR-MEM-003/004` 明确标记 `DEFERRED_BY_GATE`，不为追求覆盖率提前创建实现任务。
- 路线总计更新为 115 项/1840 字段，并与 Stage 0、Stage 1、Round 4D 检查器一致。

## Subproblems
- none

## Results
- R067

## Latest Check
C070

## Bodies
- Problem: problems/P000/children/P004/children/P055/children/P069/children/P071/children/P075/README.md
- Ticket T072: problems/P000/children/P004/children/P055/children/P069/children/P071/children/P075/tickets/T072.md
- Result R067: problems/P000/children/P004/children/P055/children/P069/children/P071/children/P075/results/R067.md
- Check C070: problems/P000/children/P004/children/P055/children/P069/children/P071/children/P075/checks/C070.md

## Follow-ups
- none
