# Round 2 产品模型、范围与决策收敛方案

## Problem Definition

当前 PRD、V3 Blueprint、iOS 一致性分析、Hermes/AOS 分析与工程实现分别描述了不同阶段的产品：私人记忆助手、公开数字分身、家庭关怀、时间信件、声音复刻和认知平台被同时列为核心，导致 36 条需求中 32 条被标为 P0，且部分未来能力已经默认出现在公开产品表面。若不先收敛产品模型和决策边界，目标架构与开发路线会继续重复历史任务、扩大安全风险，并把合同壳层误写成已完成能力。

用户已明确：现有 PRD、Blueprint 和分析文档是可修订底稿，不作为最终成果物。Round 2 因此需要在保留来源可追溯性的前提下，形成唯一产品定义，并明确哪些结论是事实、已确认决策、推荐方案、外部依赖或待决策。

## Proposed Solution

1. 以 Round 1 的 36 项需求证据矩阵和 21 项冲突为事实底座，不以历史文档标题或既有页面倒推最终产品范围。
2. 收敛一条阶段化产品主线：原始证据进入、候选记忆审核、权威记忆形成、可引用的本人问答；Publication/Visitor、Voice/Digital Human、Family/Care/TimeLetter 分别作为受控扩展轨道，不再相互充当上线前置。
3. 定义 Owner、Visitor、Operator、Admin 及未来 Family Contributor 的角色与权限；把私人域、发布域和运行时域做确定性隔离。
4. 定义 Source、Memory Candidate、Canonical Memory/Version、Knowledge Projection、Persona、Conversation、Publication、Visitor Session、Voice Profile、Digital Human Runtime 等领域词典、权威归属和状态机。
5. 将 sensitivity、usage consent、visibility、publication state 分成独立维度；为未决项设定 fail-closed 默认值，不用工程实现替产品做隐性决定。
6. 形成 Product Spec V4 初稿，覆盖定位、用户/JTBD、北极星、阶段闭环、非目标、IA、功能范围、AI 行为、隐私安全、质量指标、运维和外部验收边界。
7. 形成产品决策登记册，逐项记录证据、选项、推荐、影响、默认安全策略、决策责任人与截止门槛。
8. 对 PRD、V3 Blueprint 和分析文档增加文档生命周期标识与 V4 引用关系；允许修正冲突内容，但保留历史来源和变更说明，最终只让 V4 主规格成为开发范围权威。
9. 通过至少两轮独立复审挑战产品价值、范围、隐私伦理、商业成本、供应商依赖和过度设计，再由主控统一收敛，不直接复制任一 agent 的结论。

## Acceptance Criteria

- `DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md` 初稿完整，且所有规范性结论均标注为事实、已确认决策、推荐方案、外部依赖或待决策。
- `DreamJourney_V4_产品决策登记册_V1.0.md` 覆盖 Round 1 的 21 项冲突，并对身份、导出/删除、声音授权、Publication/Visitor、Family/Care/TimeLetter、数据地域、供应商和成本给出明确状态。
- 产品只有一条可测量的主闭环、一个候选北极星指标和不超过三个阶段性结果指标；Voice/Digital Human 不阻塞私人记忆 MVP。
- 角色、领域词典、数据权威、权限矩阵和至少 Source、Candidate、Canonical Memory、Publication、Voice Profile 的生命周期不存在互相矛盾定义。
- 私人知识域与公开人格知识域采用独立发布副本；未确认 Candidate、未到期 TimeLetter、失败媒体分析、未接受 Family 邀请及 runtime 状态不会被当作可发布事实。
- 现有三 Tab 不被文档直接判废；目标 IA 给出兼容映射和产品验证门，不要求本轮改 UI。
- 32/36 P0 被重新分级为安全止损、Owner 核心、摄入/质量、受控发布、独立 Voice Beta、未来扩展，不再全部并行开发。
- PRD、Blueprint 和分析底稿具有明确 `工作底稿/历史参考/由 V4 取代` 生命周期标识，且不会与 V4 同时被描述为最终执行依据。
- 产品规格与决策登记册通过术语、状态、冲突覆盖和内部链接静态检查。

## Verification Plan

1. 建立术语唯一性和状态机交叉检查，确认同一概念只有一个权威定义。
2. 将 36 条 FR 逐项映射到 V4 阶段、领域和决策项，检查无遗漏且无“页面存在即完成”的表述。
3. 将 21 个冲突 ID 逐项映射到决策登记册，检查状态、推荐与 fail-closed 默认值齐全。
4. 对 Owner、Visitor、Operator、Admin 运行权限场景表，验证私人域、发布域、声音和数字人 runtime 不越界。
5. 由独立复审分别从产品价值、隐私安全、工程可迁移性和成本运维角度审查，所有高风险异议要么修正，要么进入待决策项。
6. 运行 Product V4 文档静态检查、`git diff --check` 和 Closure Lodestar ledger check。

## Risks

- 把用户尚未确认的推荐方案误写为已决策，导致后续开发范围被错误冻结。
- 为追求统一而丢失历史需求和现有已实现能力的兼容路径。
- 过早把 Publication/Visitor 或 Voice/Digital Human 设为 MVP 前置，继续分散 Owner 核心闭环投入。
- 使用“完全可信、完全可控”等不可证明承诺，带来合规和验收风险。
- 在源文档尚未归档前直接重写，造成来源不可追溯；必须保留版本、日期和变更说明。

## Assumptions

- 当前源码和已执行测试优先证明实现事实，但不自动决定产品公开范围。
- 最新 PRD 是评审底稿，不是已经批准的发布承诺。
- V4 可以提出推荐默认值；涉及商业、合规、身份、数据地域和第三方授权的决定仍需标为待产品确认。
- 本轮不改生产业务代码、不改变现有公开 UI，也不宣称真实 provider 或真机能力已验收。
