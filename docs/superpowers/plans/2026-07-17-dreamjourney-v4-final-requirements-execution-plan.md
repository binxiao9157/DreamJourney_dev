# DreamJourney V4 终版需求可执行开发计划

版本：V2.0
日期：2026-07-17
状态：`FINAL_REQUIREMENT_DERIVED_EXECUTION / SINGLE_DAILY_ENTRY / IMPLEMENTATION_IN_PROGRESS`
当前 iOS 基线：`feature/prd-stitch-ui-adaptation@075a75a`（相对远端存在已验证的本地提交）
当前 Backend 基线：`main@a45170d`

## 0. 计划定位

本文是 DreamJourney V4 后续日常开发的唯一主入口，替代：

- `2026-07-15-dreamjourney-v4-confirmed-decisions-execution-plan.md`

本文不创建第二套产品定义、领域模型或 Work Item 编号。终版产品需求采用以下合并规则：

1. `docs/DreamJourney_V4_成果物_2026-07-16/` 是 2026-07-15 基线之上的终版需求增量。
2. 该目录明确标记为“增量覆盖包”，因此未变化内容继续继承 2026-07-15 基线。
3. 发生冲突时，2026-07-16 成果物中的风险方案、引导式访谈说明、Product Spec V4.4、Decision Register V1.4、验收清单和 Roadmap V1.3 依次优先。
4. `docs/product/` 与 `docs/superpowers/plans/2026-07-12-*` 是兼容路径；Phase 0 完成后必须与终版需求一致，不能继续形成双权威。
5. Registry/Trace 保留 115 个稳定 Work Item ID、依赖和 Gate。按终版 Roadmap 合同，Registry 是保守计划视图并保持 `PLANNED/STOP/NO_GO`，不能自行声称实现；当前提交证据必须写入单一 current handoff 派生清单，避免因 Registry 的保守状态重复开发。

### 0.1 每轮最小读取集合

日常执行只读取：

1. 本文当前 Phase/Slice 和当前交接点。
2. 当前一个 Work Item 在 Registry 中的依赖、Authority、Gate 和完成定义。
3. 相关源码、测试、状态证据、最近提交和工作区差异。

只有在阶段切换、终版需求发生正式变更、产品边界冲突、Gate 变化或 Work Item 需要拆分时，才回查完整成果物。禁止每轮重新通读全部产品文档。

### 0.2 不可变产品边界

- 产品核心是个人私有记忆资产，不是数字人拟真程度。
- 近期公开主线是 M0；M1-M4 默认关闭并独立过门。
- 保留 UIKit、三 Tab 和已对齐的 Stitch 全屏视觉，不做无关 UI 重构。
- 继续使用模块化单体、Postgres 单一数据 Authority、独立 Worker 和私有对象存储；百级用户阶段不拆微服务。
- 唯一事实主干是 `Source -> Candidate -> DecisionReceipt -> MemoryVersion -> Projection`。
- KBLite 只能成为 Projection/兼容读取，不得继续作为确认事实 Authority。
- Interview Orchestrator 和 Knowledge Dimension Projection 不得直接写 `MemoryVersion`。
- Family relationship 不等于 AccessGrant；家庭管理员不继承声音、肖像、人格、逝者或公开授权。
- 已有 Voice、Digital Human、TimeLetter、Care、媒体代码可复用，但“存在代码”不等于终版需求已验收或可公开。

### 0.3 硬拒绝

以下能力不进入可放行开发路径，也不能通过改名、客户端隐藏或家庭管理员同意绕过：

1. 未成年人虚拟亲属、Voice、Persona 或持续人格化互动。
2. 家庭成员替他人录制声音；M1 只允许在世成年人 `subject=actor` 训练本人声音。
3. 无生前专项授权和完整权利链的逝者 Voice/Digital Human。
4. Persona 人格化促购、诱导依赖、替代现实关系或参与重大现实决策。
5. 私人、敏感、生物识别数据默认用于平台或 Provider 通用训练。
6. 用本地 tombstone、一次 smoke、模拟器、Provider accepted 或 UI 截图宣称完整删除、生产可用或外部门通过。

## 1. 终版需求分析结论

### 1.1 产品发布层级

| 层级 | 产品范围 | 默认状态 | 核心退出条件 |
| --- | --- | --- | --- |
| M0 | 记忆采集、确认、私人问答、引导式访谈、复制/导出/删除、静态家庭贡献 | 条件性主线 | Owner Truth、身份隔离、引用、权利、GIC、安全和 G1/G2 证据 |
| M1 | 在世成年人本人私有 Voice | `OFF` | 本人证明、专项同意、Provider 删除回执、AI 标识、真机质量 |
| M2 | 在世主体授权发布、成年 Visitor、在世 Digital Human | `OFF` | 独立发布副本、成年验证、退出/危机/依赖控制、监管与上架材料 |
| M3 | 老人健康协同、成人纪念互动逐案试点 | `OFF` | 专项授权、无诊断、权利链、法律伦理和紧急下线 |
| M4 | 知识许可、数字传承和收益 | `OFF` | 权利目录、合同、受益人、计量、结算和争议机制 |

