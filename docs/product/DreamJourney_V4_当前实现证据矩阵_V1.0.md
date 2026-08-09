# DreamJourney V4 当前实现证据矩阵

版本：V1.5 Current Engineering Refresh
初版日期：2026-07-12
更新日期：2026-08-09
状态：已同步当前代码、统一非真机证据和线上 runtime；非真机合同已关闭，真实 Provider、V4 主链路切换、真机和发布 Gate 仍开放
工程基线：iOS `feature/prd-stitch-ui-adaptation@dfd55c82`；Backend `main@8a61720`；服务器 API runtime `e8eacc5`（后续差异为文档提交）
评审控制面：[DreamJourney V4 评审与验收清单](./DreamJourney_V4_评审与验收清单_V1.0.md)
当前执行计划：[DreamJourney V4 完整功能开发与生产闭环计划](../superpowers/plans/2026-08-09-dreamjourney-v4-complete-functional-development-plan.md)
定稿边界：矩阵中的成熟度仍以当前代码证据为准；26/26 非真机 Gate 通过不表示真实 Provider、G2-G4 或发布批准已经完成。

## 0. 2026-08-09 当前证据快照

### 0.1 验证基线

| 证据域 | 当前结果 | 能证明 | 不能证明 |
| --- | --- | --- | --- |
| iOS XCTest | workspace 296 项通过，0 失败 | 当前 typed contract、状态机和账号隔离回归 | 真实权限、网络、音频和通知 |
| iOS generic device build | Debug 构建通过 | iPhoneOS 编译、依赖和签名前置有效 | 真机体验和 App Store 发布 |
| Backend tests | 1973 项通过，0 失败 | API、持久化、权限、任务和 Provider 合同 | 未启用 Worker/Provider 的生产效果 |
| 统一非真机 Gate | 26/26 通过，M0/Stage 2/M1/M2 lane passed | 代码/合同/default-off 边界完整 | 真实 Provider、真机和发布批准 |
| 线上 `/ready` | database/schema/auth/incident ready | API、数据库、迁移和认证配置健康 | 业务 capability 已开放 |
| 线上 runtime | OTP、媒体、Worker、数字人关闭或阻断 | fail-closed 生效 | 用户已经能使用 V4 主链路 |

证据入口：

- `docs/superpowers/status/2026-08-09-v4-non-device-functional-closure-handoff.md`
- `docs/superpowers/status/2026-08-09-v4-non-device-functional-closure-manifest.json`
- `docs/superpowers/status/2026-08-09-v4-full-engineering-gap-scan.md`

### 0.2 四轴当前判断

| 轴 | 当前判断 | 说明 |
| --- | --- | --- |
| 代码与合同覆盖 | 约 80%–85% | M0–M2 的模型、API、typed client、负向 Gate 和默认关闭大多存在 |
| 真实 Provider / 部署闭环 | 约 35%–45% | API/DB/Redis/ClamAV 与部分声音合成运行；OTP/COS/OCR/ASR/强身份/Worker/DH 未闭环 |
| 可公开发布 V4 功能 | 约 30%–40% | 普通 App 仍主要使用旧 Archive/Context；V4 Owner Truth 与 M1/M2 多数未开放 |
| 发布结论 | `RELEASE_NO_GO` | 外部 Provider、V4 authority cutover、真机和批准未关闭 |

### 0.3 当前真实运行态

| 能力 | 线上状态 | 当前结论 |
| --- | --- | --- |
| Route authentication | `enforce`，191 路由全部分类 | `IMPLEMENTED` |
| Cross-account ownership | `shadow` | `PARTIAL`，等待真实 SMS 身份与部署 shadow evidence |
| OTP identity challenge | disabled/unavailable | `CONFIG_MISSING` |
| Owner Truth media storage | disabled | `CONFIG_MISSING`，等待腾讯 COS |
| ClamAV | sidecar 运行，clean/EICAR smoke 通过 | `PROD_VERIFIED` 扫描器运行条件，不代表媒体闭环 |
| Owner Truth media processing | worker disabled | `DEPLOYMENT_DISABLED` |
| PDF/DOCX/text parser | 代码和隔离 E2E 通过 | `IMPLEMENTED`，等待真实 COS/Worker |
| OCR/ASR | provider disabled | `PROVIDER_REQUIRED` |
| Archive image analysis | DeepSeek text-only，vision unsupported | `PARTIAL`，仅可重试失败合同 |
| Voice clone | 合成 ready；训练被身份/活体 Gate 阻断 | `PARTIAL` |
| Voice provider delete | unsupported | `PARTIAL`，只能先撤销使用权 |
| Tencent Digital Human | configured but broker blocked | `CONTRACT_ONLY`，缺 scoped session credential 证明 |
| Async effects | worker/scheduler disabled | `DEPLOYMENT_DISABLED` |
| Publication/Visitor | 非真机合同完成，default-off | `IMPLEMENTED` 代码 / `EXTERNAL_ACCEPTANCE` 发布 |

### 0.4 历史内容使用规则

第 2.2、2.3、6.1–6.3、7.1–7.10 中保留的 2026-07 设计/风险记录用于解释演进，不再覆盖本节和第 5 节的当前状态。若历史行与当前源码、线上 runtime 或本轮证据冲突，以第 0 节、第 5 节和当前源码为准。

## 1. 使用规则

本矩阵只描述可验证状态，不用“已有页面”“已有数据结构”代替完整业务验收。四个状态轴必须分开：

- `实现成熟度`：当前 iOS/后端代码闭环的最弱实现状态，不包含产品批准或外部验收。
- `决策门`：尚未关闭的 Product/Privacy/Security/Commercial Decision ID；`NONE` 不表示产品已批准，只表示没有额外专项决定。
- `外部门`：真机、provider、地域、合同、生产、渗透或用户研究证据；列出即表示尚未通过。
- `当前暴露`：`PUBLIC_PARTIAL / BETA_UNVERIFIED / HIDDEN_QA / DISABLED / CROSS_CUTTING`，不等于成熟度。

状态枚举：

| 状态 | 含义 |
| --- | --- |
| `PROD_VERIFIED` | 代码、真实后端/部署和适用设备或 provider 验收均有证据 |
| `IMPLEMENTED` | 已有真实代码和自动化验证，但仍缺外部/真机/规模验收 |
| `CONTRACT_ONLY` | 数据模型、API 或壳层已存在，业务链路未完成 |
| `HIDDEN_QA` | 仅通过 feature flag、launch arg 或 QA 入口可用 |
| `MOCK_ONLY` | 仅 mock/seed/fallback，可证明状态机但不证明生产能力 |
| `PARTIAL` | 只覆盖需求的一部分，不能宣称完整实现 |
| `MISSING` | 当前工程未发现对应实现 |
| `DECISION_REQUIRED` | 必须先完成产品、合规或商业决策 |
| `EXTERNAL_ACCEPTANCE` | 代码已具备，但必须由真机、provider、证书或生产环境验收 |

每项结论使用以下证据等级：

- `E1`：当前源码、测试、构建产物或生产部署证据。
- `E2`：用户在当前项目中明确确认的产品决策。
- `E3`：最新 PRD 的评审要求。
- `E4`：Blueprint、架构分析或既有 canonical design。
- `E5`：Hermes/AOS 本地可见源码机制。
- `E6`：分析推断，只能形成待验证问题。

## 2. 来源登记

| 来源 | 类型 | 权威等级 | 可用于证明 | 不能用于证明 |
| --- | --- | --- | --- | --- |
| `DreamJourney_dev` 当前源码、QA、Git 历史 | 工程事实 | E1 | iOS 已实现行为、flag、构建和自动化边界 | 真实 provider、真机体验和产品批准 |
| `DreamJourneyBackend` 当前源码、测试、部署证据 | 工程事实 | E1 | API、持久化、授权、任务和部署合同 | 未执行的生产规模与第三方 SLA |
| 用户明确确认的历史产品决策 | 产品决策 | E2 | 当前公开/隐藏策略和重大取舍 | 未被明确讨论的新 PRD 范围 |
| `寻梦环游_产品问题风险分级与整体规避方案_V1.0.md` | 2026-07-16 产品/合规风险基线 | E2/E3 | 新规生效后的禁用能力、M0-M4 范围、发布 Gate 与产品表达 | 工程已实现、法律意见或监管程序已完成 |
| `DreamJourney_V4_引导式访谈与知识丰满化功能说明_V1.0.md` | 2026-07-16 引导式访谈产品合同 | E2/E3 | 一个自然入口、两类动态推荐、访谈编排、用户控制、知识地图 Projection 与验收要求 | 当前代码已实现、推荐效果或真实用户接受度 |
| `寻梦环游_个人记忆库与数字分身平台_PRD_V1.0.md` | 评审 PRD | E3 | 目标需求、验收、指标和非目标 | 已实现状态或已批准发布日期 |
| `DreamJourney_V3_产品蓝图_Product_Blueprint_V3.0.md` | 产品蓝图草案 | E4 | 领域方向与候选阶段划分 | 当前代码事实或最终 IA |
| `寻梦环游_iOS工程_PRD_目标架构一致性分析_V1.0.md` | 架构分析 | E4 | 术语冲突与迁移建议 | 产品范围批准或完整代码审计 |
| `2026-07-11-product-knowledge-base-architecture-v2.md` | 已执行架构基线 | E1/E4 | 当前知识管线、安全边界和已完成任务 | Publication/Visitor 等新产品域 |
| `Hermes-Skills-All_AOS-Memory_Analysis.md` | 静态分析 | E4/E6 | 待验证 AOS 概念线索 | 完整 AOS 生产实现 |
| `/Users/yxj/Documents/Codex/AI/Hermes-Skills-All/aos-memory-project/code` | 部分 Go 源码 | E5 | 感知、动作、验证、规则和技能蒸馏局部机制 | MemoryStore、MCP、索引和完整部署能力 |

