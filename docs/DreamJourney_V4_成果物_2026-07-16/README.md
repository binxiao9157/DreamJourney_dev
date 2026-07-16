# DreamJourney V4 2026-07-16 新规适配增量成果物包

初版日期：2026-07-12  
更新日期：2026-07-16  
状态：`REGULATORY_AND_GUIDED_INTERVIEW_BASELINE_SYNCED / M0_CONDITIONAL / M1-M4_DEFAULT_OFF / IMPLEMENTATION_UNVERIFIED`

> 本目录最终交付时仅保留相对 `DreamJourney_V4_成果物_2026-07-15` 内容有变化的文档。使用时应覆盖到 7 月 15 日成果物副本上；它不是完整独立包，也不会重复未变化的历史复审、工具和交付记录。

## 1. 工程基线

- iOS：`feature/prd-stitch-ui-adaptation@8a1922b`
- Backend：`main@4c0538b`

## 2. 推荐阅读顺序

1. `01-核心成果物/寻梦环游_产品问题风险分级与整体规避方案_V1.0.md`
2. `01-核心成果物/DreamJourney_V4_引导式访谈与知识丰满化功能说明_V1.0.md`
3. `01-核心成果物/DreamJourney_V4_方案架构评审解读_新规生效增量复审_2026-07-16.md`
4. `01-核心成果物/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
5. `01-核心成果物/DreamJourney_V4_产品决策登记册_V1.0.md`
6. `01-核心成果物/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
7. `01-核心成果物/2026-07-12-dreamjourney-v4-executable-development-roadmap.md`
8. `01-核心成果物/DreamJourney_V4_评审与验收清单_V1.0.md`
9. `05-交付记录/DreamJourney_V4_相对2026-07-15新规适配更新说明_2026-07-16.md`

## 3. 目录说明

- `01-核心成果物`：本轮新增的风险 Authority、引导式访谈功能合同、新规增量复审，以及发生变化的产品、架构、路线和验收文档。
- `02-追踪与执行`：仅在重新生成后与7月15日不同的 Trace/Registry 派生视图。
- `05-交付记录`：7月16日相对7月15日的差异、兼容方式和验证结果。

## 4. 2026-07-16 同步摘要

- 发布分层由旧三级名称调整为 M0-M4：M0 记忆资产、M1 在世本人私有 Voice、M2 在世主体授权互动、M3 受控高风险试点、M4 权益商业化。
- 未成年人虚拟亲属、未成年人 Voice/Persona、家庭代录、无专项授权逝者 Voice/DH、人格化促购和 Persona 参与重大现实决定为硬拒绝。
- M0 增加交互数据复制、可读导出、机器可读清单和删除状态；M2/M3 增加 AI 标识、2小时提醒、确定性退出、依赖/危机控制、安全评估和算法备案 Gate。
- M0 的记忆采集采用“一个自然输入 + 最多两条动态推荐”：第一条延续近期故事，第二条补足知识维度；主题由系统内部管理，用户拥有跳过、暂缓和禁问权。
- 引导式访谈通过 ConversationThread、Interview Orchestrator 和 Knowledge Dimension Projection 融入现有 Source→Candidate→MemoryVersion 主干，不新增第二套事实库，也不改变115个Work Item总数。
- 百级用户仍采用 Startup Lean Profile；本轮增加合规状态机和 ReleasePolicy，不要求提前拆分微服务或一次建设全部组合迁移控制面。

派生物 SHA-256：

- Trace：`706023152ff8897fe310a6021e27dc3f3a16003cd2a1b7961c97d10534a93347`
- Registry：`49388767e3a72e28a0e596ab081350105a717f65de5c596b0f95d270267000cb`

## 5. 使用边界

本增量包完成的是新规基线、产品边界、目标架构、开发路线和验收门同步，不表示工程 Work Item 已实现，也不关闭 G2-G4、真机、Provider、法律/隐私、监管备案或发布审批。风险方案和架构评审不替代正式法律意见；用户协议不能替代平台法定义务、主体授权、第三方权利或供应商许可。