M0 通过不自动批准 M1-M4；任一扩展 Lane 失败不得影响 M0 中性文字核心。

### 1.2 M0 引导式访谈终版合同

终版需求新增的核心不是“推荐卡片”，而是受约束的主动倾听：

- 永久保留一个自然输入入口：“今天想聊点什么？”。
- 最多两条动态推荐：一条延续近期故事，一条补足知识维度；无安全候选时允许为空。
- 每轮最多一个主要问题；同一线索通常深挖 2-4 轮后总结。
- 深挖轮次和 5-10 轮/退出时 Candidate 批量确认分别计数。
- 支持“这次跳过、以后再聊、不再问”，三者必须有不同持久化语义。
- `do_not_ask`、敏感、跨 Vault、撤权、删除、争议和仅 AI 推断线索不得进入主动推荐。
- 人生地图和语义搜索是只读次级工具，不是第二事实库，也不展示伪精确完成百分比。
- 危机和安全策略可覆盖普通访谈动作，切换中性安全模式。

GIC 需求在本计划中的唯一落点：

| 需求 | 实施位置 |
| --- | --- |
| `GIC-001` | Phase 3 Slice 3D：长期自然输入入口 |
| `GIC-002`、`GIC-003`、`GIC-004` | Phase 4 Slice 4B：最多两条、允许为空、具体问题 |
| `GIC-005`、`GIC-006`、`GIC-007` | Phase 3 Slice 3A：Thread 状态、单问题、2-4 轮总结 |
| `GIC-008`、`GIC-009`、`GIC-010` | Phase 3 Slice 3B：跳过/暂缓/禁问和敏感过滤 |
| `GIC-011` | Phase 4 Slice 4A：主题自动归并 |
| `GIC-012`、`GIC-013` | Phase 4 Slice 4C：次级回顾工具和访谈结束反馈 |
| `GIC-014` | Phase 4 Slice 4B：reason code、policy version 和审计 |
| `GIC-015` | Phase 3 Slice 3B + Phase 4 Slice 4B：授权数据与推荐 evidence |
| `GIC-016` | Phase 3 Slice 3B：危机策略覆盖普通访谈 |

### 1.3 当前工程可复用资产

| 资产 | 当前价值 | 终版需求处置 |
| --- | --- | --- |
| 三 Tab、Archive/Echo/Profile 和 Stitch 视觉 | 已有公开 MVP 交互基础 | 保留视觉和导航，通过 typed use case 渐进替换内部调用 |
| ReleasePolicy/FeatureFlag | 已完成 server policy、cache、默认关闭和 QA 边界基础 | 继续作为 M0-M4 暴露控制；补 AI 身份/危机安全策略 |
| Context Packet/Echo Trace/Evidence Bundle | 已有上下文和诊断证据 | 接入 typed Citation、Candidate/Memory 状态和 GIC reason code |
| KBLite、Knowledge Sync、Gap Detector | 已有本地搜索、图谱和同步能力 | 降级为 Projection/compatibility；禁止直接确认事实 |
| Archive/媒体 UI 和合同 | 已有本地草稿、状态、重试壳层 | M0 先做文字/诚实本地状态；真实对象和处理进入 R4 |
| TimeLetter、消息中心、Care | 已有较完整壳层与部分后端合同 | 保持 default-off，迁移到统一 effect/receipt 后独立验收 |
| Voice Clone、Tencent Digital Human、Audio owner | 已有 Provider 与真机调试积累 | 按 M1/M2 权利与 Provider Gate 重验，不进入 M0 退出条件 |

### 1.4 当前主要缺口

1. `docs/product` 与 2026-07-16 包仍是两套不同版本，当前权威不唯一。
2. Registry 按设计不声明实现状态，但仓库缺少一个由提交和 evidence manifest 生成的 current handoff，不能只看 Registry 判断是否重复开发。
3. 后端尚未形成唯一 `Source/Candidate/DecisionReceipt/MemoryVersion` Authority。
4. KBLite 仍包含本地提取和可变图谱写入路径，尚未完成 Projection 化。
5. 引导式访谈的 `ConversationThread/InterviewSession/Orchestrator`、双推荐和用户控制尚未实现。
6. 强身份、全路由对象 AuthZ、iOS AccountLease 和 owner-scoped store 尚未完成 Stage 0 退出。
7. 复制、可读导出、机器清单、删除传播和 Provider/backup receipt 尚未形成完整 M0 权利闭环。
8. 统一 outbox/job/inbox/business receipt 仍未生产化；TimeLetter/Echo 不能作为完整 effect kernel 的替代。
9. iOS 缺少正式 XCTest 承载面，`EchoViewController` 等页面仍承载过多业务和 runtime 职责。
10. 现有 Voice/DH 成果不满足终版 M1/M2 的权利、监管和独立发布定义。

