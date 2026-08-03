# 建立独立终态检查器并完成全量静态验收

## Problem Definition

局部 checker 已能验证各阶段合同，但缺少一个最终入口把五份成果物、两轮复审、23 条 disposition、22 条 Wave 2 validation、互链、派生物 freshness 和不过度声明边界放在同一验收面。

## Proposed Solution

- 新增 `product-v4-finalization-check.py`，独立读取五份固定成果物、两轮 review、Wave 2 索引、Trace 和 Registry。
- 默认检查精确计数、ID 集合、状态、互链、代码基线、`R5C-PROD-001` 修复、`R5A-ENG-008` 保留及 Registry source hash/freshness。
- `--self-test` 使用内存 fixture 逐项破坏至少 9 类合同并要求 checker 拒绝。
- 运行所有生成器 self-test/check、全部非生成器 checker、双次生成 hash、链接、敏感信息和 diff gate。

## Acceptance Criteria

- 默认 finalization check 为 0 errors。
- self-test baseline=0，至少 9 个负向 fixture 均产生预期错误。
- 精确验证 5 artifacts、Wave1=23、Wave2 expected/covered/verified/challenged=22/22/22/0、36/41/22/12/13/115/1840。
- 检出缺成果物、缺 review wave、P0 未处置、P1 无 Gate/Owner、外部门误关、计数漂移、断链、派生物 stale、实现过度声明。
- 全量 Product V4 checks、双次生成确定性、敏感信息、链接和 `git diff --check` 通过。

## Verification Plan

运行 checker 默认与 `--self-test`；运行现有全套脚本；在临时目录重复生成 Trace/Registry 或比较连续生成 hash；用受限敏感模式扫描成果物；运行链接和 diff gate。

## Risks

最终 checker 不能复制生成器逻辑后自证；应独立解析最关键终态不变量，并复用 Registry 中的 canonical source hash 只做一致性比较。

## Assumptions

当前工作树不提交，artifact commit 风险必须继续为开放状态。
