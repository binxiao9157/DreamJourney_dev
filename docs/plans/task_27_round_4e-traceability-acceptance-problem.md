# Round 4E：路线追踪、静态验收与下一个任务选择规则

## Problem

路线图完成后必须证明 36 FR、41 DR、22 finding、12 canonical risk 和 13 package 全部可追踪，并能稳定选择下一个小闭环；人工浏览无法防止遗漏、循环依赖、开放决策误标完成或字段退化。

## Success Criteria

- 建立 FR/DR/finding/CR/package/work item 的完整追踪矩阵，开放 DR 与外部门不被标为已关闭。
- 新增 `product-v4-roadmap-check.py`，精确验证 13 package、work item 唯一 ID、必填字段、合法优先级/验收门、依赖引用与无环关系。
- 检查 P0 不含后置能力、Optional lane default-off、Owner core 独立发布和 `WP-MIG-01` 非第二 Authority。
- 路线图定义“下一个最高优先级小闭环”的确定性选择规则，以及状态变更、证据失效和重新规划规则。
- 全部 Product V4 checks、链接检查、路线图检查与 `git diff --check` 通过。