### 2.1 2026-07-16 E2/E3 产品与监管增量

当前增量基线：三 Tab；手机号注册登录；R3 Owner文字核心、自传、静态“Ta 的故事”、Family材料贡献、复制/导出/删除构成 M0；M0 的采集入口采用一个自然输入和最多两条动态推荐，由访谈编排器在用户控制下补充连续性与知识完整性；M1 只允许在世成年人本人私有Voice；M2 只允许在世主体主动发布和成年 Visitor 的文字/语音/DH；M3 承载老人健康与成人纪念逐案试点；M4 承载知识许可。未成年人虚拟亲属、未成年人 Voice/Persona、人格化促购、人格参与重大现实决策和无生前专项授权的逝者 Voice/DH 为硬拒绝。Provider、地域、真机、安全评估、算法备案与生产证据不因产品确认自动关闭。

### 2.2 2026-07-12 历史审计基线与可复现性

本节冻结 Task 27 当时的审计输入，不代表 2026-08-09 当前工程状态；当前验证以第 0 节为准。

| 项目 | 基线 | 工作区状态/证据 | 限制 |
| --- | --- | --- | --- |
| iOS | `feature/prd-stitch-ui-adaptation@8a1922b`，审计开始时与 `origin` 一致 | Task 27 前无已跟踪业务代码改动；本轮产品附件与成果物尚未提交 | 本任务未重新跑 iOS build/模拟器/真机，不能据此更新设备成熟度 |
| Backend | `main@4c0538b` | 审计开始时 clean；该版本也是当时服务器部署版本 | 本任务未重新部署；线上状态以当时已知版本为准 |
| Backend tests | Round 1 全套测试报告为 304 passed | 已由独立审查执行并核对代码 | 尚无提交到仓库的原始 stdout/artifact，最终验收需重跑并保存报告 |
| iOS tests/build | 未在 Round 1 重跑 | 只使用源码、既有 QA 脚本和历史证据 | 状态=`NOT_RUN_IN_TASK_27` |
| 真机/provider | 未在 Round 1 重跑 | 只保留证据矩阵中的历史边界 | 状态=`EXTERNAL_NOT_RERUN` |
| 签署时间 | 2026-07-12（Asia/Shanghai） | Task 27 Round 1/2 文档检查 | 任何后续代码提交都需要更新 commit 和受影响行 |

### 2.3 2026-07-16 当时的新规实现缺口（历史）

以下项目记录 2026-07-16 当时的目标变化和缺口。多数合同已在后续提交实现，当前判断必须回到第 0 节和第 5 节，不得继续把本表的 `MISSING` 作为当前排期依据。

| 新控制项 | 当前证据判断 | 安全默认 |
| --- | --- | --- |
| 未成年人虚拟亲属服务端硬阻断 | `MISSING`；当前 Family/Persona/feature flag 没有证明年龄+角色实质双重拒绝 | 所有未成年人 Persona/Voice/DH/Visitor route `DENY` |
| M1 仅在世成年人本人训练声音 | `PARTIAL`；当前有录音/授权UI和Provider训练，但缺 subject=actor、成年人、随机语句和活体硬门，且存在 Family profile 路径 | 隐藏 Family 代录；不满足本人证明不发 Provider |
| M2 成年 Visitor 与在世主体发布 | `MISSING`；无 Publication、adult verification、独立读取角色或Visitor authority | Publication/Visitor/DH 全部 default-off |
| AI持续标识、依赖与2小时提醒 | `MISSING`；现有状态文案/数字人提示不能证明统一策略 | 禁止 M2/M3 人格化互动 |
| UI/语音/关键词确定性退出 | `PARTIAL/MISSING`；现有页面关闭和runtime release不等于三通道即时退出，且未证明Persona不挽留 | 只提供中性文字或直接关闭人格能力 |
| 危机切换中性助手与联系人 | `MISSING`；无统一风险判定、紧急联系人或演练 | 高风险表达拒绝 Persona/延迟/Provider effect |
| 人格化促购与重大决策阻断 | `MISSING`；无服务端支付/高风险意图隔离证据 | Persona 不进入支付、医疗金融、法律或关系承诺链 |
| 安全评估、算法备案、上架合规包 | `EXTERNAL_REQUIRED`；未见报告/备案/年度核验/上架材料证据 | M2/M3 `NO_GO` |
| M0 本人数据复制/导出 | `PARTIAL`；只有QA导出，未形成产品化可读/可机读导出和第三方裁剪 | 不宣称可迁移，M0退出门保持开放 |
| 平台/Provider 通用训练禁用 | `EXTERNAL_REQUIRED`；当前Provider合同和平台训练数据清单不足 | 私人/敏感正文、声音、人脸、健康和未成年人数据不进入通用训练 |
| Interview Orchestrator 与 Thread 状态 | `MISSING`；未发现服务端 `InterviewSession/ConversationThread/ThreadPreference/InterviewDecision` Authority，也未证明每轮单问题、2至4轮总结和疲劳/跳过控制 | 退化为普通中性文字输入；不得宣称已实现结构化引导 |
| 一个自然入口与两类动态推荐 | `MISSING`；未发现连续性/完整性固定角色、最多两条、去重、过期和少于两条的完整 UI/服务端合同 | 推荐默认关闭；自然输入保持可用，不用静态主题卡伪装动态推荐 |
| Knowledge Dimension Coverage / Gap | `PARTIAL/MISSING`；现有 KBLite 可作为 Projection 输入，但没有六维覆盖、缺口、证据绑定或 Candidate 不计确认覆盖的实现证据 | 不显示完成百分比，不用 AI 推断或未确认 Candidate 驱动主动推荐 |

## 3. 已识别的跨文档冲突

| ID | 冲突 | 当前安全默认 | 所需动作 |
| --- | --- | --- | --- |
| C-01 | 当前公开 IA 为“记忆档案 / 回响 / 我的”，Blueprint 建议“首页 / 记录 / 记忆 / 分身” | 已确认保留现有三 Tab，家人管理位于“我的” | 实现与真机验收 |
| C-02 | 旧 PRD/7月15基线把 Publication/Visitor 放进统一 MVP；新规风险基线要求持续人格化互动后置 | M0 不开放 Visitor；M2 仅在世主体主动发布、成年 Visitor、独立副本/读取角色，并增加安全评估、算法备案与安全门 | WP-S3-01 + G2/G4/监管证据 |
| C-03 | 当前工程已有 Family/Care/TimeLetter 隐藏合同和部分 UI，但新范围分层不同 | M0 只开放 Family 材料贡献、人物切换与静态故事；持续查询属M2；Care/TimeLetter后置 | Family 横切实现、AuthZ 与服务端阶段硬门 |
| C-04 | 可创建逝者 MemorialVault，但当前 Family role/voiceProfile 未实现权利与安全模型 | M0 只保留静态纪念；现有 family voice 不能迁为逝者授权；无生前专项授权 Voice/DH=`NO_GO`，成人纪念互动最多进入M3逐案试点 | DR-004/036 + Provider/法律/监管与实现 |
| C-05 | 旧产品回复“不支持首版导出”与新规风险基线、停服迁移和用户控制冲突 | M0 提供本人交互、资料、已确认记忆和自传的可读导出与可机读清单；第三方受限内容裁剪 | Data Rights 实现 + G4格式/裁剪验收 |
| C-06 | 最新 PRD 要求独立公开人格知识域，当前 Knowledge 主要服务私人/家庭 Echo Context | 私人知识不得通过过滤视图直接公开 | 新建 Publication 边界设计 |
| C-07 | 新 PRD 要求候选记忆审核，当前提取允许部分 observed 内容直接进入私人生成门禁，且没有访谈编排与知识缺口控制 | 已确认一个自然入口、连续性/完整性双推荐、每轮单问题、2至4轮总结与每5–10轮或退出批量确认；未确认内容不进确定性 QA/Publication | ConversationThread/Orchestrator + Candidate/Memory 实现与 legacy 迁移 |
| C-08 | 当前核心 Echo 依赖火山实时语音与腾讯数字人链路 | M0 中性文字 QA 独立；M1 仅在世成年人本人私有 Voice；M2 在世成年 DH；M3 成人纪念逐案。三条 runtime 分开验收 | Conversation + Voice/DH G3/G4/监管 |
| C-09 | PRD 要求对象存储直传和 PDF/DOCX/OCR/ASR，当前媒体能力存在 mock upload intent 和部分 provider fallback | 不宣称文件处理 P0 完成 | 后端存储/任务方案 |
| C-10 | PRD 将 Visitor 设为匿名分享入口，当前认证/ownership 主要面向注册用户和家庭授权 | M2 仅允许完成成年校验的认证/受邀访问；匿名、未成年人和 Family关系自动授权均拒绝 | Adult Visitor identity/AuthZ/限流/退出实现 |
| C-11 | PRD 的账号删除要求全链路资产删除，当前实现包含 30 日 soft delete/一次恢复产品合同 | 已确认账号30日恢复；上传人删除自己的 Source 不可撤回并暂停依赖 | 分层 purge/provider receipt + G4 |
| C-12 | AOS 分析声称 MemoryStore/Slot/Scatter 等能力，但本地包缺少完整实现 | 仅借鉴原则，不列为可集成组件 | 证据审计 |
| C-13 | 36 条 FR 中有 32 条为 P0，优先级无法表达阶段依赖 | 已按 M0-M4 和规模触发重映射115项；旧lane token仅作机器兼容 | Roadmap/Registry 同步 |
| C-14 | 旧 PRD M0 要求声音克隆和实时语音，与新规风险分层冲突 | Voice不再阻塞M0；M1只允许在世成年人本人私用，DH进入M2/M3独立门 | Voice G3/G4、评估/备案与真机 |
| C-15 | PRD 的 Source 包含“对话消息”，但未明确 assistant 回复是否可作为证据 | 已确认 `userEvidenceOnly`；assistant 只作上下文，用户陈述经批次确认后才入记忆 | 实现 typed Candidate batch |
| C-16 | 删除 Source 只要求提示影响，记忆纠正后 Publication 只标记待确认，公开失效时点不明确 | 已确认 Source 删除/Memory修正/异议/grant过期立即 suspend 依赖 Publication | 撤回 SLO 与传播回执 |
| C-17 | 地域、声音供应商、活体、音频留存和单位成本影响 MVP 架构 | 中国首发、认证/受邀 Visitor 已确认；具体 processor/跨境/Provider条款仍是外部门，精确预算暂缓但工程硬配额必须存在 | G3/G4 + 扩量预算 |
| C-18 | Blueprint 使用“完全可控、可信”等绝对承诺，PRD 同时承认 AI 错误和供应商删除限制 | 对外改为“用户可管理、证据可追溯、边界可审计”，禁止绝对保证 | 产品文案决策 |
| C-19 | PRD 缺少单一北极星，持续率、声音完成率、发布转化率和单位成本没有发布门槛 | 已确认 WTMR 北极星与 DFX 测量合同；阈值仍需真实 cohort 校准 | 服务端事件与基线测量 |
| C-20 | Hermes-Skills-All 当前目录权限过宽，配置和 memory 文件含非空凭据/基础设施信息 | 按潜在泄漏处理，不把该目录纳入 DreamJourney 仓库；轮换凭据并收紧权限 | 安全整改 |
| C-21 | AOS 文档同时主张原始数据永久保存和 forget/delete，但缺少 WAL、版本链、图边、缓存与备份删除证明 | 不采用永久 TimeRiver 设计；DreamJourney 删除矩阵必须覆盖所有副本 | 隐私架构 |