## 2. Gate 与完成声明

| Gate | 能证明什么 | 不能证明什么 |
| --- | --- | --- |
| G0 | unit/contract/static、negative fixture、generic build | Postgres、Provider、真机、产品/法律批准 |
| G1 | 模拟器 UIQA、截图、交互和发布暴露 | 真机权限和真实 Provider 质量 |
| G2 | 部署、Postgres、migration、restore、并发和观察窗 | Provider、真机、监管批准 |
| G3 | Provider credential、quota、质量、成本、删除/退出回执 | 真机听感和产品/法律批准 |
| G4 | 真机、产品、隐私、法律、监管、商业和真实用户证据 | 不能由 G0-G3 自动关闭 |

状态统一使用：

- `PLANNED`：未开始。
- `IN_PROGRESS`：已取得 Authority lease 并有活动实现。
- `INTERNAL_READY`：G0/G1 已完成，等待外部门。
- `EXTERNAL_BLOCKED`：仅缺 G2/G3/G4 外部门；不得删除该 Gate。
- `VERIFIED`：该 Work Item 所需 Gate 全部有当前证据。
- `RETIRED`：旧路径完成零使用窗和退役证据。

所有“完成”声明必须精确到 Work Item 和 Gate，禁止把 `INTERNAL_READY` 写成生产完成。

## 3. 当前实施交接点

### 3.1 已有有效证据

| 范围 | 当前证据结论 |
| --- | --- |
| `WI-S0-03-01..07` | Credential inventory、响应边界、移动端路径退役、安全接入和风险豁免已有提交/状态证据；已接受旧凭据不轮换的风险豁免，不再因此阻断后续开发 |
| `WI-S0-06-01..08` | ReleasePolicy、TTL/cache、future default deny、captured gate、能力分轴、QA override 和 public release scope 已有提交 |
| `WI-S0-07-01..02` | 最小事件映射和持久化 evidence sink 已有提交 |
| `WI-S0-04-01..04` | UoW、versioned migrator、readiness 和 Postgres backup 已有后端部署/证据；iOS 状态证据已提交在本地分支 |

这些证据在 Phase 0 重算后写入 current handoff 派生清单，不回写 Registry 的保守计划状态，也不能因 Registry 仍为 `PLANNED` 而重复实现。

### 3.2 当前活动任务

截至 2026-07-23，`docs/superpowers/status/2026-07-17-v4-current-execution-handoff.json` 已登记 `86/115` 个具有实现或验证证据的 Work Item。该数字只表示**证据覆盖**，不等同于公开发布完成率；Registry 继续保留 `PLANNED/STOP`，直到全部适用 Gate 有独立证据，不能把 G3/G4 或真实设备/法务门误算为“未开发”。

`WI-S0-06-09` 新规即时安全止损已经完成代码合同、后端部署和 scoped G0/G2 验证；M1-M4 仍默认关闭。`WI-S0-04-05` 已完成恢复工具、运行时围栏和真实 Postgres 隔离恢复演练，但 G2 结论仍为 `NO_GO`：历史数据存在 owner orphan 且全库 replay bundle 缺失，因此不得恢复切流。两项状态分别见 `docs/superpowers/status/2026-07-17-wi-s0-06-09-safety-stop-loss.md` 与 `docs/superpowers/status/2026-07-17-wi-s0-04-05-postgres-recovery.md`。

`WI-S0-01-01..08`、`WI-S0-02-01..06`、`WI-S0-05-01..04`、`WI-S0-05-06`、`WI-S0-07-01..09` 已分别形成 scoped 实现/验证证据；`WI-S1-01..03` 的多项 default-off M0 子切片也已在 handoff 中登记。当前不重复这些已交付边界。`WI-S0-05-05` 仍受真实对象/Provider/备份删除的 G3/G4 限制。`WI-S1-01-03` 的正式用户边界命令已经以 owner-scoped、captured-policy 路由和 typed iOS client 完成 scoped G0/G2：仅允许 `skipOnce`、`cooldown`、`doNotAsk`，保持默认关闭，不开放新的公开 Echo 入口，也不把这些控制当作 Provider 或 Memory Authority 写入。M0A-25 已将该命令接入 `OwnerTruthInterviewNaturalInputUseCase` 的 AccountLease request/commit 围栏，并验证 stale completion、回执不匹配和 paused continuation。M0A-26 仅在 QA presentation 的 Debug/UIQA 编译分支增加三个操作控件与 in-memory 模拟器 smoke，分别验证 `skipOnce` 的 active continuation 和 `cooldown`/`doNotAsk` 的 paused continuation；Release 不创建该控件，且不改变公开 Echo。M0A-27 已在后端将 `skipOnce` 收敛为一次性边界：仅在下一段 owner narrative 成功落库时原子恢复为 `open`，并以隔离 Postgres smoke 验证重放幂等；不增加客户端 `open` 命令。M0A-28 已以 `0038` receipt 迁移部署独立、必须显式确认的 `doNotAsk` 恢复命令：只允许 `paused + doNotAsk -> active + open`，拒绝恢复 `cooldown`，并保持 QA-only/默认关闭。M0A-29 已在正式 narrative append 写入前接入既有 `SafetyPolicy`：明确危机表达返回不含原文的中性安全 override，不创建消息/回执或推进 session 版本，普通叙述仍可使用原 optimistic version 提交；后端 `4ebeda0` 已部署并通过隔离 Postgres smoke。M0A-31 进一步锁定同 Owner/同 Vault 下的线程隔离：现有“一条 active session”约束不变，A 被 cooldown 暂停后 B 可独立开始，任何 `sessionB + threadA` 的 boundary/restore 都被拒绝且不写数据；后端 `8a28825` 已在线上 disposable Postgres smoke 验证，iOS 同 Lease 的跨线程回执也 fail-closed。它不实现自然语言主题识别；该 topic identity/classifier 合同和 cooldown 的到期策略仍是后续明确缺口。后续继续盘点 handoff 内已有 `WP-S1-01` scoped 证据，选择第一个未覆盖且不依赖 G3/G4 或恢复切流的 P0 小闭环；不得因 Registry 仍为 `PLANNED` 重复编码。

