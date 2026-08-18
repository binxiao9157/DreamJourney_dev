# DreamJourney 产品文档权威源

状态：`CANONICAL_WORKING_SOURCE / PRODUCT_CONFIRMED_2026-08-18_ALIGNED`

本目录是 DreamJourney V4 产品、架构和工程事实文档的唯一可编辑工作源。交付快照、历史评审和任务过程记录不得反向覆盖本目录。

## 当前权威顺序

发生冲突时按以下顺序判断：

1. `寻梦环游_产品确认版整体概要设计_2026-08-17.md`：今天提供的第一份输入，作为目标产品与概要设计主文档。
2. `寻梦环游_当前代码产品PRD_2026-08-17-产品已确认点.md`：今天提供的第二份输入，作为产品确认来源记录。
3. `寻梦环游_产品确认版待明确与完善清单_2026-08-18.md`：产品方对 PCQ-01 至 PCQ-13 的确认记录，包含 2026-08-18 补充澄清和确认附件哈希。
4. `寻梦环游_产品确认版PRD_2026-08-18.md`：由两份初始输入和已确认 PCQ 归一化产生的日常需求入口。
5. `寻梦环游_产品确认版当前实现证据矩阵_2026-08-18.md`：仅以确认产品输入和当前 iOS `09394f98`、Backend `b472b6d` 代码扫描生成的工程事实。
6. `../superpowers/plans/2026-08-18-dreamjourney-product-confirmed-gap-01-13-execution-plan.md`：仅由概要设计 GAP、确认版 PRD、PCQ 决策和当前代码证据生成的执行计划；Work Item 执行卡、UI 设计依据、部署运行态快照、API/迁移合同、验收证据和回滚规范均收敛在该文件内，不再建立平行计划。

PCQ 决策记录已于 2026-08-18 标记 `CONFIRMED_2026-08-18`。后续若改变其中结论，必须保留新的确认主体、日期、凭证和工程回写，不得直接覆盖历史结论。

`docs/superpowers/plans` 是既有路线图兼容路径，不依赖已安装的 Codex plugin 或 skill。

## 非本轮输入材料

目录内其他 V4 Product Spec、决策登记册、历史路线图、成果物快照和状态 ledger 均不参与本轮产品范围推导，也不得向当前确认链追加需求。只有用户后续明确要求引用时，才单独评估其内容。

## 修改流程

1. 只在本目录和路线图工作路径修改权威文档。
2. 产品范围变化先更新确认版 PRD 和概要设计，再更新当前实现证据矩阵与 GAP 计划。
3. 不运行旧 V4 生成器覆盖当前确认版文档。
4. 运行当前确认版权威源守卫和链接检查。
5. 需要新交付包时，从已验证的权威源重新生成新的日期快照；不得把旧快照复制回工作源。

```bash
python3 Scripts/QA/product-v4/product-v4-canonical-source-check.py
python3 Scripts/QA/product-v4/product-v4-links-check.py
```

当前产品确认版的工程审计基线是 iOS `feature/prd-stitch-ui-adaptation@09394f98` 和 Backend `main@b472b6d`；不能只替换提交号来提升成熟度，必须同步更新实现证据。