## 4. Hermes/AOS 可借鉴边界

### 4.1 建议吸收的原则

| 原则 | 可验证证据 | DreamJourney 落点 |
| --- | --- | --- |
| 用户画像与情景记忆分层 | Hermes 使用独立 `USER.md` 与 `MEMORY.md`，但格式仍是扁平文本 | Persona profile 与 Memory 分域，使用结构化对象和独立权限 |
| 原始感知先缓冲、确认后升格 | `perception_loop.go` 将结果写入 perception pool，不直接写长期 MemoryStore | Source/对话先形成 Candidate，策略或 Owner 确认后成为正式记忆 |
| 原始证据与派生知识分层 | `research/llm-wiki/SKILL.md` 描述 immutable raw、派生页面、来源、hash 和冲突 | Source 为可追溯记录，Confirmed Memory 表示 Owner 当前认可版本，Knowledge 为可重建 Projection |
| 小状态预取、细节按需拉取 | driving-mode 文档提出精简 state report 与按需 recall | 延续 Context Packet：先 policy/ranking/cap，再按 source 引用展开 |
| 有界编排和持久任务账本 | Hermes 文档与配置存在并发/深度约束和任务状态 | 异步处理采用显式 DAG、幂等键、取消/超时、状态与审计，不引入通用 Agent 自治 |
| 程序性能力需要重复成功和验证 | AOS `action_loop.go` / `skill_distiller.go` 存在三次成功后固化原型 | 仅作为未来自动化原则；不进入个人记忆 MVP |

### 4.2 明确不照搬

- 不采用扁平 Markdown 作为正式记忆存储；它缺少稳定 ID、来源、时间语义、置信度、同意范围、保留期和版本关系。
- 不采用缺少完整源码与基准的 20736 槽位、六维权重、三温区、自研二进制和 TimeRiver。
- 不把 namespace 当授权边界；授权必须绑定 principal、owner/persona、用途和操作。
- 不采用现有技能蒸馏实现：当前复放/截图验证、失败回退、风险审批和测试均不足。
- 不把“纯本地”当作天然隐私；落盘、日志、导出、备份和云端 LLM 出站仍需明确政策。
- 不采信没有固定语料、模型、参数和原始结果的 token、性能、召回或隐私数字。

## 5. PRD Requirement 覆盖矩阵

每个 FR 只有一个主交付阶段；跨阶段准备通过 `决策门`、`外部门` 和缺口描述表达，不再把“Stage 0 决策、Stage 1 实现”写进同一阶段字段。

