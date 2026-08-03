# Round 5D2：终态检查器与全量静态验收

## Problem

现有 checker 分别验证 Trace、Roadmap、review disposition 等局部合同，但没有一个独立终态门同时约束五份成果物、两轮复审、处置完整性、链接、派生物 fresh 与工程成熟度不过度声明。

## Success Criteria

- 新增 finalization checker，默认检查五份成果物、两轮 review、Round 5A/5C 集合、互链、计数、Registry/Trace 和状态边界。
- negative self-test 至少覆盖：缺成果物、缺 review wave、P0 未处置、P1 无 Gate/Owner、外部门误关、计数漂移、断链、派生物 stale、工程完成度过度声明。
- 全量 Product V4 checker 与生成器 self-test/check 通过。
- 双次生成 hash 一致，敏感信息扫描、链接和 `git diff --check` 通过。
- 输出最终验收证据与残余风险，不把静态验收解释为 115 个工程工作项完成。

## Boundary

不为让检查器变绿而弱化现有状态、删除开放风险或修改生产代码；不声称未提交工作树已经通过 clean checkout。
