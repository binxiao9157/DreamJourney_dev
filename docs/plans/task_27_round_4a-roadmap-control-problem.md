# Round 4A：路线图控制模型、阶段与依赖 DAG

## Problem

13 个稳定工作包缺少统一的路线图状态、任务字段、阶段门和依赖图。若各包直接独立扩写，容易形成相互矛盾的优先级、隐式外部门和第二套迁移 authority。

## Success Criteria

- 创建 V4 可执行路线图文件，并明确其权威边界、状态词典、任务字段和版本控制规则。
- 精确登记 13 个 package ID、CR 映射、主要阶段、优先级和 package 级依赖。
- 给出无环 DAG、critical path、Optional lane 关闭证明和 Owner 文字核心 release increment。
- 定义纯代码、模拟器、真实 Postgres/部署、Provider、真机/产品/法律五类验收门。
- 定义每个 Stage 的进入、退出、stop-the-line、rollback/forward-fix 和证据包要求。
- 只建立路线控制和骨架，不替后续子问题伪造 package 内具体任务。
