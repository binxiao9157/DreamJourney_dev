# DreamJourney V4 Round 5A 产品独立复审

基线：审查者 Round5A-Product-Agent｜2026-07-12｜iOS `8a1922b`｜backend `4c0538b`｜Round4 static accepted

## Summary

本轮独立产品复审识别出3项P0、4项P1、0项P2。P0集中在Owner Truth尚未实施、身份/租户隔离尚不足，以及V1历史MVP口径与V4当前可发布范围冲突；P1集中在Publication/Visitor、Voice/DH、开放产品决定和指标证据。报告只记录发现，不在本轮修改或关闭这些问题。

## Findings

### R5A-PROD-001

- Severity：`P0`
- 结论：Owner Truth Loop 尚未形成可验收闭环。
- 证据：《当前实现证据矩阵》§5 FR-CHAT-002、FR-MEM-001/002、FR-QA-001；《路线图》§15.1 `WP-S1-01`。
- 影响：当前缺少独立 Candidate、DecisionReceipt、immutable MemoryVersion authority，无法证明用户确认记忆驱动问答。
- 建议处置：冻结 Source→Candidate→Review→MemoryVersion→Citation→Correction→Rights 的单一 Authority，并禁止 legacy projection 伪装完成。
- Suggested Owner：Product + Backend。
- 验证方式：真实 Postgres 端到端回放，确认/纠正/删除后 citation 与检索结果一致，legacy 不进入 active context。
- 主张类型：已实现事实。

### R5A-PROD-002

- Severity：`P0`
- 结论：当前身份与租户边界不足以支撑私人记忆产品上线。
- 证据：《当前实现证据矩阵》§7.4、§7.9 FR-ACC-001/FR-PRIV-001；《路线图》§14.1、§14.4。
- 影响：存在 anonymous/system fallback、共享 token、手机号弱认领及 ownership shadow；跨用户泄露和高风险入口均未闭环。
- 建议处置：先完成强身份、server-derived owner、全路由 deny-by-default、AccountLease 与危机表达即时退出；未完成前保持公开和高敏能力关闭。
- Suggested Owner：Security + Backend + Product。
- 验证方式：跨 Vault/AuthZ 负例、匿名访问、token 泄露扫描、账号切换/撤销/恢复测试全部通过。
- 主张类型：已实现事实。

### R5A-PROD-003

- Severity：`P0`
- 结论：V1 PRD 的 MVP/P0 范围与当前可发布产品范围冲突，存在把目标当现状的风险。
- 证据：V1 PRD §4.1、§14.1–14.2、§15；V4 Product Spec §0.1、§3；《路线图》§5.1–5.3。
- 影响：V1 将声音、Visitor、Publication 作为 MVP/P0；但 36 FR 中成熟度仅 1 `IMPLEMENTED`、20 `PARTIAL`、10 `MISSING`、4 `CONTRACT_ONLY`、1 `MOCK_ONLY`，路线图对应包仍 `STOP/PLANNED`。
- 建议处置：将 V4 阶段门作为唯一排期依据，V1 仅保留为历史需求来源；发布材料不得沿用“完整 MVP”表述。
- Suggested Owner：Product。
- 验证方式：发布清单逐项映射 V4 Stage Gate，任何未过门能力不得进入公开承诺。
- 主张类型：已确认产品决策。

### R5A-PROD-004

- Severity：`P1`
- 结论：Publication/Visitor 必须是独立公开域，但当前仍完全缺失。
- 证据：V4 Product Spec §3.4、§5.2、§10.1–10.2；《当前实现证据矩阵》§5 FR-PUB-001–003、FR-VIS-001–003；《路线图》§18.1。
- 影响：当前无 Publication snapshot、Public Index、ShareGrant、Visitor principal 或撤回传播；`isPrivate=false` 不能替代公开 authority。
- 建议处置：保持 Publication/Visitor 默认关闭；实现独立快照、索引、授权、撤回和 private-role deny 后再做邀请 cohort。
- Suggested Owner：Product + Privacy/Legal + Backend。
- 验证方式：public role 无法读取 private store；grant 过期/撤回后新 session/query 命中为 0。
- 主张类型：已实现事实。

### R5A-PROD-005

- Severity：`P1`
- 结论：Voice/Digital Human 现有代码不能代表产品完成，且其授权边界仍未满足 V1 MVP 要求。
- 证据：V4 Product Spec §3.5、§17.1–17.3；《当前实现证据矩阵》§5 FR-VOICE-001–005；《路线图》§19。
- 影响：当前为 `PARTIAL/IMPLEMENTED/BETA_UNVERIFIED`，存在默认开启、布尔 consent、长期 credential、provider delete/receipt 缺口；V1 的 M0/M1 要求与实际 Beta 门不匹配。
- 建议处置：将 Voice/DH 拆为独立 Beta lane，默认关闭；先完成 purpose grant、短期 credential、provider receipt、删除回执、真机和成本验收。
- Suggested Owner：Product + Privacy/Legal + Provider Owner。
- 验证方式：无有效 purpose consent 时 UI/API/runtime 均 deny；训练、生成、撤回、删除均有可追踪 receipt。
- 主张类型：已实现事实。

### R5A-PROD-006

- Severity：`P1`
- 结论：36 FR 与 41 DR 的状态显示产品尚未具备稳定的发布决策基线。
- 证据：《当前实现证据矩阵》§5；《产品决策登记册》§2–§4。
- 影响：41 个 DR 中仅 1 `CONFIRMED`，32 `RECOMMENDED_PENDING`，5 `EXTERNAL_REQUIRED`，3 `REJECTED`；身份、地域、Provider、匿名 Visitor、声音、指标和数据权利仍影响范围。
- 建议处置：对每个待决策项指定 Product/Privacy/Commercial owner 和 gate；在关闭前只允许可逆 schema、mock、shadow 与 fail-closed 实现。
- Suggested Owner：Product 主控 + Privacy/Legal + Finance。
- 验证方式：逐项产生决策记录、批准人、适用范围和失效条件；未关闭项不得进入不可逆 schema 或公开 release。
- 主张类型：待决策。

### R5A-PROD-007

- Severity：`P1`
- 结论：当前指标不能作为产品验收证据，V1 的百分比目标存在过度声明风险。
- 证据：V1 PRD §13、§15；V4 Product Spec §6.1–6.3、§18.4；《产品决策登记册》DR-019、DR-032。
- 影响：当前没有产品事件管线；V4 仅定义 WTMR/A72/R28/GHR 候选口径，且明确需真实事件和至少两个完整周观察后确认。
- 建议处置：先实现服务端事件、稳定 owner/object/version/idempotency 与失败/无引用/未反馈分母，再由 Product/Data 批准阈值；此前不得宣称达标。
- Suggested Owner：Product + Data。
- 验证方式：服务端事件与业务 receipt 对账，排除 QA/mock/internal，形成 cohort 报告和正式 go/no-go 记录。
- 主张类型：待决策。

## 审查覆盖

仅读取指定 5 份文档，覆盖用户/角色、核心闭环、Source/Memory/Projection/Persona/Echo/Publication 边界、公开/隐藏/外部门、36 FR、41 DR、指标、路线图状态及现状声明。

## 残余风险

未读取源码、密钥、LocalConfig、既有评审报告，也未重新执行构建、真机、Provider、生产或用户研究验证；因此不对文档外实际运行状态作推断。

## 独立性声明

本审查为独立、只读、快速产品审查，未修改任何文件，结论仅基于上述 5 份材料及其内部交叉核对。

## 计数

- P0：3
- P1：4
- P2：0
