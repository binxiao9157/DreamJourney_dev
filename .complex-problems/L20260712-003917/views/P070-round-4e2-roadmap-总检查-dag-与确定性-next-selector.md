# P070: Round 4E2：Roadmap 总检查、DAG 与确定性 Next Selector

Status: done
Parent: P055
Root: P000
Source Ticket: T067 (split)
Source Check: none
Package: problems/P000/children/P004/children/P055/children/P070
Body: problems/P000/children/P004/children/P055/children/P070/README.md
Ticket(s): T077

## Problem
现有检查分别覆盖产品文档、架构、Stage1和Optional/Migration，但没有一个总检查解析13 package、全部Work Item、16字段、依赖、priority/gates/DAG和next-action规则，也无法在incident、证据过期或状态变化时确定性重排。

## Success Criteria
- 新增`product-v4-roadmap-check.py`，验证13 package、全部Work Item唯一/连续、16字段、合法状态/priority/lane/gate、依赖引用和无环关系。
- 检查P0不含后置能力、Optional default-off、Owner text core独立、MIG不拥有业务状态、G0/G1不关闭G2–G4。
- 路线图新增全局确定性next selector、状态transition、evidence expiry、incident/blocker和replan规则。
- 更新header/第6节为Round4工作项与验收完成但仍待Round5独立复审，不误报工程实现。
- 全部Product V4/links/roadmap checks与`git diff --check`通过。

## Subproblems
- P079: Round 4E2A：路线执行注册表与确定性 Next Selector
- P080: Round 4E2B：Roadmap 总 Checker 与负向验收

## Results
- R080

## Latest Check
C084

## Bodies
- Problem: problems/P000/children/P004/children/P055/children/P070/README.md
- Ticket T077: problems/P000/children/P004/children/P055/children/P070/tickets/T077.md
- Result R080: problems/P000/children/P004/children/P055/children/P070/results/R080.md
- Check C084: problems/P000/children/P004/children/P055/children/P070/checks/C084.md

## Follow-ups
- none