| Requirement | PRD | iOS 实现 | 后端实现 | 决策门 | 外部门（未通过） | 当前暴露 | 实现成熟度 | 主交付阶段 | 主要证据/缺口 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FR-ACC-001 | P0 | `IMPLEMENTED` v2 challenge/session client | `IMPLEMENTED` provider-neutral OTP/session contract | CONFIRMED: DR-023/024; OPEN: DR-035 | 真实 SMS、渗透、恢复真机 | PUBLIC_PARTIAL | `PARTIAL` | M0 Identity | 线上 OTP adapter disabled；legacy login 已关闭，真实新用户当前不能登录 |
| FR-ACC-002 | P0 | `IMPLEMENTED` profile/family shell | `IMPLEMENTED` family/persona contracts | CONFIRMED: DR-003/004/023; EXTERNAL: DR-022/036 | 身份、关系证明、产品验收 | HIDDEN_QA | `PARTIAL` | M0 Family Contribution | 邀请/接受/静态贡献存在；家庭关系不授予 Vault、Voice、Persona 或 DH 自动读取权 |
| FR-SRC-001 | P0 | `IMPLEMENTED` typed V2 capture/task state | `IMPLEMENTED` COS/SourceObject/scanner adapter | OPEN: DR-026/031 | COS bucket、SSE、删除回执 | HIDDEN_QA | `IMPLEMENTED` | M0 Stage 2 Media | 代码与 fake/ClamAV Gate 完成；线上 media storage disabled，等待真实腾讯 COS |
| FR-SRC-002 | P0 | `IMPLEMENTED` unified media/file intake | `IMPLEMENTED` text/PDF/DOCX + OCR/ASR ports | OPEN: DR-026/031 | COS、OCR/ASR Provider、真机大文件 | HIDDEN_QA | `PARTIAL` | M0 Stage 2 Media | 本地 parser 与隔离 E2E 已过；OCR/ASR disabled，视频保持 storage-only |
| FR-SRC-003 | P0 | `IMPLEMENTED` delete/status UI | `IMPLEMENTED` revoke-first/delete receipt | CONFIRMED: DR-011/039; OPEN: DR-035 | COS/provider/备份删除 | HIDDEN_QA | `IMPLEMENTED` | M0 Data Rights | 访问撤销、幂等 effect、partial/unknown 已实现；真实对象与 Provider 回执待接入 |
| FR-CHAT-001 | P0 | `IMPLEMENTED` owner-scoped conversation/interview UI | `IMPLEMENTED` InterviewSession/Thread contracts | CONFIRMED: DR-008/015 | closed-pilot、真实用户研究 | HIDDEN_QA | `IMPLEMENTED` | M0 Owner Truth | 自然输入、单问题、节奏、topic switch 和结果壳层已完成非真机闭环，尚未公开 |
| FR-CHAT-002 | P0 | `IMPLEMENTED` extraction/recommendation client | `IMPLEMENTED` Source/Candidate/双推荐 authority | CONFIRMED: DR-007/015; EXTERNAL: DR-031 | 模型质量、真实 cohort | HIDDEN_QA | `IMPLEMENTED` | M0 Owner Truth | 连续性/完整性最多两条、去重、反馈和知识维度均有合同与 Gate |
| FR-CHAT-003 | P0 | `IMPLEMENTED` pause/skip/do-not-ask UI | `IMPLEMENTED` preference/cooldown/reactivation contracts | CONFIRMED: DR-007/015; EXTERNAL: DR-022/036 | 敏感语料、真实体验 | HIDDEN_QA | `IMPLEMENTED` | M0 Owner Truth | 用户控制和 fail-closed 已实现；仍需 closed-pilot 体验验收 |
| FR-VOICE-001 | P0 | `IMPLEMENTED` consent/sample shell | `IMPLEMENTED` eligibility preflight/training adapter | CONFIRMED: DR-004/008/014/023/037; EXTERNAL: DR-026/031/036 | 成年本人/活体 Provider、质量、真机 | BETA_UNVERIFIED | `PARTIAL` | M1 Living Self Voice | 火山训练配置存在，但服务端因 identityLivenessProviderUnavailable 拒绝新训练 |
| FR-VOICE-002 | P0 | `IMPLEMENTED` profile lifecycle UI | `IMPLEMENTED` lifecycle/operation matrix | CONFIRMED: DR-011/037/039; EXTERNAL: DR-031 | Provider 删除能力与回执 | BETA_UNVERIFIED | `PARTIAL` | M1 Living Self Voice | training→previewReady→accepted、pause/delete 均有合同；Provider 删除仍 unsupported |
| FR-VOICE-003 | P0 | `IMPLEMENTED` Echo audio-owner/runtime | `IMPLEMENTED` synthesis/binding v2/PCM adapter | CONFIRMED: DR-008/014/037/039; DEFERRED: DR-027 | 真机听感、路由、延迟 | BETA_UNVERIFIED | `IMPLEMENTED` | M1 Living Self Voice | accepted profile 强绑定已验证；真实有声、口型、打断和麦克风恢复仍是真机 Gate |
| FR-VOICE-004 | P0 | `HIDDEN_QA` Visitor voice shell | `IMPLEMENTED` Publication/Visitor voice policy | CONFIRMED: DR-002/004/010/014/038; EXTERNAL: DR-036 | 成年 Visitor、法律、安全、Provider | DISABLED | `CONTRACT_ONLY` | M2 Publication/Visitor | default-off；M0/M1 不允许公开 Voice，也不允许逝者或家庭关系自动授权 |
| FR-VOICE-005 | P0 | `IMPLEMENTED` disclosure/exit states | `IMPLEMENTED` consent/safety/delete boundary | CONFIRMED: DR-004/028/037; EXTERNAL: DR-031/036 | Provider 保留/删除、监管、真机 | BETA_UNVERIFIED | `PARTIAL` | M1 Living Self Voice | 审计与明确失败已实现；第三方删除 SLA、规模和监管证据未关闭 |
| FR-MEM-001 | P0 | `IMPLEMENTED` Candidate Inbox/detail/correction | `IMPLEMENTED` Candidate decision/history authority | CONFIRMED: DR-007/015; OPEN: DR-034 | legacy migration、closed-pilot | HIDDEN_QA | `IMPLEMENTED` | M0 Owner Truth | accepted/corrected/rejected/invalidated 与来源片段可追踪，人工确认后才激活 MemoryVersion |
| FR-MEM-002 | P0 | `IMPLEMENTED` version/life-map/coverage UI | `IMPLEMENTED` MemoryVersion/projection/search contracts | CONFIRMED: DR-029; OPEN: DR-034 | migration/recovery、真实 cohort | HIDDEN_QA | `IMPLEMENTED` | M0 Owner Truth | current/superseded、知识维度和 Projection 已实现；普通 App 仍未完成 V4 authority cutover |
| FR-MEM-003 | P1 | `PARTIAL` merge/conflict UI primitives | `IMPLEMENTED` three-way merge/governance primitives | INHERITS V4 | 语义模型评测 | DISABLED | `PARTIAL` | M3/M4 Deferred | 当前只具备结构化冲突/合并基础，不宣称完成语义冲突检测 |
| FR-MEM-004 | P1 | `PARTIAL` graph/life-map presentation | `IMPLEMENTED` association/thread projections | OPEN: DR-022/036 | 第三方权利、产品 UX | HIDDEN_QA | `PARTIAL` | M3/M4 Deferred | 可逆关系 Projection 已有；跨人物公开关系和第三方确认仍不开放 |
| FR-QA-001 | P0 | `IMPLEMENTED` Echo/citation/trace | `IMPLEMENTED` V4 context authority + legacy context | CONFIRMED: DR-007/008; OPEN: DR-034 | V4 主路径切换、LLM/来源真机 UX | PUBLIC_PARTIAL | `PARTIAL` | M0 Owner Truth | V4 Context closed-pilot contract 已完成；普通 Echo 仍以旧 /context/build 为主 |
| FR-QA-002 | P1 | `IMPLEMENTED` answer correction flow | `IMPLEMENTED` source/candidate/version correction | CONFIRMED: DR-007/015 | closed-pilot、真实质量 | HIDDEN_QA | `IMPLEMENTED` | M0 Owner Truth | 回答错误可定位 citation 并生成更正；未完成公开主链路切换 |
| FR-PUB-001 | P0 | `HIDDEN_QA` publication shell | `IMPLEMENTED` PublicationVersion authority | CONFIRMED: DR-002/006/016/033 | 成年身份、法律、安全、外部索引 | DISABLED | `IMPLEMENTED` | M2 Publication/Visitor | 独立副本与主动发布合同已实现，发布政策仍 externalBlocked |
| FR-PUB-002 | P0 | `HIDDEN_QA` withdrawal state | `IMPLEMENTED` lifecycle/revoke/cleanup contracts | CONFIRMED: DR-006/016/039 | 索引失效、Provider cleanup SLO | DISABLED | `IMPLEMENTED` | M2 Publication/Visitor | 撤回传播和外部 cleanup 已有非真机 Gate，Worker/Provider 未启用 |
| FR-PUB-003 | P0 | `HIDDEN_QA` persona/disclosure shell | `IMPLEMENTED` living/adult/safety policy | CONFIRMED: DR-002/006; REJECTED: DR-018 | 安全评估、算法/AI 标识、法律 | DISABLED | `IMPLEMENTED` | M2 Publication/Visitor | 未成年人和逝者硬拒绝；五方发布批准仍缺失 |
| FR-VIS-001 | P0 | `HIDDEN_QA` visitor/share shell | `IMPLEMENTED` ShareGrant/Visitor session authority | CONFIRMED: DR-010/038 | 成年身份、限流、联系人、真机 | DISABLED | `IMPLEMENTED` | M2 Publication/Visitor | 邀请、TTL、撤回和 owner 隔离已实现；真实 Visitor 身份未接入 |
| FR-VIS-002 | P0 | `HIDDEN_QA` visitor answer shell | `IMPLEMENTED` public retrieval/safety/exit contracts | CONFIRMED: DR-006/010/038 | LLM 安全、依赖提醒、长会话真机 | DISABLED | `IMPLEMENTED` | M2 Publication/Visitor | 只读 Publication Context；2 小时提醒与确定性退出合同已固定，尚未发布 |
| FR-VIS-003 | P1 | `HIDDEN_QA` reporting/message shell | `IMPLEMENTED` feedback/privacy contracts | CONFIRMED: DR-010/038 | 运营流程、投诉演练 | DISABLED | `IMPLEMENTED` | M2 Publication/Visitor | Owner 不可见 Visitor 正文；运营处理和外部证据未关闭 |
| FR-PRIV-001 | P0 | `IMPLEMENTED` owner-scoped stores/leases | `IMPLEMENTED` route auth + shadow ownership | CONFIRMED: DR-023/024; OPEN: DR-035 | SMS 身份、deployed shadow、渗透 | CROSS_CUTTING | `PARTIAL` | M0 Identity | route auth 已 enforce；ownership 仍 shadow，等待真实身份后按 cohort enforce |
| FR-PRIV-002 | P0 | `IMPLEMENTED` privacy/disclosure surfaces | `IMPLEMENTED` scope/consent/policy contracts | CONFIRMED: DR-004; OPEN: DR-035; EXTERNAL: DR-036 | 隐私/法律评审 | CROSS_CUTTING | `PARTIAL` | M0 Data Rights | 数据分类和 fail-closed 已实现，跨域 Provider/法律证据未完整 |
| FR-PRIV-003 | P0 | `IMPLEMENTED` family authorization UI | `IMPLEMENTED` family contribution/hard-deny policy | CONFIRMED: DR-003/004; EXTERNAL: DR-022/036 | 关系证明、第三方权利 | CROSS_CUTTING | `PARTIAL` | M0 Family Contribution | 静态贡献可控且不授予 Vault 读取；争议冻结/近亲属权利仍是后续门 |
| FR-PRIV-004 | P0 | `IMPLEMENTED` export job/status/share | `IMPLEMENTED` ExportJob/CopyExportManifest | CONFIRMED: DR-005/039; OPEN: DR-035 | 真实 COS 字节、格式/裁剪验收 | HIDDEN_QA | `IMPLEMENTED` | M0 Data Rights | 异步状态、过期和部分清单完成；真实媒体字节等待 COS |
| FR-PRIV-005 | P0 | `IMPLEMENTED` delete/restore UI | `IMPLEMENTED` soft delete/purge/effect reconcile | CONFIRMED: DR-011/039; OPEN: DR-035 | Provider/备份删除、恢复演练 | PUBLIC_PARTIAL | `IMPLEMENTED` | M0 Data Rights | 30 日和一次恢复已实现；真实外部删除回执仍 partial/unsupported |
| FR-PRIV-006 | P0 | `IMPLEMENTED` voice/DH scope states | `IMPLEMENTED` eligibility/consent/hard deny | CONFIRMED: DR-004/037; EXTERNAL: DR-031/036 | 强身份、Provider、监管、真机 | BETA_UNVERIFIED | `PARTIAL` | M1 Living Self Voice | M1 仅在世成年人本人；逝者、未成年人和家人代录服务端拒绝 |
| FR-SAFE-001 | P0 | `IMPLEMENTED` disclosure/exit/fallback states | `IMPLEMENTED` safety/eligibility policies | CONFIRMED: DR-025; EXTERNAL: DR-026/036 | 联系人、地区资源、安全评估/备案 | CROSS_CUTTING | `PARTIAL` | M0 Owner Truth | M0 中性回退与高风险硬拒绝存在；M2/M3 危机演练和地区资源未关闭 |
| FR-SAFE-002 | P0 | `HIDDEN_QA` Visitor abuse UX | `IMPLEMENTED` Visitor limiter/exit/report contracts | CONFIRMED: DR-010/038 | 成年身份、压测、公网、投诉演练 | DISABLED | `IMPLEMENTED` | M2 Publication/Visitor | default-off，只有外部安全门关闭后才能 beta |
| FR-OPS-001 | P0 | `IMPLEMENTED` runtime/readiness states | `IMPLEMENTED` typed jobs/outbox/dead-letter/replay | CONFIRMED: DR-024; OPEN: DR-035 | Worker 部署、故障演练 | HIDDEN_QA | `IMPLEMENTED` | Cross-cutting Operations | 代码完成但生产 Worker/scheduler disabled，不能宣称异步效果自动完成 |
| FR-OPS-002 | P0 | `IMPLEMENTED` Echo/readiness evidence | `IMPLEMENTED` provider/runtime/cost evidence | CONFIRMED: DR-032/039; DEFERRED: DR-027 | 生产负载、成本阈值 | HIDDEN_QA | `IMPLEMENTED` | Cross-cutting Operations | Context/voice/DH evidence 可导出；真实 SLA 与成本阈值待 cohort 校准 |
| FR-OPS-003 | P0 | `IMPLEMENTED` operation/data-rights states | `IMPLEMENTED` receipts/reconcile/manual review | CONFIRMED: DR-024/039; OPEN: DR-035 | 外部 Provider 回执、恢复演练 | CROSS_CUTTING | `IMPLEMENTED` | Cross-cutting Operations | 五域 effect 与 dead-letter 合同完成；真实 Provider/备份完成回执未接齐 |

