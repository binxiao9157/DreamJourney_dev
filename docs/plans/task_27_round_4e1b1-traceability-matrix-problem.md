# Round 4E1B1：建立V4路线追踪矩阵与生成器

## Problem

FR、DR、finding、CR、package与115个Work Item仍分散在多个文档中，缺少一份可阅读、可重建的双向注册表。手工维护115行容易漂移，需要由权威源生成确定性快照，同时保留人工关系例外。

## Success Criteria

- 新增`DreamJourney_V4_路线追踪矩阵_V1.0.md`，包含36 FR、41 DR、22 finding、12 CR、13 package、115 WI和关系说明。
- 新增确定性生成器，从Product Spec、证据矩阵、登记册、评审响应和roadmap抽取结构；重复运行无差异。
- 每个WI记录父package、精确FR/DR/finding/CR、状态上限、owner角色、gate集合和反向关系。
- FR deferred/rejected、DR open/external/rejected/confirmed与finding多package关系不被强行改成implementation完成。
- 文档明确当前没有FR为PROD_VERIFIED，矩阵生成不升级工程事实。
