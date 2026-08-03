# Round 4E2：Roadmap 总检查、DAG 与确定性 Next Selector

## Problem

现有检查分别覆盖产品文档、架构、Stage1和Optional/Migration，但没有一个总检查解析13 package、全部Work Item、16字段、依赖、priority/gates/DAG和next-action规则，也无法在incident、证据过期或状态变化时确定性重排。

## Success Criteria

- 新增`product-v4-roadmap-check.py`，验证13 package、全部Work Item唯一/连续、16字段、合法状态/priority/lane/gate、依赖引用和无环关系。
- 检查P0不含后置能力、Optional default-off、Owner text core独立、MIG不拥有业务状态、G0/G1不关闭G2–G4。
- 路线图新增全局确定性next selector、状态transition、evidence expiry、incident/blocker和replan规则。
- 更新header/第6节为Round4工作项与验收完成但仍待Round5独立复审，不误报工程实现。
- 全部Product V4/links/roadmap checks与`git diff --check`通过。