## 6. iOS 工程模块证据矩阵

### 6.0 2026-08-09 当前 iOS 摘要

| 能力域 | 当前代码状态 | 当前产品状态 | 剩余主任务 |
| --- | --- | --- | --- |
| Account/Auth | v2 challenge/session typed client、refresh rotation、账号 lease 已实现 | 真实 OTP disabled | 接短信 Provider，真机登录/恢复 |
| Archive/Owner Truth | V2 Source、媒体任务、Candidate、MemoryVersion、审核/更正 UI 已实现 | closed-pilot/default-off；旧 Archive 写路径仍在 | 真实 COS/Worker 后切 V2，旧路径只读 |
| Echo/Context | Context V2、citation、trace、evidence 和 authority client 已实现 | 普通 Echo 仍使用旧 `/context/build` | closed-pilot 切 V4 authority，移除旧回答 fallback |
| Data Rights | ExportJob、删除状态、账号租约和分享清理已实现 | 真实媒体字节/Provider receipt 不完整 | 接 COS/Provider 外部效果 |
| Voice | profile lifecycle、binding v2、PCM/audio-owner、失败收敛已实现 | 训练被强身份 Gate 阻断，真机未验收 | 强身份、真实训练/delete、真机音频 |
| Publication/Visitor | QA-only/default-off 壳层与 typed client 已实现 | 不公开 | 等 M2 外部门后受控 beta |
| Digital Human | SDK adapter、lease、lifecycle、fallback 已实现 | runtime blocked | scoped credential 合同或替代路径 |

### 6.H 2026-07-16 历史 iOS 审计（仅用于演进追溯）

| 能力域 | 成熟度 | 当前可复用实现 | 关键缺口与证据 |
| --- | --- | --- | --- |
| Account / Auth | `PARTIAL` | `BackendAuthSessionStore` 使用 Keychain 保存 opaque access/refresh session；client 支持 401 refresh coalescing；`UserManager` 已串行化账号切换副作用 | 登录 UI 仍是手机号+密码，真实身份校验由后端缺口阻断；client 仍可发送共享 API token。证据：`BackendAuthSessionStore.swift:53`、`DreamJourneyBackendClient.swift:3738`、`:3838`、`LoginViewController.swift:231` |
| Archive / Source / Media | `PARTIAL` | 公开 Archive 支持文字、照片、本地详情、metadata sync、sourceRef/owner/persona 字段；音频录制和时间信件有本地生命周期；Home 照片和录音 staging 已迁入 AccountLease 派生的账号私有媒体 store，旧全局照片 quarantine、临时录音 discard | 尚无独立 Source Domain；视频入口明确只生成 mock；audio/video upload 默认关闭且后端 intent 为 mock；账号级统一 purge 待 WI-S0-01-08。证据：`ArchiveLocalStorage.swift`、`AccountPrivateMediaStore.swift`、`MemoryArchiveVideoEntryViewController.swift` |
| Knowledge / Memory | `IMPLEMENTED`（Projection） / `MISSING`（V4 权威模型） | KBLite 多账号图谱、evidence/source、Mutation V2、三方合并、governance、change feed、receipt、Context policy 均有代码与 gate；legacy `MemoryRepository` 与 Map presentation 已使用 owner-scoped envelope | 当前仍是 Knowledge/legacy local Projection，不是 Source/Candidate/Canonical Memory 权威模型；审核 UX 和正式记忆版本域缺失。证据：`KBLiteManager.swift`、`MemoryRepository.swift`、`MapFootprintViewController.swift` |
| Echo / Conversation | `PARTIAL` + `EXTERNAL_ACCEPTANCE` | Echo 状态机、Context Packet、延迟回信、ASR/TTS、barge-in、audio owner、数字人生命周期与 QA evidence 很完整；Conversation 本地 cache 已使用 owner-scoped envelope、legacy quarantine 与 AccountLease commit fence | 没有服务端 Conversation/Message 权威存储和独立文字流式会话；也没有一个自然入口/双推荐、Interview Orchestrator、ThreadPreference、疲劳/禁问与知识覆盖 Projection。生产语音仍依赖真机/provider。证据：`ConversationLocalStorage.swift`、`ConversationMemoryManager.swift`、`EchoViewController.swift` |
| Voice Clone / TTS / ASR | `PARTIAL` + `EXTERNAL_ACCEPTANCE` | iOS 只经后端训练/查询/合成，存在授权确认、轮询、试听、启停/删除 UI 和 role voice selection | 缺随机授权语句、活体/本人证明、SNR 质量门、private/public 双授权和 provider 删除回执；家庭音色能力与新 PRD 冲突。证据：`VoiceCloneService.swift:139`、`:545`、`ProfileVoiceCloneShellViewController.swift:129` |
| Tencent Digital Human | `IMPLEMENTED` + `EXTERNAL_ACCEPTANCE` | `DigitalHumanRuntime` protocol、factory、真实 SDK/stub/audio-only fallback、text/PCM drive、interrupt/close 和 lease 生命周期已抽象 | 配额、素材授权、音频/口型和供应商会话仍需真实环境；不应作为私人记忆闭环的前置条件。证据：`DigitalHumanRuntime.swift:51`、`DigitalHumanRuntimeFactory.swift:20`、`EchoViewController.swift:4161` |
| Family / Persona / Care | `PARTIAL` / `CONTRACT_ONLY` | Family invitation authority、persona context、授权 generation、Care snapshot/UI 状态和失败重试已有 | M0 仅允许家庭材料贡献与静态人物查看；当前 Persona 尚非后端权威 Domain。M2 委托查询与发布副本隔离未完成；M3 Care 缺同意、纠错和危机闭环。证据：`FamilyRepository.swift`、`DigitalHumanContextStore.swift`、`ProfileElderCareDashboardViewController.swift:93` |
| TimeLetter / Message | `PARTIAL` / `CONTRACT_ONLY` | 创建/草稿/封存/不可改删、openAt、收件人、本地通知、mailbox、已读/归档和统一消息壳层已实现 | APNs provider delivery 和稳定后台调度尚无完整验收；最新 Blueprint 将 TimeLetter 后置。证据：`MemoryArchiveTextEntryViewController.swift`、`MemoryArchiveRepository.swift:410`、`InAppMessageCenter.swift:181` |
| Publication / Visitor | `MISSING` | 仅遗留 `MemoryRepository.getPublicByOwner()` 与 `isPrivate` 布尔、评论/点赞 mock social model | 无独立 Publication snapshot/index、public persona、Visitor/share/auth/rate-limit/feedback UI；不能复用 `isPrivate=false` 直接公开。证据：`MemoryRepository.swift:58`、`:112`，全工程无正式 Publication/Visitor 模块 |
| Privacy / Delete / Export / Safety | `PARTIAL` | 知识本地文件保护、Echo QA 导出账号隔离、账号 soft-delete UI 和后端合同已有 | M0 要求的交互数据复制、可读导出、机器可读清单和删除状态尚未形成完整自助闭环；30日注销/Source不可撤回删除缺完整传播；logout 不清全部本地业务数据；无 2 小时提醒、确定性退出和结构化危机响应。证据：`ProfileViewController.swift:744`、`UserManager.swift:166`、`KBLiteMultiUser.swift:276` |

