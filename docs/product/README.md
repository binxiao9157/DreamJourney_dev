# DreamJourney 产品文档权威源

状态：`CANONICAL_WORKING_SOURCE`

本目录是 DreamJourney V4 产品、架构和工程事实文档的唯一可编辑工作源。交付快照、历史评审和任务过程记录不得反向覆盖本目录。

## 权威顺序

发生冲突时按以下顺序判断：

1. `DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`：产品目标、领域边界和目标架构。
2. `DreamJourney_V4_产品决策登记册_V1.0.md`：已确认、待确认、外部依赖、拒绝和延期决定。
3. `DreamJourney_V4_当前实现证据矩阵_V1.0.md`：冻结提交上的当前工程事实，不因目标文档更新而自动提升成熟度。
4. `../superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md`：115 个 Work Item 的执行顺序、Gate 和停止条件。
5. `DreamJourney_V4_评审与验收清单_V1.0.md`：评审处置与静态验收控制面。

`docs/superpowers/plans` 是既有路线图兼容路径，不依赖已安装的 Codex plugin 或 skill。

## 派生与参考材料

- `DreamJourney_V4_开发前问题与决策收敛清单_V1.0.md` 记录 2026-07-15 五项产品细节的确认回执与实施交接；正式权威口径已经回写 Product Spec、决策登记册和既有路线图。
- `../superpowers/plans/2026-07-15-dreamjourney-v4-confirmed-decisions-execution-plan.md` 是确认后的派生执行切片，不新增 Work Item，不覆盖 115 项正式路线图、Registry stableRank 或 Gate。
- `DreamJourney_V4_路线追踪矩阵_V1.0.md` 与 `DreamJourney_V4_路线执行注册表_V1.0.json` 是生成产物，不应手工编辑。
- `reviews/` 和 Round 2/3 文档是评审证据，不覆盖 Product Spec 或决策登记册。
- PRD、V3 Blueprint、Hermes/AOS 分析和历史一致性分析是输入材料，不是 V4 当前实现证明。
- `../DreamJourney_V4_成果物_2026-07-15/` 是 `DELIVERY_SNAPSHOT_NON_CANONICAL`，仅用于交付和审计回看。

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

当前文档审计基线是 iOS `feature/prd-stitch-ui-adaptation@8a1922b` 和 Backend `main@4c0538b`。后续代码提交可以前进，但修改“当前实现证据”前必须重新读取并验证对应提交，不能只替换提交号。
