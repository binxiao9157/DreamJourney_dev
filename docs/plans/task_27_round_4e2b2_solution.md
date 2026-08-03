# 在全量门通过后发布 Round 4 静态验收状态

## Problem Definition

总checker已通过pending baseline，但状态发布会修改Roadmap并使Execution Registry source hash失效，也可能触发旧header checker。必须先验、更新、重生成、再验，避免状态自签或留下stale生成物。

## Proposed Solution

1. 在pending状态运行registry/trace生成检查、roadmap/trace checker、全部Product V4非生成脚本和diff gate。
2. 全绿后更新Roadmap header、Round4E表和selector baseline为`ROUND4_STATIC_ACCEPTANCE_PASSED_ROUND5_PENDING`，明确Working Draft、非工程实现、非发布批准。
3. 更新只校验历史pending文案的Stage1/Optional checker和总checker，使其严格要求最终Round4/Round5边界。
4. 重新生成Execution Registry与Trace Matrix，分别连续两次生成并比较SHA-256；运行`--check`、独立checker、全部非生成脚本和diff gate。

## Acceptance Criteria

- 状态更新前全量检查通过；失败则不更新Header。
- Header、Round4E表、baseline JSON三处一致为Round4静态验收通过、Round5待审。
- Registry source hash fresh，Registry/Trace双次hash稳定。
- 全部Product V4非生成脚本通过，negative self-tests仍通过，`git diff --check`通过。
- 文案明确：静态验收只证明成果物内部一致，不代表115个WI已实现、部署、通过G2-G4或可发布。

## Verification Plan

统计并运行所有`Scripts/QA/product-v4/*.py`：生成器执行self-test/双次hash/check，其他脚本默认执行；额外运行trace/roadmap `--self-test`和diff gate。搜索残留`E2B_TOTAL_CHECK_PENDING`与旧Header文案，允许只存在于历史result文件，不允许存在最终Roadmap/active checker断言。

## Risks

- Roadmap任何字符变化都会更新registry hash；最后一次编辑后必须重生成。
- Checker若同时接受pending和passed会失去发布门价值；最终版本应严格要求passed/Round5 pending。
- Round5尚未运行，不能把Working Draft改成Final Approved。

## Assumptions

- 本票只发布文档静态验收状态，不提交或推送代码。
- Round5将独立复审五份成果物并生成最终评审与验收清单。