### 6.1 2026-07-16 iOS P0 风险（历史）

1. `FeatureFlagService.defaultEnabled` 默认公开 Care、Family、TimeLetter、VoiceClone 和 DigitalHuman；Family/Voice 即使属于目标 MVP 也必须由服务端 AuthZ/capability 放行，Care/TimeLetter/DH 仍不能默认公开。
2. 客户端共享 backend API token 可进入认证头，破坏“客户端不持有系统权限”的信任边界。
3. `MemoryRepository` 已退役全局 UserDefaults live store 和生产自动 seed，改用 owner-scoped legacy projection 与 quarantine；它仍使用 `isPrivate` 表达旧公开语义，不能作为 V4 正式记忆或 Publication 权威源。
4. 账号 switch/logout 已 unmount WI-S0-01-06 的目标 store，但尚无覆盖全部业务 surface 的统一账号级 purge/生命周期协调器；该缺口归 `WI-S0-01-08`。
5. `DeepSeekService` 等历史直连 provider 路径仍需确认是否能在 release 构建触达，并从客户端彻底移除长期密钥。

### 6.2 2026-07-16 可复用稳定模块（历史）

- `KBLiteManager + KnowledgeSyncCoordinator`：保留为客户端 Projection/Cache 与离线 pending，不升级为产品事实源。
- `KnowledgeGenerationPolicy + Context Packet`：保留证据、persona、权限过滤和可观察 trace。
- `DigitalHumanRuntime` adapter：保留供应商隔离和 audio-only fallback，作为 M2/M3 独立运行层，不阻断 M0 文字核心或 M1 本人私有 Voice。
- Echo lifecycle/audio owner/generation guards：保留为 M1 本人 Voice、M2 在世主体 Voice/DH 与 M3 成人纪念互动的稳定运行层，但三层授权和资产不得复用。
- `MemoryArchiveItem/Repository` 的 owner/persona/source metadata：作为 Source 迁移输入，不能直接视为 Source 权威模型。
- `FeatureFlagService` 机制：保留开关能力，但需改为 server/release policy 驱动并修正默认值。

### 6.3 Round 3C2A iOS Account/Store 设计状态（历史）

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| AccountSessionActor/Lease | `DESIGNED` | Product Spec 29.1–29.3 定义 snapshot、generation、CAS 和 8 个异步 checkpoint | 当前仍是 `UserManager`/Keychain/各 service 分散状态，生产 Swift 未实现 |
| 冷启动/账号生命周期 | `DESIGNED` | 29.2 定义 journal 与 login/refresh/switch/logout/revoke/delete 顺序 | 没有 crash recovery、A/B refresh 竞态或 session/profile reconciliation 测试 |
| 本地 store registry | `PARTIAL / WI-S0-01-06 INTERNAL_READY` | S04 Home media、S06 Conversation、S08 Memoir、S09 Memory/Map 已完成 owner scope、legacy quarantine/receipt，并通过 G0/G1 | S07/S10/S11 等后续 surface 与账号级统一 purge 尚未收敛；本地隔离不等于后端业务权威，G4 仍开放 |
| Draft/Archive local-only | `CONTRACT_ONLY` | S03/S04 与场景 11 固定显式 submit/seal 前不建后端 Authority | 当前 TimeLetter draft 仍可能走 repository sync |
| iOS rollout waves | `DESIGNED` | I00–I08 从 XCTest/Actor 到 legacy retirement | 工程尚无 XCTest target，未运行升级/canary/回滚 |
| 本地草稿保留 | `PRODUCT_CONFIRMED / NOT_IMPLEMENTED` | DR-041 已确认 switch/logout/delete 边界 | 加密 owner scope、恢复/清理入口、容量策略与迁移测试尚未实现 |

Round 3C2A 只冻结设备内身份/数据边界，不表示后端强身份、`/v2`、AuthZ enforce 或真实账号迁移已完成。

## 7. 后端工程模块证据矩阵

### 7.0 2026-08-09 当前后端摘要

当前代码基线为 `main@8a61720`，数据库 migration head `0085`。线上 API runtime 为 `e8eacc5`，后续差异仅包含文档提交。当前 route authentication 为 enforce，191 条路由全部分类；ownership 仍为 shadow。

| 能力域 | 当前代码状态 | 线上状态 | 剩余主任务 |
| --- | --- | --- | --- |
| Auth/Ownership | opaque access/refresh、OTP port、191 路由 policy、cross-account audit 已实现 | OTP disabled；ownership shadow | 真实 SMS + shadow evidence 后 enforce |
| Owner Truth | Source/Candidate/MemoryVersion/Context/迁移与 typed API 已实现 | closed-pilot 未入组，Context authority disabled | V2 主路径 cutover |
| Media | COS adapter、ClamAV、解析器、任务/删除 Worker 已实现 | ClamAV 运行；COS/Worker disabled | 配置 COS并启动 Worker |
| Async effects | outbox、lease、dead-letter、replay、receipt 已实现 | scheduler/worker disabled | 分 job family 灰度启用 |
| Data Rights | ExportJob、五域 effect reconcile、恢复边界已实现 | 外部媒体/Provider completion 不完整 | 真实执行器和恢复演练 |
| Voice | 火山 train/query/TTS、profile/slot、binding v2 已实现 | synthesis ready；training admission blocked；delete unsupported | 强身份、删除政策、真机 |
| Publication/Visitor | Authority、ShareGrant、lifecycle、cleanup、安全 policy 已实现 | default-off/externalBlocked | 外部索引、法律安全、beta |
| Digital Human | session/lease 和安全 broker 决策已实现 | configuredButBrokerBlocked | 腾讯 scoped credential 证明或替代方案 |

### 7.H 2026-07-16 历史后端审计（仅用于演进追溯）

本地审计基线：`DreamJourneyBackend main@4c0538b`。先前部署记录指向同一提交，但本轮未 SSH 复核服务器 checkout、容器、timer 或 `.env`，因此不将其写成当前线上事实。当前代码有 58 个 FastAPI 路由、18 张 Postgres 表；路由 ownership registry 覆盖不等于所有资源写入已经安全。

| 能力域 | 成熟度 | 当前可复用实现 | 关键缺口与证据 |
| --- | --- | --- | --- |
| Auth / Ownership | `IMPLEMENTED`（session） / `PARTIAL`（identity） | opaque access/refresh token hash、轮换/replay rejection/logout；58 路由进入 ownership registry | 手机号即可建立/恢复账号，无 OTP/Apple 身份证明；`BACKEND_API_TOKEN` 缺失时 anonymous fail-open，system token 可绕过 owner policy。证据：`auth_sessions.py:30`、`main.py:365`、`:615`、`:748` |
| Archive / Media / Source | `IMPLEMENTED`（metadata/cascade） / `MOCK_ONLY`（media） | `archive_items` JSONB、owner ID 防冲突、知识 source cascade 事务 | upload intent 返回 `mock://`；无对象存储、OCR、DOCX/PDF parser、ASR；DeepSeek adapter 不支持视觉。证据：`main.py:872`、`:927`、`deepseek.py:67` |
| Knowledge / Governance | `IMPLEMENTED`（Projection） / `MISSING`（V4 authority） | snapshot/change/receipt、revision CAS、Mutation V2、tombstone、governance 和 compaction 已真实部署 | 没有 Source、MemoryCandidate、CanonicalMemory/Version 表；KBLite 不能继续兼任业务真相。证据：`postgres_store.py:59`、`:71`、`:99`、`knowledge_governance.py:11` |
| Context / Owner QA | `IMPLEMENTED`（private facts path） / `PARTIAL` | `/context/build` 有权限、证据、timeLetter、care、ranking/cap/hash trace | facts 过滤较完整，people/places/events 尚未统一 persona/evidence 过滤；无 Publication/Visitor 独立 context builder。证据：`context_packet.py:23`、`:1205` |
| Family / Persona | `CONTRACT_ONLY` | invitation/accept、delegated principal、`family_members` 持久化 | 无 Persona 权威表/状态机；`digitalHumanId` 主要由客户端声明；不支持解除关系。证据：`main.py:2368`、`:2418`、`postgres_store.py:259` |
| TimeLetter / Mailbox | `CONTRACT_ONLY` | archive payload、dispatch-due、detail、mailbox read/archive 和定时脚本 | provider delivery 始终 `false`；APNs 不可发；部分更新缺统一 outbox/事务；属于 Blueprint 后置域。证据：`time_letters.py:181`、`:199`、`postgres_store.py:2557` |
| Care / Echo Messages | `CONTRACT_ONLY` / `MISSING` | care snapshot 保存脱敏聚合；delayed reply/mailbox 状态可持久化 | 无后端情绪/危机权威分析、真实 delayed generation 和统一消息 provider；device token 仅存 hash 无法 APNs。证据：`privacy.py:392`、`main.py:2231` |
| Voice Clone / TTS | `IMPLEMENTED`（provider calls） / `CONTRACT_ONLY`（lifecycle） | 火山训练/查询/TTS/PCM adapter、profile/slot 持久化、app/provider ID 分离 | 无随机授权语句、活体/SNR、private/public 双授权、provider 删除回执和可靠后台轮询；synthesis 是任意文本 base64 接口。证据：`voice_clone.py:76`、`tts.py:182`、`main.py:1414` |
| Tencent Digital Human | `IMPLEMENTED`（lease） / `CONTRACT_ONLY`（provider session） | session lease、capacity、heartbeat/release、Postgres 持久化 | 后端未代建腾讯短期会话，只下发环境凭据和本地 expiry；未配置时返回 mock asset。证据：`main.py:188`、`:474`、`postgres_store.py:201` |
| Publication / Visitor | `MISSING` | 无 | 无 Publication/public copy/index/public persona/Visitor/share/chat/feedback 路由或表；全后端无对应符号。 |
| Data Rights / Operations | `PARTIAL` | soft delete/restore、部分 maintenance script、runtime/QA reports | 无 Alembic、Job/Outbox、不可篡改 audit log、对象存储删除、provider deletion、完整 export；`PostgresStore` 单连接跨请求复用，运营任务视图缺失。证据：`postgres_store.py:47`、`:411`、`:3311` |

