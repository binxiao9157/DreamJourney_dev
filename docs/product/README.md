# DreamJourney 产品文档权威源

状态：`CANONICAL_WORKING_SOURCE / FINAL_REQUIREMENT_2026-07-16_ALIGNED`

本目录是 DreamJourney V4 产品、架构和工程事实文档的唯一可编辑工作源。交付快照、历史评审和任务过程记录不得反向覆盖本目录。

## 权威顺序

发生冲突时按以下顺序判断：

1. `DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`：V4.4 产品目标、M0-M4 边界、领域模型和目标架构。
2. `寻梦环游_产品问题风险分级与整体规避方案_V1.0.md`：新规硬拒绝、阶段 Gate 和风险边界；冲突时采用更严格约束。
3. `DreamJourney_V4_引导式访谈与知识丰满化功能说明_V1.0.md`：`GIC-001..016` 的交互、Authority 和验收合同。
4. `DreamJourney_V4_产品决策登记册_V1.0.md`：已确认、待确认、外部依赖、拒绝和延期决定。
5. `DreamJourney_V4_当前实现证据矩阵_V1.0.md`：冻结提交上的当前工程事实，不因目标文档更新而自动提升成熟度。
6. `../superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md`：115 个 Work Item 的依赖、Gate 和停止条件。
7. `DreamJourney_V4_评审与验收清单_V1.0.md`：评审处置与静态验收控制面。

`docs/superpowers/plans` 是既有路线图兼容路径，不依赖已安装的 Codex plugin 或 skill。

## 派生与参考材料

- `DreamJourney_V4_开发前问题与决策收敛清单_V1.0.md` 记录 2026-07-15 五项产品细节的历史确认回执；2026-07-16 新规和引导式访谈口径已覆盖其中冲突项。
- `../superpowers/plans/2026-07-17-dreamjourney-v4-final-requirements-execution-plan.md` 是当前唯一日常执行入口；2026-07-15 计划仅保留为历史。
- `DreamJourney_V4_路线追踪矩阵_V1.0.md` 与 `DreamJourney_V4_路线执行注册表_V1.0.json` 是生成产物，不应手工编辑。
- `reviews/` 和 Round 2/3 文档是评审证据，不覆盖 Product Spec 或决策登记册。
- PRD、V3 Blueprint、Hermes/AOS 分析和历史一致性分析是输入材料，不是 V4 当前实现证明。
- `../DreamJourney_V4_成果物_2026-07-16/` 是 `FINAL_REQUIREMENT_SNAPSHOT_NON_CANONICAL`，用于终版需求快照和审计；本文目录仍是唯一可编辑 working source。
- `../DreamJourney_V4_成果物_2026-07-15/` 是被 7 月 16 日增量覆盖的历史快照。

## 修改流程

1. 只在本目录和路线图工作路径修改权威文档。
2. 运行生成器刷新 Trace 和 Registry。
3. 运行权威源守卫、最终静态验收和链接检查。
4. 需要新交付包时，从已验证的权威源重新生成新的日期快照；不得把旧快照复制回工作源。

```bash
python3 Scripts/QA/product-v4/generate-product-v4-traceability-matrix.py
python3 Scripts/QA/product-v4/generate-product-v4-execution-registry.py
python3 Scripts/QA/product-v4/product-v4-canonical-source-check.py
python3 Scripts/QA/product-v4/product-v4-finalization-check.py
python3 Scripts/QA/product-v4/product-v4-links-check.py
```

终版需求包的工程审计基线是 iOS `feature/prd-stitch-ui-adaptation@8a1922b` 和 Backend `main@4c0538b`。当前工程续接点和后续提交证据由 2026-07-17 执行计划及 current handoff 派生清单维护；不能只替换提交号来提升成熟度。