### 3.3 工作区保护

当前 iOS 仓库存在 `.closure-lodestar/`、`.complex-problems/`、`docs/plans/task_27_*`、`findings.md`、`progress.md` 和 `task_plan.md` 等过程/外部改动。后续提交必须按文件白名单暂存，不得清理、回退或混入正式 Work Item 提交。

## 4. 连续执行总序

```text
Phase 0 终版需求晋升与证据重算
-> Phase 1 Stage 0 剩余安全/恢复/身份/权利闭环
-> Phase 2 M0 基础 Authority 与可测试架构
-> Phase 3 M0-A 最小引导式访谈闭环
-> Phase 4 M0-B 双推荐与知识地图
-> Phase 5 M0-C 评测、个性化和 M0 发布闭环
-> Phase 6 R4 真实媒体质量（独立后置）
-> Phase 7 M1 在世本人私有 Voice
-> Phase 8 M2 成年授权 Publication/Visitor/Digital Human
-> Phase 9 M3/M4 受控试点与商业权利（默认不启动）
```

一次只推进一个主要 Work Item；并行工作只能触及互不重叠的 adapter、测试或 additive schema，不能同时拥有同一 writer、effect、audio session 或 runtime session。

## 5. Phase 0：终版需求晋升与执行基线重建

目标：把 2026-07-16 成果物正式变成唯一终版需求，并恢复可信的下一任务选择。

### Slice 0A：权威路径晋升

1. 将成果物包中发生变化的 Product Spec V4.4、Decision Register V1.4、Evidence Matrix V1.4、Review Checklist V1.4 和 Roadmap V1.3 晋升到 canonical 路径。
2. 将新增的风险方案、引导式访谈说明和新规增量复审放入 `docs/product/`，并修正相对链接。
3. 更新 canonical source checker，使 2026-07-16 包成为终版快照来源；2026-07-15 保留为历史，不再参与当前 hash 比对。
4. 保持 36 FR / 43 DR / 22 Finding / 12 CR / 13 Package / 115 Work Item，不创建第二编号体系。

### Slice 0B：当前实现证据重算

1. 从提交、状态文档、manifest、后端部署 smoke 重算已完成 Work Item。
2. Registry 按 Roadmap 重新生成并继续保持保守 `PLANNED/STOP/NO_GO`；不得修改生成器来自动签发 `GO/VERIFIED`。
3. 新增单一 current handoff 派生清单，逐项记录 evidence path、已关闭 Gate、状态上限和剩余外部门。
4. 在 handoff 中将 `WI-S0-04-05` 标记为唯一当前 `IN_PROGRESS`；记录 backend 未提交文件，不把测试通过冒充 G2 restore 完成。
5. 将 `WI-S0-06-09` 标记为新规新增的近期 P0，不与已完成 01-08 混淆。

### Slice 0C：执行入口切换

1. 旧 2026-07-15 计划标记为 `SUPERSEDED`，仅保留历史。
2. 本文成为唯一日常入口；Registry 提供当前一个 Work Item 的静态机器字段，current handoff 提供实现证据和续接点。
3. 生成新的 current handoff，明确下一任务为 `WI-S0-04-05`。

验证：

- `product-v4-canonical-source-check.py`
- `product-v4-docs-check.py`
- `product-v4-links-check.py`
- `product-v4-traceability-check.py`
- `product-v4-roadmap-check.py`
- `product-v4-current-handoff-check.py`
- `product-v4-finalization-check.py`
- `git diff --check`

