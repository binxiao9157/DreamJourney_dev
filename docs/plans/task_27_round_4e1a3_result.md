# Canonical 引用、计数与跨包追踪边收敛结果

## Summary

路线图已统一到36个canonical FR，并用`SCOPE-*`替代Family/Care/TimeLetter/Digital Human/Media等非FR范围标签；Voice/DH对`DR-012`的错误实施引用已清除，关键FR/finding边和Stage4 deferred关系已显式登记。

## Done

- 清除全部`FR-DH/FR-FAM/FR-TIME/FR-MEDIA`伪ID、FR范围和通配写法。
- 所有36个FR都在路线中出现；`FR-MEM-003/004`使用`DEFERRED_BY_GATE`而非伪造实施任务。
- `FR-ACC-001`映射到`WI-S0-02-01`，`FR-SAFE-002`映射到`WI-S3-01-06`。
- `IAR-06`分别下钻到S1-01与MIG，`IAR-07`下钻S1-03，`SOR-04`下钻V0。
- 从所有Voice/DH Work Item移除`DR-012`，仅保留`ENFORCES_REJECTION -> SCOPE-AOS-COMPONENTS`。
- 清除隐藏在`BAR-05/08`中的非法BAR-08。
- 路线总数声明为115个Work Item/1840字段。
- 新增canonical roadmap checker及内置负向self-test。

## Verification

- canonical checker/self-test通过：36 FR、41 DR权威集、22 finding权威集、115 Work Item、1840字段。
- 负向样本正确拒绝伪FR、Voice DR-012、缺失IAR-06边和错误总数。
- 全部20个Product V4检查通过。
- `git diff --check`通过。

## Known Gaps

- 本项只保证ID与关键边可靠；完整FR/DR/finding/CR/package/WI双向矩阵、状态、owner、gate/evidence仍由P072完成。
- 路线中部分CR/DR/finding仍使用人类可读组合表达；P070总checker会用独立机器注册表收敛依赖与状态，不在本项重写115项全部字段。

## Artifacts

- `docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md`
- `Scripts/QA/product-v4/product-v4-roadmap-canonical-reference-check.py`
- `docs/plans/task_27_round_4e1a3_solution.md`