### 7.1 2026-07-16 后端 P0 风险（历史）

1. 生产身份非强证明：手机号可直接建立/恢复账号；`BACKEND_API_TOKEN` 为空时业务 route 对 anonymous fail-open，客户端 system token 兼容路径进一步扩大越权后果。
2. 部分通用 upsert 在全局 ID 冲突时可能改变 owner，需要逐表改为 owner-bound conflict rejection。
3. `/config/runtime`、realtime token 和 digital-human session 合同仍可能向客户端返回长期供应商凭据，不符合短期凭证/服务端代理边界。
4. 账号和声音删除只更新业务状态，缺全 session 撤销、定时 purge、对象/索引/provider 删除回执和脱敏 tombstone。
5. API 广泛接受 `Dict[str, Any]`，Archive sanitizer 可保留额外字段；缺 typed schema、请求大小上限和 JSONB allowlist。
6. `PostgresStore` 缓存单一 psycopg connection 供同步请求复用，commit/rollback/advisory lock 可能跨请求相互影响；`/health` 不探测数据库。
7. TimeLetter 先提交 delivered 再写 mailbox reminder，Echo/Voice 也没有统一 job/outbox；故障可形成状态成功但副作用丢失。
8. ownership 默认/非法配置落到 `shadow`，policy evaluator 异常会进入 fallback；生产必须改为未登记/异常/fallback 一律 deny。
9. 当前 login/password/restore 的错误和成功状态可区分账号存在、密码配置和恢复状态；强身份迁移必须统一中性响应、耗时与限流。

### 7.2 2026-07-16 数据迁移约束（历史）

- 先引入版本化 migration（如 Alembic）和 owner 约束，再新增 Source/Candidate/Canonical/Publication 表；禁止继续只靠启动期 `CREATE/ALTER IF NOT EXISTS`。
- `archive_items` 中只有本地路径或无 object key 的记录不能迁成“已上传 Source”。
- `kb_snapshots` 保留为兼容 Projection；新 Canonical Memory 通过 outbox/投影器生成 KBLite，不反向从整图猜测权威事实。
- 现有手机号哈希 user ID 通过 identity alias 兼容，不直接重写 18 张表的 owner。
- Voice 旧 `ready/deleted` 不能直接映射成已完成授权和供应商删除，必须保留 unknown/legacy 状态。
- TimeLetter JSON payload 在结构化迁移前先审计时区、收件人授权和非法状态。

### 7.3 Round 3C1A Backfill 设计状态

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| Legacy backend catalog | `DESIGNED` | Product Spec 27.3 覆盖当前 18 张 Postgres 表 | 未执行线上 row count、payload 分布、冲突率或 backfill |
| iOS local catalog | `DESIGNED` | Product Spec 27.4 覆盖 12 类本地 store/runtime/cache | 未实现统一 migration ledger，未跑真实升级矩阵 |
| V4 target coverage | `DESIGNED` | Product Spec 27.5 对 38 组目标对象给出 migrate/derive/project/quarantine/不迁结论 | 新 schema/table/repository 尚未实现 |
| Deterministic ID/owner | `DESIGNED` | migration-only UUID v5、legacy identity alias、claim-pending subject/vault、owner conflict quarantine | 强身份 claim、线上 alias 冲突和 ID 碰撞未验证 |
| Backfill runner | `CONTRACT_ONLY` | checkpoint-after-commit、keyset、snapshot/tail、checksum、replay、quarantine 协议 | 没有 runner 代码、migration head、dry-run artifact 或备份恢复证据 |
| Provider/object reconcile | `CONTRACT_ONLY` | legacy ready/active/uploaded 不直接升级，进入 external reconcile | 未调用真实对象存储、腾讯、火山或 APNs 查询/删除接口 |

Round 3C1A 只回答“现有数据如何被安全识别和回填”，不批准 authority cutover、schema contract 或旧 route 退役。这些动作分别由 Round 3C1B、3C2、3C3、3C4 定义。

### 7.4 Round 3C1B Cutover/Rollback 设计状态

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| Migration run/waves | `DESIGNED` | Product Spec 28.1–28.3 定义状态机和 W00–W11 | 没有 runner、DDL migration、生产 wave 或 cohort evidence |
| Authority fencing | `DESIGNED` | Vault `authorityEpoch` 单调 CAS、request/job/cache/callback fencing | 当前 schema/client/API 尚未携带统一 epoch |
| Shadow compare | `CONTRACT_ONLY` | M01–M08 owner/identity/visibility/version/lineage/time 比较和 promotion gate | 没有 canonical comparator、全量报告或连续观察窗 |
| Rollback | `DESIGNED` | R01–R05 区分 pre-cutover、post-cutover、projection 和 post-contract | 未执行 backup restore、R03/R05 演练或测量 maxRecoveryTime |
| Legacy retirement | `DESIGNED` | D01–D07 与固定退役顺序 | 旧 route、timer、credential、schema 和客户端仍在使用/兼容 |
| Go/no-go evidence | `CONTRACT_ONLY` | 定义最小 evidence record、批准角色和 no-go 默认 | 没有真实产品/数据/安全批准和线上参数 |

该设计禁止把旧 Authority 在 epoch 提升后重新开启写入；因此“可以切回旧 UI/兼容读取”不能表述成“数据可无损回到旧模型”。

### 7.5 Round 3C2B API/AuthZ/Capability 设计状态

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| Typed `/v2` client/route policy | `DESIGNED` | Product Spec 30.1–30.2 定义 EndpointDescriptor、H01–H05、L01–L05 | iOS 仍为宽字典/旧 route；生产没有 domain typed client |
| Strong Identity/Session | `PRODUCT_CONFIRMED / CONTRACT_ONLY` | DR-023 已确认手机号 SMS OTP；30.3 定义 challenge/verify、rotation/reuse、Actor CAS | 短信 provider、真实 claim、防冒领/恢复与 neutral response 尚未实现/验收 |
| AuthZ rollout | `DESIGNED` | G01–G09、production deny、cross-vault 404 与 machine/data-rights/operator 边界 | 当前仍有 shadow/fallback/system token；未完成真实 route/Postgres enforce |
| Capability/ReleasePolicy | `DESIGNED` | 30.5 固定 contract/dataAuthority/policy/epoch/cohort/TTL 与四维成熟度 | 当前 capability 仍可能只看 base URL/本地默认，未签名/未版本化 |
| Client credential eradication | `EXTERNAL_ACCEPTANCE` | 30.6 定义 built artifact、资源、二进制和抓包门 | 尚无当前 Release `.app/.appex` secret scan 证据；旧 credential 轮换状态未知 |
| API rollout waves | `DESIGNED` | P00–P10 与 compatibility/error matrix、20 个场景 | 未实施 read shadow、command dry-run、cohort、426 或 legacy retirement |

本节不改变当前实现成熟度。静态源码没有找到某个 key 不能证明 ignored LocalConfig、构建资源、运行时响应或网络 header 中不存在长期凭据。

### 7.6 Round 3C3A Job/Outbox/Timer 设计状态

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| Scheduler ownership | `DESIGNED` | Product Spec 31.1 定义 DB lease/generation、one-active 和 cutover state | 未验证服务器 systemd/cron/container，当前唯一 scheduler 未知 |
| 15 类 Job migration | `DESIGNED` | J01–J15 给出 legacy producer、bootstrap、cutover、retirement | 当前无统一 Job/Outbox worker，backlog/effect 状态未知 |
| Transactional outbox | `CONTRACT_ONLY` | 31.3 定义 legacy transaction shadow→active consumer→completion command | 当前业务 route 仍按各自 commit/同步路径执行 |
| Timer/worker rollout | `DESIGNED` | Q00–Q10 与 one-active、drain、failover、retirement | 未部署 worker、shadow consumer或 scheduler lease |
| Business idempotency | `CONTRACT_ONLY` | TimeLetter/Inbox、Echo/Inbox、rights/provider 分离与18个场景 | 未跑真实Postgres并发、crash或duplicate effect smoke |
| Operations | `PRODUCT_CONFIRMED / UNMEASURED` | DR-039 已确认统一 DFX/测量合同；queue/dead-letter/scheduler 指标和 UNKNOWN inventory 已定义 | dead-letter owner/SLA、worker容量和最长旧timer窗仍需实测批准 |