完成定义：仓库内只有一个当前 Product Spec/Roadmap/Registry 组合；所有检查读取同一版本；current handoff 可定位当前证据和续接点；已完成工程证据不被重置，Registry 也不越权签发实现状态。

## 6. Phase 1：Stage 0 剩余闭环

目标：完成 R0/R1，保证后续 Owner Truth 不建立在共享身份、不可恢复 DB 或不完整权利之上。

### Slice 1A：完成 DB 恢复门

对应：`WI-S0-04-05`

1. 备份只恢复到 `dj_recovery_*` 隔离目标，硬拒绝生产目标。
2. 恢复后迁移到 schema head。
3. 按 cutoff 重放 command/outbox/deletion receipt，区分 duplicate/conflict/provider unknown。
4. 验证 owner、hash、删除用户不复活和业务 receipt 完整性。
5. 输出 value-free RPO/RTO、GO/NO_GO 和流量恢复记录。

退出：G0 合同测试 + G2 真实 Postgres isolated restore/replay；失败时保持流量关闭。

### Slice 1B：补新规即时安全止损

对应：`WI-S0-06-09`

- 持续 AI 身份标识合同。
- 危机表达退出 Persona/延迟回复，进入中性安全模式。
- 未成年人虚拟亲属和不合格 Voice 请求服务端 hard deny。
- M1-M4 ReleasePolicy 默认关闭，离线/未知状态 deny。

### Slice 1C：强身份与资源 AuthZ

对应：`WI-S0-02-01..06`

- access/refresh/session/revoke 强身份合同。
- actor 由 token/session 推导，payload owner 只能作为待校验输入。
- resource owner/vault/purpose/grant/epoch 全路由 enforce。
- Family relationship 与 grant 分离；pause/terminate/reinvite 后旧 grant 失效。
- A/B 用户、旧客户端、深链、手机号复用和跨 Vault negative corpus 为零泄漏。

### Slice 1D：iOS Account 与本地隔离

对应：`WI-S0-01-01..08`

- `AccountSessionActor`、generation CAS 和 `AccountLease`。
- Archive/Media、Memoir/Memory/Conversation、Voice/Reply/Message/Notification 全部 owner scope。
- switch/logout/delete/冷启动/后台/晚到回调不得提交旧 owner 数据或 UI。
- legacy mismatch 进入 quarantine，禁止自动认领 `user_001`。

### Slice 1E：数据权利与删除

对应：`WI-S0-05-01..06`

- access-first suspend、session/grant revoke。
- 复制、人类可读导出、机器可读对象/版本/来源/状态清单。
- `deletedAt/purgeAfter/restoreDeadline`、30 天恢复和一次恢复限制。
- object/provider/backup cleanup adapter 与 `pending/partial/unsupported/completed` receipt。
- purged 用户不可因 restore/backfill/旧客户端复活。

### Slice 1F：运营证据闭环

对应：`WI-S0-07-03..09`

- request/operation/attempt 分母、readiness 指标和 rights projection。
- Provider usage/cost/circuit breaker、incident 生命周期。
- 字段 allowlist、正文/secret 禁止、不可变 evidence manifest/TTL。
- `skipped/unknown/missing/expired` 不得计为 PASS。

Phase 1 Gate：Stage 0 Exit 全部满足；未满足 G2/G3/G4 的项标记 `EXTERNAL_BLOCKED`，继续不依赖该外部门的下一项，但不得开放对应能力。

## 7. Phase 2：M0 基础 Authority 与可测试架构

目标：建立唯一 Owner Truth 和可渐进迁移的 iOS/异步基础，不先改变公开 UI。

### Slice 2A：测试与 Composition seam

对应：`WI-S1-03-01/02/03`

- 建立正式 XCTest target 和层级依赖 guard。
- 引入 UIKit `AppComposition`/Feature Factory，先无行为替换一个真实 call site。
- 统一传播 AccountLease、ReleasePolicy 和 lifecycle；禁止只新增 protocol 而旧路径继续写。

### Slice 2B：Owner Truth schema 与 Source command

对应：`WI-S1-01-01/02`

- additive schema：Source、Candidate、DecisionReceipt、MemoryRecord/Version、authorityEpoch。
- 文字 `CreateSource` 使用 stable commandId/expectedVersion/receipt。
- 当前 Archive 通过 compatibility facade 写 shadow；本地照片明确 local-only，不冒充 uploaded/verified。

### Slice 2C：Effect kernel

对应：`WI-S1-02-01..04`

- Postgres outbox、job、attempt、consumer inbox、business/provider receipt、dead letter 和 scheduler lease。
- aggregate 与 outbox 同一 UoW；worker lease/heartbeat；consumer 幂等。
- 先 disabled worker 部署，不启动真实 Provider effect。

### Slice 2D：Candidate、Decision 与 MemoryVersion

对应：`WI-S1-01-03..05`、`WI-S1-03-04`

