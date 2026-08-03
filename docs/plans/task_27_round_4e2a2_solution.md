# 在 Roadmap 固化安全的确定性 Selector 与失效重排规则

## Problem Definition

Execution Registry 已提供 typed facts，但还没有权威算法解释这些 facts 如何变成唯一下一动作。尤其当前全部任务都是 `STOP/NO_GO/UNASSIGNED`，若把排序第一项直接当作执行授权，会绕过 Owner、Authority lock、依赖和外部门。Roadmap 状态也需要区分“工作项/分项静态验收完成”与“总 checker/独立复审完成”。

## Proposed Solution

在 Roadmap 第6节新增四部分：

1. Registry 权威边界和有限枚举：JSON 是 Roadmap 的生成视图，source hash 不一致即 stale；产品范围仍由五层权威源和 16 字段 Work Item 决定。
2. 两阶段 selector：先计算 `planningCandidate`，再判断是否可 `EXECUTE`。`STOP/NO_GO/UNASSIGNED` 只能输出 `PLAN_ASSIGN_OWNER` 或 `NO_EXECUTABLE_ACTION`；只有 `GO + owner + authority lock + start dependencies` 完整才可执行。
3. 确定性排序：stop-line incident 优先；CORE 优先于 MIGRATION inventory，Optional 只有外部 decision/flag 后进入；然后按 selectorBand、priorityClass、stableRank、ID 排序。相同输入必须唯一。
4. 失效与 replan：incident、evidence `FAIL/EXPIRED/MISSING`、依赖回退、open/revoked decision、owner/lock丢失、source hash变化分别定义状态 ceiling、PAUSED、fallback 和重新选择。

当前 baseline 明确输出 `PLAN_ASSIGN_OWNER:WI-S0-03-01`，理由是 P0 CORE、无 start dependency、Credential Stop-Loss band=0；`WI-MIG-01-01` 是次级只读 inventory 候选，不得抢占止损任务。Header/第6节先标“Round 4 工作项与分项静态验收完成、E2B 总 checker 待通过”，P080 通过后再把总验收标完成；始终保留 Working Draft/待 Round 5 和“非工程实现”说明。

## Acceptance Criteria

- Roadmap 链接 registry 并明确 source hash/stale/权威边界，不形成 hash 自引用。
- selector 过滤、action 类型、排序 tuple、tie-break 和 baseline 输出完整且机器可解析。
- 当前只有 `PLAN_ASSIGN_OWNER:WI-S0-03-01`；没有 `EXECUTE/GO/IN_PROGRESS/VERIFIED` 越权。
- `WI-MIG-01-01` 仅为并行只读 inventory 候选；MIG 不能拥有业务 Authority。
- incident/evidence/decision/dependency/owner/lock/source drift 的状态降级和 replan 规则无歧义。
- G0/G1、文档、模拟器或 generic build 不会关闭 G2-G4。
- Header/第6节准确表达分项完成、总 checker 待 E2B、Round 5 待审和不代表工程实现。

## Verification Plan

人工按算法从 registry 复算 baseline；构造 owner/GO、incident、expired G3、Optional default-off、dependency rollback 五个表格例子；重新生成 registry 以更新 source hash并运行 `--check`；运行 traceability/canonical/links/docs checks 和 diff gate。P080 再以独立代码做总负向验收。

## Risks

- Planning action 容易被误读为执行指令，必须在名称、状态和文案三处明确不授权实现。
- incident 可以产生 stop-line 而非普通 WI；算法必须先返回 `STOP_THE_LINE`，不能继续选业务任务。
- Header 不能提前宣称 P080 已通过。

## Assumptions

- 当前 registry baseline 的所有 evidence 为 MISSING、owner 为 UNASSIGNED、决策为 STOP/NO_GO。
- Round 4E2B 完成后由父问题负责最终 header 状态收敛。