本节只完成异步迁移设计，不证明 APNs、Voice、DigitalHuman、对象存储或任何 Provider effect 已真实执行。

### 7.7 Round 3C3B Object/Media 设计状态

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| Media migration catalog | `DESIGNED` | Product Spec U01–U13 覆盖文字、照片、音频、视频、文档、TimeLetter、Voice、TTS、派生与Provider资产 | 线上/设备媒体数量、字节、可达率和owner可证明率未知 |
| Upload/verify contract | `CONTRACT_ONLY` | 32.2定义private namespace、signed PUT/GET、HEAD、sha256、MIME、scan、quota | 当前仍是mock upload intent，没有真实bucket/provider |
| Reference cutover | `DESIGNED` | 32.3与O00–O11定义metadata/copy/shadow/reference/retirement | 未复制、扫描、比较或切换任何真实对象 |
| Delete/retention | `CONTRACT_ONLY` | Z01–Z08区分访问撤销、object/version、derived、cache、device、backup、Provider、audit | 无object/provider/backup deletion receipt与真实恢复演练 |
| Security/permissions | `DESIGNED` | 20个path/SSRF/MIME/checksum/cross-vault/URL/delete场景 | 未完成渗透、恶意文件、signed URL/CDN和大文件压测 |
| External provider | `EXTERNAL_ACCEPTANCE` | DR-026/031与32.7列出region/KMS/scan/parser/SLA输入 | 云厂商、地域、留存、删除和成本尚未批准/验收 |

mock URL、设备路径、Provider临时URL、base64响应或“本地已保存”都不能作为`SourceObject.verified`证据。

### 7.8 Round 3C3C Provider 设计状态

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| Provider state/receipt | `DESIGNED` | Product Spec 33.1 区分 configured、accepted、terminal、businessUsable、externalVerified、deletionState，并定义 receipt 最小字段 | 当前 Provider adapter、DB receipt 和 runtime 尚未统一实现这些状态 |
| F01–F10 Provider matrix | `DESIGNED` | 33.2 覆盖 Object、Scan、OCR、ASR、LLM、Vision、TTS、Voice、Digital Human、APNs 的 credential/effect/query/delete/exit/fallback | Scan/OCR 缺失，Object 为 mock，Vision 为 text-only failure；其余也未形成统一 effect/exit 证据 |
| Credential boundary | `EXTERNAL_ACCEPTANCE` | 33.3 定义 server secret reference、真短期 scope credential、candidate→draining→revoked 和泄漏处置 | 当前真实 secret inventory、轮换、构建产物/header 扫描和 Provider scope/TTL 尚未验收 |
| V00–V11 migration waves | `DESIGNED` | 33.6 从 inventory、sandbox、receipt/callback 到各 Provider canary、delete/exit drill 和 legacy retire | 没有真实 sandbox/canary、cohort、cost/quota gate、旧 key/adapter retirement |
| Delete/exit/asset portability | `CONTRACT_ONLY` / `EXTERNAL_ACCEPTANCE` | 33.7 与 DR-028/031 区分 adapter 可替换、资产可迁移、重新采集/授权和删除状态 | 未取得 Voice/DH/Object/backup/provider 删除回执、许可和 exit drill |
| Provider quality/device outcome | `EXTERNAL_ACCEPTANCE` | 33.5、33.8 定义 fixed corpus、单 Provider canary、质量指标与 22 个故障场景 | 没有 ASR/TTS/Vision/LLM 质量基线、腾讯真机 runtime、APNs arrival、真实成本/SLA 证据 |

2026-07-15 已确认 DR-028/037/039 的产品与架构原则，DR-026/031 仍为外部门，DR-027 的精确预算暂缓。`configured`、HTTP 2xx、Provider accepted、SDK callback 或本地 lease 均不能单独升级为 `businessUsable/externalVerified/deletion completed`。

### 7.9 Round 3C4 组合 Runbook 设计状态

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| Composite authority / C00–C11 | `DESIGNED` | Product Spec 34.1、34.4、34.5 将 W/I/P/Q/O/V 编排为一个组合 go/no-go Authority 和 12 个有序 wave | 当前无 migration controller、组合 run/cohort、生产 checkpoint 或 promotion record |
| Startup Lean Profile | `PRODUCT_CONFIRMED / NOT_IMPLEMENTED` | DR-040/042 与 Product Spec 34.0A 固定 L0盘点/恢复、L1离线演练、L2维护窗切换、L3 24–72小时观察 | 尚无真实 inventory、isolated restore、维护窗 go/no-go、切换或观察证据 |
| Five rollback planes | `DESIGNED` | 34.2 区分 UI、client、API、worker/provider、schema/data 的 Authority、允许/禁止动作 | 未执行跨 build/schema/worker/provider 的 rollback 或 emergency fence |
| Irreversible compensation | `CONTRACT_ONLY` | 34.3 覆盖 MemoryVersion、Inbox/APNs、Publication、Voice/TTS/DH、Object/Provider delete、rights purge、grant和成本 | 当前业务/Provider receipt 尚未统一，补偿命令和真实 reconcile 未实现/演练 |
| Go/no-go and recovery | `PRODUCT_CONFIRMED / CONTRACT_ONLY` | DR-040/042 已确认 Lean 档位；34.6、34.7 保留完整模式的 record、自动 no-go、restore/replay 和 MRT-C00–C11 | 具体阈值、观察窗、RPO/RTO、MRT、on-call/approver 尚未实测和批准 |
| Legacy retirement manifest | `DESIGNED` | 34.8 覆盖 schema、route、timer、credential、feature flag、local store、transition code | 无运行时零使用窗、old binary/client、credential revoke、contract或post-monitor证据 |
| Production migration drill | `EXTERNAL_ACCEPTANCE` | 34.9 给出 24 个跨域演练和 no-go 行为 | 未在真实 backup/Postgres、生产流量、对象/Provider、旧客户端或真机环境演练 |

当前沿用 `DR-023/026/028/031/035/039/040/041/042`：产品已确认手机号、测量合同、轻量迁移和本地草稿边界，但 DR-026/031/035 及生产证据仍未关闭。Lean/C wave 表和静态门只能证明设计内部完整，不能证明生产可 cutover、rollback、contract 或 retire。

### 7.10 Round 3D 独立架构复审状态

| 项目 | 当前状态 | 已形成证据 | 尚未完成/不得宣称 |
| --- | --- | --- | --- |
| Independent reviews | `REVIEWED` | iOS IAR-01..07、Backend BAR-01..07、Security/Ops SOR-01..08 三份只读报告 | 报告范围不是全仓/生产证明，finding严重度不等于代码已修 |
| Finding disposition | `DESIGNED` | 22项均映射 disposition、CR-01..12、WP工作包和owner/gate | `ACCEPTED_*` 只表示纳入目标/路线，不表示实现或外部验收完成 |
| Stage 0 hardening | `RECOMMENDED` / `NOT_IMPLEMENTED` | Product Spec 3.1补AccountLease、credential、DB readiness/restore、delete receipt、async effect、ops/cost | 当前代码仍存在评审列出的BLOCKER/HIGH；生产enforce/rotation/restore尚无证据 |
| Overdesign control | `PRODUCT_CONFIRMED / DESIGNED` | 百级用户采用 Startup Lean；M0 先验证记忆资产，M1 独立验证在世本人私有 Voice，M2 再开放在世主体 Publication/成年 Visitor/DH，M3/M4 后置 | 已有代码尚需 server policy、Authority、监管/外部门和兼容/退役计划 |
| External decisions | `PARTIALLY_CONFIRMED / EXTERNAL_ACCEPTANCE` | DR-023/024/028/037/039/040/042/043 已确认；DR-022/026/031/036 和 DR-035 仍有外部/待确认门 | 法律、地域、Provider条款、RPO/RTO、真机/生产门未关闭；精确成本 DR-027 暂缓 |

Round 3D 响应完成不改变任何 FR 的实现成熟度。代码修复、凭据轮换、生产 AuthZ、真实 Postgres/restore、Provider/delete 和真机结果只能由 Round 4/5 的对应 artifact 升级。

## 8. 当前矩阵退出门槛

| 门槛 | 状态 | 证据/后续 |
| --- | --- | --- |
| 36 个 requirement 与 PRD 一一对应 | `PASS` | `Scripts/QA/product-v4/product-v4-evidence-matrix-check.py` |
| 当前提交、测试数、迁移和 runtime 结论不再引用旧基线 | `PASS` | `Scripts/QA/product-v4/product-v4-current-evidence-baseline-check.py` |
| 所有 `PROD_VERIFIED` 均有部署/设备/provider 证据 | `PASS_WITH_SCOPE` | 仅 ClamAV 运行条件在第 0 节标为局部 `PROD_VERIFIED`；未把 M0–M2 功能标为已发布 |
| Requirement 与 iOS/Backend 模块证据可追踪 | `PASS` | 第 5 至 7 节；当前摘要与历史审计已分区 |
| 非真机、外部 Provider、真机和发布四类 Gate 已分离 | `PASS` | 第 0、5、8 节及完整功能开发计划 |
| 当前发布判断 | `NO_GO` | OTP、COS、Worker、V4 cutover、强身份、真机与 M2 批准仍开放 |

本矩阵可作为当前开发排期和实现成熟度输入，但不能被描述为完整 release evidence package。