- ExtractionResult 只能生成 pending Candidate。
- `accept/correct/reject` terminal transition 与 immutable DecisionReceipt 同一 UoW。
- Decision 创建 immutable MemoryVersion，CAS 保证每个 MemoryRecord 恰一 current。
- iOS 提供 typed Candidate Inbox/review use case；断网、强杀和 context truncation 不丢业务记录。

### Slice 2E：Projection、QA 与 Correction

对应：`WI-S1-01-06..08`、`WI-S1-03-05`

- KBLite 从 MemoryVersion/rights event 重建，退为 compatibility Projection。
- `/context/build` 只读 active confirmed Memory/Projection，返回 typed Citation。
- 回答错误创建 correction Candidate，不原地覆盖事实。
- Echo Application Coordinator 管理 turn intent，ViewController 不直接组合 transport/Authority。

## 8. Phase 3：M0-A 最小引导式访谈闭环

目标：完成一个可持续对话、可形成待确认记忆、又不会越权追问的最小闭环。

本阶段不新增 Work Item，作为 `WI-S1-01-03/04/06/07` 与 `WI-S1-03-04/05` 的终版产品切片。

### Slice 3A：ConversationThread 与 Orchestrator

- `ConversationThread`、`InterviewSession`、当前 thread、deepening count、candidate batch count、fatigue 和 user boundary state。
- 动作：`LISTEN/DEEPEN/CLARIFY/SUMMARIZE/PAUSE`。
- 每轮一个主要问题；2-4 轮后优先总结；用户主动换话题后一轮内切换或暂停旧 Thread。

### Slice 3B：用户控制与安全策略

- “这次跳过”只影响当前机会。
- “以后再聊”进入可配置 cooldown。
- “不再问”持久化 `do_not_ask`，主动推荐/追问命中必须为 0。
- 用户主动重新提起禁问话题时先询问是否恢复。
- 敏感、跨 Vault、撤权、删除、争议和 AI-only 线索在展示前阻断。
- 危机策略优先于普通访谈动作。

### Slice 3C：Message 到 Candidate 批量确认

- 用户 Message 和 thread source 持续落库。
- 5-10 轮或退出时产生 review batch，与 2-4 轮总结计数分离。
- Orchestrator 只能产 Candidate proposal/reason code，直接创建或修改 MemoryVersion 次数必须为 0。
- 批量接受支持部分接受；敏感候选逐条确认。

### Slice 3D：M0-A UI

- 回响页保留一个自然输入入口，不显示不断增长的主题目录。
- 显示自然的总结、待确认结果和以后可续线索，不显示完成百分比或内部疲劳分数。
- 不改变现有全屏 Echo 视觉结构；新增 UI 必须以当前 Stitch/htmlCode 为主依据。

验证：GIC-001、005-010、014-016；G0 状态/策略负向测试、G1 模拟器交互、G2 状态持久化和 Authority replay。

## 9. Phase 4：M0-B 双推荐与知识地图

目标：在不增加用户管理负担的前提下，提供一条连续性推荐和一条完整性推荐。

### Slice 4A：Dimension Projection

- 六个稳定知识维度、Thread summary、DimensionCoverage 和 KnowledgeGap。
- 覆盖只由 confirmed MemoryVersion 提升；未确认 Candidate 不计入。
- 主题可自动合并/关联，但不能删除 Source、MemoryVersion 或历史视角。

### Slice 4B：双推荐

- 增加 `BROADEN` 动作。
- 推荐一“接着聊”基于近期未完 Thread；推荐二“换个角度”基于安全知识缺口。
- 任一时刻不超过两条；无安全候选允许 0-1 条；两条不得同义或指向同一缺口。
- 每条保存 reason code、policy version、evidence references 和最小审计信息。

### Slice 4C：回顾工具与反馈

- 人生地图只读浏览、语义搜索、本次补充和以后可续反馈。
- 用户反馈区分问法、时机和主题偏好。
- 推送不得以 Persona 或逝者口吻召回访谈。

验证：GIC-002-004、011-013；`do_not_ask`、敏感推荐、跨 Vault 和 AI-only 推荐命中均为 0。

## 10. Phase 5：M0-C 评测、迁移与发布闭环

### Slice 5A：评测与反优化

- 建立推荐离线评测集、敏感推荐红队集和重复问题基线。
- 指标：有效讲述、Thread 完整、经验边界、Candidate 确认/修正、重复、跳过原因。
- 禁止单独优化时长、消息数、点击率、连续使用天数或 Persona 依赖。
- 无真实证据前不使用强化学习追求更长会话。

### Slice 5B：Legacy shadow 与 cohort cutover

对应：`WI-S1-01-09/10`、`WI-S1-03-10`、适用 `WP-MIG-01`

- Archive/KBLite/memories/conversation 依 provenance 分级；无 owner/source/decision receipt 的数据进入 review/quarantine。
- shadow parity 后按 Vault CAS 提升 authorityEpoch。
- authority epoch 切换后只允许 compatibility read、freeze、forward fix、rebuild/reconcile，禁止恢复 legacy writer。

### Slice 5C：M0 权利与发布回归

- Capture -> Review -> MemoryVersion -> QA/Citation -> Correction -> Copy/Export/Delete 全闭环。
- Family 只允许静态贡献且必须有明确 AuthZ，不开放人格化家庭 Voice。
- M1-M4 全关时 M0 中性文字核心仍可运行。
- DFX：10 QPS/30 分钟、100 并发突发、retrieval/projection lag、Context Packet 容量和 cross-vault/citation 正确性按终版验收清单执行。

M0 Exit：GIC-001..016、STOP-R5-01/03/04、STOP-REG-01/05/06、适用 G0/G1/G2 和产品 G4 均有证据；否则只可保持受控 cohort。

## 11. Phase 6：R4 真实媒体质量

对应：`WI-S1-01-11/12`、`WI-S1-02-11`

- 私有对象上传 intent、校验、扫描、处理、缩略图/转写/视觉分析和删除回执。
- 音频只把已确认转写或用户说明送入 Candidate；视频/图片失败分析不注入空线索。
- mock/local-only/临时 URL 不能标为 uploaded/verified。
- 每种媒体独立 capability/cohort，可失败降级为本地草稿，不阻断 M0 文字核心。

## 12. Phase 7：M1 在世本人私有 Voice

对应：`WP-V0-01` 的 M1 切片。

1. 只允许在世成年人本人 `subject=actor`，随机授权语句、活体、质量和专项同意均通过。
2. VoiceProfile/Sample/GeneratedAudio/consent purpose/version 形成 Authority 和 receipt。
3. Provider credential、训练、状态、试听、删除和 unknown reconcile 通过 G3。
4. 生成声音持续 AI 标识；受限文本、不可任意下载、不提供代录。
5. iOS 单一 AudioOwner、PCM drive、打断、停止和麦克风恢复通过真机 G4。
6. Family 成员若使用自己的声音，必须由该成年人在自己的主体身份下独立完成训练和授权；家庭关系不能代替。

M1 失败时回 M0 普通文字/默认非克隆语音，不冒充已使用复刻音色。

## 13. Phase 8：M2 成年授权 Publication/Visitor/Digital Human

对应：`WP-S3-01` 和 `WP-V0-01` 的 M2 切片。

- Owner 主动创建脱敏、版本化、不可变 `PublicationVersion`；Visitor 只读独立公开副本和 Index。
- `ShareGrant` 独立于 Family relationship，包含 subject/purpose/scope/expiry/epoch。
- 只允许成年 Visitor；持续 AI 标识、2 小时提醒、UI/语音/关键词即时退出。
- 依赖、异常长时、替代现实关系和人格化促购触发干预；危机退出 Persona 并切中性安全助手。
- 投诉、争议冻结、紧急下线、撤回传播和 public index 删除可执行。
- 安全评估、算法备案/年度核验、隐私/法律和应用商店材料属于 G4，不能由代码测试关闭。

## 14. Phase 9：M3/M4 默认关闭

M3 老人健康或成人纪念互动、M4 知识许可和收益不进入自动连续开发。只有对应产品 Owner、法律/隐私、Provider 和运营 Gate 提供明确授权后，才从现有 115 Work Item 中启用相关切片。

在启用前只允许：

- schema/contract threat model；
- ReleasePolicy `OFF` 和服务端 hard deny；
- 数据权利、争议冻结和紧急下线设计；
- 不使用真实高敏数据的 synthetic 测试。

## 15. 提交、部署与验证规则

### 15.1 每个 Work Item

1. 开始前确认依赖、Authority lease、工作区差异和已有实现。
2. 先补最小测试/contract/static check，再实现。
3. 运行相关 unit/contract/smoke、`git diff --check` 和适用构建。
4. UI 变化运行模拟器 UIQA 并保存截图；真机只在 G4 阶段执行。
5. 独立提交，提交信息包含 Work Item ID；不得混入无关 dirty files。
6. 更新状态证据和 Registry 后再进入下一项，不反复询问是否继续。

### 15.2 后端变化

- migration 必须先通过空库、升级库、rollback/forward 和 isolated restore。
- 验证通过后提交、推送、部署，运行线上 Postgres smoke 和 readiness；未部署不得声明 G2。
- 外部 effect 必须有 stable request、query/reconcile、cost/usage 和 receipt；timeout/accepted 不直接当 failed 重试。

### 15.3 iOS 变化

- 使用本地签名 `2BTR77V3R8 / com.yxj.dreamjourney.app` 做本机/真机验证，不修改团队默认配置。
- 至少运行 generic iPhoneOS build；UI 变化增加模拟器 smoke。
- iOS 默认只提交当前分支，不自动推送远端，除非用户明确要求。

## 16. Stop Conditions

仅在以下情况暂停询问：

1. 需要新的真实 key、账号、证书、Provider 控制台操作或真实设备人工动作。
2. 要执行不可逆生产迁移、生产数据删除、credential 吊销或公开发布。
3. 终版需求内部出现无法通过“更严格边界优先”解决的实质冲突。
4. 需要法律、隐私、监管或商业 Owner 的正式 G4 决定。
5. 同一 blocker 连续三轮无法取得进展。

外部门阻塞时，将对应任务标记 `EXTERNAL_BLOCKED`，自动切换到不依赖该门的下一个 Work Item。已接受的旧 credential 风险豁免不得再次阻断开发。

## 17. 工作量与里程碑量级

以下是当前单体工程上的工程量级，不含等待 Provider、监管、法务和真实用户研究的日历时间：

| 里程碑 | 估算工程量 | 主要不确定性 |
| --- | --- | --- |
| Phase 0 | 1-3 人日 | canonical 工具与 Registry 状态重算 |
| Phase 1 | 18-30 人日 | 强身份、跨账号 AuthZ、restore、权利传播 |
| Phase 2 | 25-40 人日 | Authority schema、effect kernel、iOS composition/XCTest |
| Phase 3 | 15-25 人日 | Orchestrator 状态与 Candidate 审核体验 |
| Phase 4 | 15-25 人日 | 推荐质量、Projection 和敏感过滤 |
| Phase 5 | 15-30 人日 + 用户研究窗口 | migration/cutover、DFX、GIC 真实体验证据 |
| Phase 6 | 15-30 人日 | 对象存储和真实媒体 Provider |
| Phase 7 | 15-30 人日 + G3/G4 | Voice 供应商、质量、删除和真机音频 |
| Phase 8 | 25-45 人日 + 监管周期 | 独立发布域、持续互动安全和备案 |
| Phase 9 | 暂不估算 | 产品、法律和商业 Gate 未开启 |

对 1 名 iOS + 1 名 Backend + 共享 QA/Product 的小团队，M0 内部工程闭环约为 3-5 个月量级；外部批准和真实用户验证另计。该估算用于排期，不用于降低 Gate 或并行切多个 Authority。

## 18. 当前下一步

从当前基线继续时严格按以下顺序执行：

1. 保持 `WI-S0-04-05` 的恢复切流 `NO_GO` 和 `WI-S0-05-05` 的真实外部清理 Gate；它们不得阻塞互不依赖的本地合同开发，也不得被 mock 或本地状态冒充关闭。
2. `WI-S0-05-06` 的 typed、owner-scoped 数据权利状态 mapper 已完成 scoped G0；不重复实现。`WI-S0-07-09` 的 strict readiness 适配器已完成 scoped G0，G2/G4 仍保持外部门。
3. `WI-S1-01-03` 的用户边界正式命令及其 iOS AccountLease use case 均已完成：复用既有持久化 Conversation/Session 状态，为 `skipOnce`、`cooldown`、`doNotAsk` 增加 owner-scoped、captured `echoTextInput` policy 的默认关闭写入路由；用例层在 request/commit 两侧校验 lease/generation，并拒绝 `open`、回执错配和 stale completion。M0A-26 以 QA-only 界面和 in-memory smoke 覆盖这三种操作的实际 UIButton 触发，不增加公开入口，Release 构建不创建控件。M0A-27 将 `skipOnce` 的消费绑定到下一段 owner narrative 的原子持久化，保证它不会泄漏到下一次追问机会；该路径已在部署容器的隔离 Postgres smoke 验证。M0A-28 只为 `doNotAsk` 增加独立、显式确认且可重放的恢复命令，不向通用边界路径开放 `open`，且只在 QA 面板暴露确认动作；`0038` 已在部署环境应用并通过隔离 Postgres smoke。M0A-29 在正式 narrative append 写入前执行既有 `SafetyPolicy`，明确高风险表达会返回 content-free 的中性安全 override，不写入访谈且不推进版本；后端 `4ebeda0` 已部署并经隔离 Postgres smoke 验证。冷却期到期后已由服务端时钟选择为连续性推荐，并可经独立的 QA-only typed `restore-cooldown` 返回 `active/open`；iOS 已验证该动作的 AccountLease/generation 围栏与 Release 编译剔除。它不自动重开会话。自然语言主题再识别和自动提示恢复仍未实现。不得将这些边界扩展为 Provider、问题正文、Candidate/Memory 写入或公开 Echo UI。
4. 下一步先对 `WP-S1-01` 已登记的 scoped 证据做短盘点，再选择第一个真正缺失的 P0/G0 小闭环。不得仅因 Registry 保守地保留 `PLANNED` 重复实现已部署的 Memory/Projection/QA 边界，也不得开启 G3/G4 或生产 Authority 切流。

在 Phase 0 完成前，不启动新的 M0 功能编码；在 Stage 0 退出前，M0 只允许 additive schema、typed contract、fake 和 shadow，不切生产 Authority。
