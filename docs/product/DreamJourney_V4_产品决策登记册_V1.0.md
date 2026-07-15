# DreamJourney V4 产品决策登记册

版本：V1.3 Product Confirmed Baseline + Development Detail Decisions
初版日期：2026-07-12
更新日期：2026-07-15
状态：产品负责人已完成独立方案评审的40项回复、三级验证策略和开发前五项产品细节确认；产品范围选择已同步，法律、供应商、生产与真实用户证据仍按各自 Gate 独立关闭
工程基线：iOS `feature/prd-stitch-ui-adaptation@8a1922b`；Backend `main@4c0538b`
关联：[Product Spec V4](./DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md) · [当前实现证据矩阵](./DreamJourney_V4_当前实现证据矩阵_V1.0.md) · [评审与验收清单](./DreamJourney_V4_评审与验收清单_V1.0.md)
定稿边界：登记册定稿不等于开放决定获批，不表示 115 个 Work Item 已实现、G2-G4 已关闭或已获发布批准。

## 1. 使用规则

本登记册防止“代码已经存在”“某份 PRD 写了 P0”或“供应商支持”被误当成已批准产品决定。

| 状态 | 含义 | 工程权限 |
| --- | --- | --- |
| `CONFIRMED` | 有当前用户/有权决策人明确确认的 E2 证据 | 可进入开发，仍需安全和外部门 |
| `RECOMMENDED_PENDING` | V4 审查形成的推荐，尚未获最终产品确认 | 可做可逆设计、mock 和 contract；不可默认公开或做不可逆投入 |
| `EXTERNAL_REQUIRED` | 依赖合规、合同、地域、供应商、真机或生产证据 | 只能做隔离接口和 fail-closed；外部证据前不算完成 |
| `DEFERRED` | 明确不进入当前阶段 | 保留兼容，不扩大功能 |
| `REJECTED` | V4 当前明确不采用的方案；重新采用必须新建决策 | 不进入目标架构或发布范围 |

只有 `CONFIRMED` 表示产品已确认。`RECOMMENDED_PENDING` 的安全默认可以立即用于减少风险，但不能被文档或 UI 表述为最终产品承诺。

决策责任角色：`Product`、`Privacy/Legal`、`Security`、`Architecture`、`Operations`、`Finance`。Owner 指决策责任，不代表单人可以跳过联合评审。

## 2. Round 1 冲突决策

| ID | 冲突/证据 | 类型 | 状态 | 方案与备选 | Fail-closed 默认 | 影响 | 决策 Owner | Gate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DR-001 | C-01：三 Tab vs 四 Tab Blueprint | Product/IA | `CONFIRMED` | 保留“记忆档案/回响/我的”三个主入口；Source、Candidate、Memory、自传和家人管理使用页内层级，不新增主 Tab | 不改主 Tab，不暴露空分身域 | 保持当前信息架构，降低首发 UI 重写 | Product + iOS | 2026-07-15 产品确认；实现仍需 G1 真机验收 |
| DR-002 | C-02：Publication/Visitor 的 Product MVP 范围 | Product/Scope | `CONFIRMED` | 受控 Publication/Visitor 进入 Product MVP，但仅面向家庭成员或明确授权用户访问独立、可撤回副本；不开放匿名公共访问，不阻塞 Closed Pilot | 没有独立 PublicationVersion、授权上下文和撤回链路时入口关闭 | `WP-S3-01` 是 Product MVP 受控切片；与 Owner 文字核心隔离 | Product | 2026-07-15 产品确认；真实开放仍需身份、隐私、安全与 G2/G4 |
| DR-003 | C-03：Family/Care/TimeLetter 首发范围 | Product/Scope | `CONFIRMED` | Product MVP 必须具备家庭成员、家庭人物切换和受授权查询；Care、TimeLetter 暂不进入 Product MVP，保留兼容并默认关闭；Family 不阻塞 Closed Pilot。Family relationship 支持暂停和终止，任一方可发起且敏感主控关系二次确认；终止立即撤销后续查询 grant，保留历史贡献/审计，重新建立关系必须重新邀请和授权 | Care/TimeLetter policy 默认关闭；Family 未完成 AuthZ 时只显示不可用；关系终止不恢复旧 grant，也不直接物理删除其他 Authority 的历史数据 | 家庭基础能力成为 Product MVP 范围，Care/TimeLetter 延后；关系退出与数据权利分离 | Product | 2026-07-15 产品确认；开发前细节回执同步 |
| DR-004 | C-04：本人、家人、逝者纪念人格与主控边界 | Product/Rights/Voice | `CONFIRMED` | 经核验的在世主控人可建立 MemorialVault、邀请 Family Contributor 并决定日常产品内使用；逝者是 Represented Persona，不是登录 principal。本人、未成年人和逝者资料分别绑定本人或监护人/主控人证据；Publication、Voice、Portrait、DH 按 purpose 独立。主控人的产品选择不能替代强制法律、有效第三方异议、供应商条款或平台法定义务 | 身份/关系/监护或人工复核缺失时不创建正式 Persona；法律/Provider Gate 未关闭时 Voice/Portrait/DH 保持 blocked | 支持全龄人物资料和家庭共建，同时保留高风险能力外部门 | Product + Privacy/Legal + Architecture | 产品边界已确认；未成年人、第三方和逝者 Voice/DH 仍受 DR-022/026/031/036/037 外部门 |
| DR-005 | C-05：首版自助导出范围 | Data rights | `CONFIRMED` | 首版不提供用户自助批量导出或下载全部上传内容；服务协议如实说明产品功能边界。但依法必须提供的访问、更正、复制、转移或权利请求渠道不能用协议排除，按人工受理和最小 DataRightsAuthorization 执行 | UI 不显示已支持完整导出；内部 QA 导出不得冒充用户功能；法定权利请求不得拒绝或静默丢失 | 减少首版自助导出工程量，但仍需权利请求受理、身份核验和回执 | Product + Privacy/Legal | 2026-07-15 产品确认；中国首发法律文本与人工流程需 G4 |
| DR-006 | C-06：独立发布副本与公开索引 | Architecture/Privacy | `CONFIRMED` | Product MVP 的家庭授权访问必须读取钉住 Memory Version 的独立脱敏 PublicationVersion 与独立索引；拒绝 `isPrivate=false`、私人 Projection 过滤视图或整库直接暴露 | 不存在独立 Publication authority 就不开放 | `WP-S3-01` 成为 Product MVP 必需包；保护私人域不被家庭授权绕过 | Architecture + Privacy/Legal | 2026-07-15 产品确认；G2/G4 后才可真实开放 |
| DR-007 | C-07：未确认材料如何参与问答 | Product/AI | `CONFIRMED` | 确定性回答只使用已确认记忆；未确认材料通过自然问答追问补齐并进入批量候选确认，不要求用户逐条点击。未确认、AI 推断和家属陈述必须保留状态与视角，不能伪装成事实 | 未确认材料不进入确定性 QA/Publication；批量确认前保持 Candidate | 降低确认打扰，需要对话引导、批量审核和可解释差异 | Product + Architecture | 2026-07-15 产品确认 |
| DR-008 | C-08：文字、声音复刻与数字人发布关系 | Product/Conversation | `CONFIRMED` | 文字问答属于 Closed Pilot；声音复刻属于 Product MVP；数字人作为独立 Beta Extension。Conversation/Message Authority 与声音/DH runtime 分开，任一 Provider 失败均回退文字 | Voice/DH 不可用不得阻断文字 QA；数字人 Beta 默认按账户/家庭白名单开放 | `WP-V0-01` 中 Voice 治理/训练/TTS 为 Product MVP，DH 保持受控 Beta Extension | Product + iOS + Backend | 产品范围已确认；真实声音/DH 仍需法律、Provider、配额和真机 G3/G4 |
| DR-009 | C-09：真实资料处理 vs mock upload | Architecture/External | `EXTERNAL_REQUIRED` | Closed Pilot 可保留照片选择、owner-scoped 本地草稿和本机预览，但必须明确“仅本机保存/尚未云端保存”；Stage 2 再接对象存储、扫描、OCR/ASR/PDF/DOCX processors，视频只存不理解。供应商选择保持 port 隔离 | mock/local-only 入口不得显示已上传、已同步或 verified，也不公开为云能力 | 保留照片入口但要求诚实状态；真实存储仍需要合同、删除 SLA、成本和任务系统 | Architecture + Operations + Product | 本地入口已于 2026-07-15 确认；真实 Stage 2 开发前仍需外部门 |
| DR-010 | C-10：Visitor 身份与邀请模式 | Security/Product | `CONFIRMED` | MVP 仅允许已认证用户或具有过期/限次 grant 的受邀访问；匿名入口延后，家庭关系本身不自动产生查询权限 | 无匿名公共入口；无有效授权上下文即 deny | 降低滥用面，家庭用户需各自登录 | Product + Security | 2026-07-15 产品确认；G2/G4 后开放 |
| DR-011 | C-11：账号注销与上传记录删除 | Data rights | `CONFIRMED` | 账号注销采用“立即撤销访问 + 30 日可披露恢复窗口 + 到期分层 purge”。上传人可不可撤回地删除自己提交的 Source；删除必须级联暂停依赖 Memory/Publication/QA，并保留最小删除回执。纪念账户主控权和共同材料不得因主控账号注销被静默删除 | 账号注销立即撤销 session/grant；Source 删除立即停止未来使用；无 purge receipt 不称完成 | 需要把账号、Vault、Source、声音/DH资产四类删除分开实现 | Product + Privacy/Legal | 2026-07-15 产品确认；法律 hold/第三方权利和供应商回执仍需 G4/G3 |
| DR-012 | C-12：AOS 完整能力主张无源码支撑 | Evidence/Architecture | `REJECTED` | 不把 AOS MemoryStore/Slot/Scatter 当组件集成；只借鉴 raw/derived、promotion、bounded workflow 原则 | Hermes/AOS 目录不进入产品依赖或仓库 | 避免重写和不可验证基础设施 | Architecture | 已由证据审计关闭；重新采用需新证据 |
| DR-013 | C-13：FR 与验证优先级 | Product/Priority | `CONFIRMED` | 依赖顺序为安全/身份/备份恢复基础、Closed Pilot Owner 记忆与文字问答、Product MVP 家庭协作与受控 Publication/Visitor、Product MVP Voice Clone；数字人为 Beta Extension，Care/TimeLetter 后置 | 不按旧 P0 标签并行开发；外部门未关闭的能力保持隐藏或 fail-closed | 用独立价值门替代“大爆炸式完整 MVP 验证” | Product + Engineering | 2026-07-15 产品确认 |
| DR-014 | C-14：Voice/Digital Human 发布层级 | Product/Voice | `CONFIRMED` | 文字问答先进入 Closed Pilot；声音复刻与复刻 TTS 进入 Product MVP；数字人进入独立 Beta Extension。Voice/DH 失败或外部 Gate 未关闭时回退文字，不冒充已启用 | 缺授权、Provider、真机、质量或地域证据时对应能力 blocked | 保留 Product MVP 声音价值并隔离数字人风险 | Product + Privacy/Legal | 产品范围已确认；真实训练/合成仍需 G3/G4 |
| DR-015 | C-15：assistant 回复与批量记忆确认 | Product/AI | `CONFIRMED` | 延续 `userEvidenceOnly`；每次对话不逐条弹窗。Message/Source/Candidate/DecisionReceipt 持续持久化；退出页面或待审核数量/上下文预算达到服务端 policy 动态阈值时，以先到者触发批量审核，强杀/断网后恢复同一批次；assistant/Visitor 输出不能自动成为 Source | 未完成批次确认的内容不进入正式记忆、Publication 或人物事实回答；模型上下文截断不得丢失业务数据 | 降低确认打扰，需要批次来源、逐项撤销、部分接受和可恢复持久化；首版不提供用户轮数设置 | Product + Architecture | 2026-07-15 产品确认；开发前动态阈值细节回执同步 |
| DR-016 | C-16：Source/Memory 变化后的发布失效 | Privacy/Contract | `CONFIRMED` | Source 删除、Memory 修正/删除、第三方异议或 grant 过期时，依赖 Publication 同步进入 `suspended`；恢复发布需主控人重审并生成新版本 | 先停未来访问，再异步清索引和对象 | 保证安全优先，可能产生暂时不可用 | Product + Privacy/Legal | 2026-07-15 产品确认；暂停 SLO 由测量合同验收 |
| DR-017 | C-17：地域、匿名、声音、留存、成本未决 | Cross-functional | `EXTERNAL_REQUIRED` | 建立阶段入口门，分别由 DR-023 至 DR-028、DR-031 决定；不得由工程选择默认供应商或地域 | 不采集/出站/公开对应数据 | 可能阻塞真实用户和 provider 扩量 | Product + Privacy/Legal + Finance | 对应阶段开发前 |
| DR-018 | C-18：绝对可信/可控文案 | Product/Legal | `REJECTED` | 禁止“完全可信/完全可控/彻底删除/不会冒用/立即撤回”；使用“用户可管理、显示来源、按披露边界处理，AI 可能出错” | 对外不作不可证明保证 | 降低营销强度，避免错误合规承诺 | Product + Privacy/Legal | 所有公开文案前 |
| DR-019 | C-19：北极星和发布门 | Product/Metrics | `CONFIRMED` | 采用 WTMR：跨会话且至少跨一个自然日复用此前已确认的 active Memory 并显式 helpful；A72 衡量激活，R28 衡量持续复用，GHR 分母保留失败/无引用/未反馈 | 未有服务端事件前不声称达标；onboarding 自循环不计 | 需要服务端事件管线、eligible attempt 和 cohort 基线 | Product + Data | 2026-07-15 产品确认；阈值仍需真实数据校准 |
| DR-020 | C-20：Hermes 目录凭据和权限风险 | Security | `EXTERNAL_REQUIRED` | 立即轮换可见凭据、收紧目录/文件权限、从备份和分享范围移除；DreamJourney 不复制该目录或凭据 | 不读取/导入其配置和 memory 数据 | 外部安全整改，不改产品代码 | Security + 资产 Owner | 立即；任何复用前必须有整改证据 |
| DR-021 | C-21：永久 TimeRiver vs 删除权 | Privacy/Architecture | `REJECTED` | 不采用永久不可删时间河或无法追踪副本的自研存储；所有 authority/projection/object/provider/backup 必须进入删除矩阵 | 无删除证明的存储不接真实用户数据 | 牺牲“永久记忆”叙事，保留数据权利 | Architecture + Privacy/Legal | 目标架构冻结前 |

## 3. 跨冲突新增决策

| ID | 证据/主题 | 类型 | 状态 | 方案与备选 | Fail-closed 默认 | 影响 | 决策 Owner | Gate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DR-022 | 未成年人和可识别第三方权利 | Privacy/Product | `EXTERNAL_REQUIRED` | 产品范围覆盖全年龄人物资料；未成年人由完成强身份和监护关系核验的监护人创建/管理并接受专门条款。未成年人 Voice/Persona、外部 AI 和公开用途必须按中国首发法律、年龄保护和 Provider 能力单独批准 | 监护证据或专项政策缺失时只允许最小草稿/隔离保存；第三方敏感内容不自动公开 | 扩大产品范围并显著增加监护、年龄保障和内容治理 | Product + Privacy/Legal | 产品意图已确认；未成年人真实资料、Voice/DH 和公开用途前需 G4 |
| DR-023 | 首发登录与账号恢复 | Security/Product | `CONFIRMED` | 首发采用手机号注册登录，必须实现 SMS OTP、session rotation/revoke、换号/丢号受控恢复和账号关联防冲突；手机号文本不能直接作为数据 owner authority | 未验证手机号或 alias 冲突时不开放高敏数据、家庭邀请或 Provider | 影响短信成本、恢复运营和冒领防护 | Product + Security | 2026-07-15 产品确认；短信与恢复 G2/G4 |
| DR-024 | Operator/Admin 内部访问 | Security/Operations | `CONFIRMED` | Operator 默认仅看脱敏任务元数据；Admin break-glass 需要工单、理由、短时、双人批准、字段最小化和不可修改审计，默认不得修改用户事实 | 内部角色无私人正文默认权限 | 增加运营审批与审计实现 | Security + Operations | 2026-07-15 产品确认 |
| DR-025 | AI 身份披露与危机表达 | Safety/Product | `CONFIRMED` | 始终披露 AI；危机/自伤等高风险表达不得进入延迟回信或人格模拟，立即展示非诊断安全响应和中国首发适用资源；Care 不替代危机运营 | 未有适用政策时退出 Persona 模式并提示寻求真人帮助 | 需要安全评测、年龄分层、投诉和地区资源 | Product + Safety/Privacy | 2026-07-15 产品确认；上线前 G4 |
| DR-026 | 首发地域、processor/subprocessor 和跨境 | Privacy/Commercial | `EXTERNAL_REQUIRED` | 产品选择中国作为首发地域；数据库、对象与第三方处理的具体区域、跨境、子处理者、禁训练、留存、删除和事件通知仍需逐供应商核验 | 不把真实正文、声音、生物特征发送给未批准 processor；产品协议披露不能替代处理商合同或法定义务 | 可能限制模型和数字人供应商 | Privacy/Legal + Operations | 产品地域已确认；真实数据出站前需 G4/G3 |
| DR-027 | 多模型、语音、数字人成本停止线 | Finance/Product | `DEFERRED` | 产品接受预算、并发和自动降级原则，但首发暂缓确定商业预算。工程仍必须设置供应商硬配额、异常熔断和文字降级，避免无界费用；不得暂停数据权利任务 | 未批准的 Beta 不扩量；Provider 配额错误时回文字，不借用其他家庭资产 | 首发无法以成本目标验收扩量，需在种子数据后重新确认 | Finance + Product + Operations | 精确预算暂缓；真实扩量和数字人 Beta 扩容前必须重开 |
| DR-028 | Provider Adapter 与资产可迁移性 | Architecture/Commercial | `CONFIRMED` | 接口隔离只保证调用可替换；声音模型、数字人素材和授权可能需重新采集。产品不承诺训练资产跨供应商迁移，正式扩量前披露退出和重训成本 | 无 exit/delete 路径的 provider 不承载高敏正式资产 | 可能增加重新训练成本但降低错误承诺 | Architecture + Commercial | 2026-07-15 产品确认；Provider exit 证据仍需 G3 |
| DR-029 | “Canonical Memory”含义、人物记忆维度和类型化存储合同 | Product/Architecture/Data | `CONFIRMED` | 产品 UI 使用“已确认记忆记录”；技术名 `CanonicalMemory` 只表示 Owner 当前采用版本。采用 Spec 24.4A：共同 Memory Authority 主干 + `MemoryKind/PerspectiveType/EpistemicStatus` 三个正交维度 + versioned typed content schema + `memory_relations`。首批冻结 `experience/knowledge/emotion`，完整本体覆盖 skill/relationship/preference/habit/value/decision/goal/self_narrative；人格为有证据的 PersonaProjection，声音形象为 EmbodimentProfile。拒绝每人一份大 JSON、自由 JSONB、把第三方/AI视角当内容类型以及把 KBLite/图/向量库作为事实 Authority | 未知 kind/schema、视角不明、未确认推断一律 quarantine，不进入 Projection/QA/Publication；情感和第三方关系默认高敏且不批量发布；不用“真相/真实人格”描述用户回忆或模型推断 | 增加 schema registry、relation 表、类型校验、迁移分类和查询策略；研发按合同实现，不再自行决定人物本体 | Product + Architecture + Data + Privacy | 已于 2026-07-14 确认；`WP-S1-01` Schema/API 冻结和真实数据迁移前完成实现符合性验收 |
| DR-030 | 用户明确：PRD/Blueprint/分析可更新且不是最终产物 | Document governance | `CONFIRMED` | V4 Product Spec 定稿后为唯一产品范围权威；旧文档保留历史正文、增加 lifecycle banner 和 V4 链接 | 冲突时按源码事实 + V4 + 决策登记册，不按旧 P0 开发 | 需要更新引用和协作规范 | Product/主控 | Round 2 完成前 |
| DR-031 | Provider 是否训练、样本/正文留存和删除条款未证实 | Privacy/Provider | `EXTERNAL_REQUIRED` | 默认禁止将用户数据用于供应商训练；合同需说明用途、地域、留存、删除回执、安全事件和子处理者 | 无明确条款不发送正文、生物特征或高敏数据 | 可能排除部分 provider；影响成本和质量 | Privacy/Legal + Commercial | 任何真实 provider 数据前 |
| DR-032 | 产品事件和指标 Authority | Product/Data | `CONFIRMED` | 事件由服务端事务/outbox 产生，使用稳定 owner/object version/idempotency；排除 QA/mock/internal，客户端事件只补交互；用于 WTMR、A72、R28 和 GHR | 无可验证事件不声称北极星或转化达标 | 需要 typed analytics contract 和隐私最小化 | Product + Data + Privacy | 2026-07-15 产品确认；G2 数据后校准阈值 |
| DR-033 | 产品确认基线与可逆边界 | Architecture governance | `CONFIRMED` | 2026-07-15 产品回复是当前 E2 产品基线；确认项可以进入开发，外部依赖项仍只能做 port、mock、contract 和 fail-closed，不得把产品意图当法律或生产批准 | 外部门未关闭的能力保持 blocked | 结束“全部产品决定开放”状态，同时保留外部门 | Product + Architecture | 2026-07-15 产品确认 |
| DR-034 | Final review RV-11：legacy confirmed 仅在 Projection | Data migration | `RECOMMENDED_PENDING` | 只有 owner/source/decision receipt 完整者可迁为 Memory v1；缺证据进入 `legacy_needs_review`，observed/candidate/rejected/superseded 分级映射，按 authorityEpoch 切换 | legacy 未验证内容不进确定性 QA/Publication | 增加审核和迁移成本，避免丢数据或伪造确认 | Product + Architecture | Round 3 migration 设计前 |
| DR-035 | Final review RV-02/RV-12：撤权后删除/审计失去授权 | Security/Privacy | `RECOMMENDED_PENDING` | 分离 ProcessingBasis/Consent、AccessGrant、WorkAuthorization、DataRightsAuthorization、RetentionHold 和短期 ProviderCapability；禁止通用 system 绕过 | 普通访问撤销，已受理数据权利 job 仅凭最小 operation authorization 继续 | 新增 policy/job authority，修复删除死锁 | Security + Privacy/Legal + Architecture | Round 3 auth/job 设计前 |
| DR-036 | 第三方、未成年人、逝者用途和权利请求 | Privacy/Product | `EXTERNAL_REQUIRED` | 产品希望由经核验主控人承担日常内容、冲突、第三方公开和逝者 Voice/DH 选择，并在协议中明确责任；架构仍必须按私人保存、AI/QA、Publication、Voice/Persona 分用途，提供 RightsRequest、异议冻结和 receipt。协议不能排除平台法定义务、有效第三方请求或未成年人保护 | 主控选择已记录，但未取得中国首发专项法律意见、监护/关系证据和 Provider 允许前，高风险用途 blocked；有效权利请求可触发 scope hold | 产品意图与外部法律边界分离，避免把协议勾选误当免责 | Privacy/Legal + Product | 产品意图已确认；真实未成年人/第三方公开/逝者 Voice-DH 前需专项 G4 |
| DR-037 | Voice 资产、用途授权和合成内容绑定 | Voice/Privacy | `CONFIRMED` | Product MVP 按训练、私人问答、家庭播放、Visitor、商业展示分别授权；基础 MVP 要求 Owner private 与授权 Family Voice，Visitor Voice 为独立 capability/cohort，不阻断基础 MVP。家庭成员客户端必须解析目标 Owner/Represented Persona 已授权且 active/quality-accepted 的精确 profile version；合成绑定 answer/publication、text hash、policy、profile version、purpose 和 GeneratedAudio TTL/receipt，不开放任意文本冒充 | 缺用途绑定、来源、授权或 TTL 即拒绝；不得借用访问者、上一角色或默认音色冒充目标人物 | 影响现有 synthesis API、角色解析和缓存，降低声音错配与滥用；Visitor Voice 可独立关闭 | Product + Privacy/Legal + Architecture | 2026-07-15 产品确认；开发前 Voice 细节回执同步；后续合并用途需重新评审 |
| DR-038 | Visitor 输入生命周期 | Privacy/Product | `CONFIRMED` | VisitorSession、Message 和 IP/device 派生标识默认 TTL 为7天；主控人默认只看授权使用统计和安全事件，不看问题正文。主动共享、合法争议或 RetentionHold 仅保留最小必要证据 | 到期或撤权停止读取和 Provider 处理；默认不向主控人展示正文 | 增加 MVP Visitor 数据权利与反滥用实现 | Product + Privacy/Legal + Security | 2026-07-15 产品确认；举报/法律保留例外需 G4 |
| DR-039 | 指标、SLO 与统一测量合同 | Product/Operations | `CONFIRMED` | 接受统一测量合同和现有 Projection/Retrieval DFX 作为研发基线；每个指标附 build/env/region/provider、负载、样本、窗口、分母、冷启动、超时和 artifact。未实测前不对用户承诺端到端时延 | 无 measurement metadata 不做 pass 或扩量 | 增加测试与遥测工作，减少选择性报告 | Product + Operations + Privacy | 2026-07-15 产品确认；具体扩量阈值需 G2 |
| DR-040 | 轻量迁移与未来完整迁移体系 | Architecture/Operations | `CONFIRMED` | 百级用户 MVP 采用强制最低版本、提前通知维护窗和四阶段轻量迁移：盘点/备份恢复、离线演练、维护窗冻结写入并切换、24至72小时观察与退役。C00-C11 保留为未来目标，当无法强制升级、无法接受维护窗或进入规模化运营时启用 | 缺 backup/isolated restore、迁移校验或 go/no-go 时不切换；post-cutover 不恢复 legacy 写 Authority | 当前显著降低执行负担，未来仍保留完整安全模型 | Architecture + Operations + Security + Product | 2026-07-15 产品确认；具体窗口/RPO/RTO需实测批准 |
| DR-041 | 账号切换、登出与本地草稿 | Product/Privacy | `CONFIRMED` | switch 只卸载并锁定同 subject 的加密显式草稿；logout 清 runtime/cache/export/notification，草稿只能由同一强验证 subject 恢复并提供清理选择；account delete 立即清全部本地用户数据。Closed Pilot 的本地照片草稿可预览，但必须明确未云端保存 | 无 owner proof 的 legacy 数据 quarantine；保留草稿不跨账号显示、上传、索引或送 Provider；本地媒体不得冒充同步成功 | 保护未提交内容并增加本地迁移、清理和诚实状态 UX | Product + Privacy/Legal + iOS | 2026-07-15 产品确认；开发前照片入口回执同步 |
| DR-042 | 初创团队 MVP Operating Profile | Product/Architecture/Operations | `CONFIRMED` | 以百级用户、单一中国首发地域、模块化单体、单 Postgres、私有对象存储、单独 Worker、Provider Adapter、可强制升级和可维护窗口为当前 Operating Profile。115项路线按“Closed Pilot、Product MVP、Beta Extension、规模触发”分层 | 不因轻量模式取消 Vault 隔离、来源引用、用途授权、访问撤回、删除回执、备份恢复和 Provider fail-closed | 让目标架构与初创团队能力匹配，同时保留规模化升级路径 | Product + Architecture + Operations | 2026-07-15 产品确认；工程实现与外部门仍分别验收 |
| DR-043 | 三级产品验证与发布层级 | Product/Release/Architecture | `CONFIRMED` | 采用 `Closed Pilot -> Product MVP -> Beta Extension`。首批 Closed Pilot 只开放 Adult Self；Memorial Controller 在死亡事实、亲属关系和主控任命可验证后进入第二 cohort，Guardian/未成年人保持独立 G4 cohort。Closed Pilot 只验证强身份/Vault隔离、文字记忆 Capture→Review→QA→Citation→Correction→Deletion，不等待 Family/Publication/Visitor、Voice Clone、Digital Human 或非必要媒体。Product MVP 增加 Family/人物切换与贡献、受控 Publication/Visitor 和 Voice Clone。Beta Extension 独立承载 Digital Human、媒体理解及 Care/TimeLetter | Closed Pilot 只向受控 cohort 开放，不得匿名访问或宣称完整 MVP；下一层未过门时只关闭该层入口，不反向阻断已通过的文字核心 | 以 Adult Self 降低首批真实数据风险，解除供应商、真机、法律或家庭授权延期对早期核心价值验证的阻塞，同时保留长期全龄与纪念产品范围 | Product + Architecture + Operations | 2026-07-15 产品接受建议并确认首批 cohort；每层实现及适用 G0-G4 仍独立验收 |

### 3.1 Round 3C3C Provider 决策映射

Provider Effect、Credential 与 Exit 迁移沿用以下 Gate：`DR-026` 中国首发地域/processor、`DR-027` 暂缓的商业预算与必须保留的工程熔断、`DR-028` 资产不可默认迁移、`DR-031` 禁训练/留存/删除外部条款、`DR-037` Voice purpose binding、`DR-039` 测量合同。产品已确认资产边界、用途分离和测量原则；`DR-026/031` 仍是外部门，`DR-027` 的精确预算仍为暂缓，不能由设计或静态检查替代。

### 3.2 Round 3C4 组合 Runbook 决策映射

当前 MVP 以 `DR-040/042` 的四阶段轻量迁移为默认 Operating Profile，同时保留 C00-C11 作为规模触发后的完整目标。轻量迁移仍沿用 `DR-023` 手机强身份、`DR-026` 地域/processor、`DR-028` Provider资产退出、`DR-031` Provider数据条款、`DR-035` WorkAuthorization/DataRights、`DR-039` 测量合同和 `DR-041` iOS本地草稿边界。产品确认不能替代真实 backup/restore、迁移校验、维护窗批准和 Provider in-flight 对账。

### 3.3 Round 3D 独立评审映射

IAR-01..07、BAR-01..07、SOR-01..08 已在 Round 3 评审响应中映射到 CR-01..12 与稳定 `WP-*`。2026-07-15 产品回复关闭了多数产品选择，并新增 `DR-042` 作为初创团队轻量实施基线、`DR-043` 作为三级产品验证与发布基线；身份/内部访问由 `DR-023/024/035`，第三方/未成年人由 `DR-022/036`，地域/Provider/Voice由 `DR-026/028/031/037`，成本/测量由 `DR-027/039`，迁移/本地草稿由 `DR-040/041/042`，发布分层由 `DR-043` 承载。产品确认不会自动关闭法律、供应商、部署、真机和生产证据。

### 3.4 2026-07-14 Memory Ontology 架构修订

产品评审明确确认并扩展 `DR-029`，其规范落点为 Product Spec 24.4A，执行落点为 `WP-S1-01`。研发可以选择满足合同的内部代码组织和优化方式，但不得改变 MemoryKind、视角/认知状态分离、版本化 Schema、关系 Authority、人格 Projection 以及声音形象非事实权威等产品不变量；如需变更，必须新增决策并重新评审。

### 3.5 2026-07-14 Memorial Persona 架构修订

产品评审明确确认并扩展 `DR-004`：直系/近亲属完成身份、死亡事实和关系核验后，可以建立由在世主控人管理的逝者 MemorialVault，邀请家庭成员共同提交材料和完善私人知识库。规范落点为 Product Spec 8.3、12.7、16.6、17.4 和 24.4B；执行复用 `WP-S0-02/05/06`、`WP-S1-01/02/03` 与可选 `WP-S3-01/WP-V0-01`，不新增并行 Authority。

该确认不采用“近亲属继承逝者授权”的表述。近亲属保护和个人信息请求权、产品日常主控权、逝者生前意愿证据以及每个 Voice/Portrait/DH/Publication purpose 的能力决定是四个不同对象。`DR-022/026/031/036/037`、首发法域专项法律意见、Provider 允许、生成内容标识和拟人化互动服务义务仍保持开放或外部门，不能因 `DR-004=CONFIRMED` 自动关闭。

### 3.6 2026-07-15 产品逐项确认

产品负责人已完成独立方案评审第21章的40项回复。确认后的当前产品范围为：

1. 保留三个主 Tab；当前采用百级用户、单一中国地域和四阶段轻量迁移；
2. Product MVP 包含手机登录、本人/纪念人物记忆、家庭人物切换、家属贡献、文字问答、家庭授权 Publication/Visitor 和声音复刻；数字人作为受控 Beta Extension，Care/TimeLetter 后置；
3. 未确认材料通过对话追问形成候选，在退出页面前或约5至10轮后批量确认，不逐轮打断；
4. 全龄人物资料进入产品范围，未成年人由监护人核验和授权；未成年人高风险用途仍受专项法律和 Provider Gate；
5. 首版无自助批量导出，但法定数据权利请求不能被协议排除；账号注销采用30日恢复，上传人删除自己的 Source 为不可撤回操作并触发依赖暂停；
6. 家庭和 Visitor 使用独立、可撤回授权上下文；Visitor 默认 TTL 为7天，主控人默认看不到访问者问题正文；
7. 产品希望由主控人承担家庭冲突、第三方内容和逝者高风险能力的日常选择，但服务协议不能替代平台法定义务、第三方权利请求或中国首发专项法律意见；
8. 声音复刻进入 Product MVP，数字人 Beta Extension；用途授权、来源绑定、AI 标识、资产暂停/删除和 Provider fail-closed 保持强制；
9. 接受 WTMR、统一测量合同和 DFX 基线；精确成本和配额商业参数首发暂缓，但工程硬配额、熔断和文字降级不得暂缓。

上述是产品 E2 决策证据。`EXTERNAL_REQUIRED`、`DEFERRED` 和仍为 `RECOMMENDED_PENDING` 的项目没有因产品回复自动关闭。

### 3.7 2026-07-15 三级产品验证策略确认

产品负责人接受“Closed Pilot、Product MVP、Beta Extension”分级建议。该确认新增 `DR-043`，并补充而非推翻第21章40项逐项回复：

1. `Closed Pilot` 以 R3 Owner 文字核心为价值验证切片，仅在强身份、Vault隔离、来源引用、纠正、删除和受控 cohort 的适用门通过后开放；
2. `Product MVP` 在 Closed Pilot 达标后增加 Family/人物切换与贡献、受控 Publication/Visitor 和 Voice Clone；其中任一门未关闭，只阻断 Product MVP，不否定 Closed Pilot 的产品验证结果；
3. `Beta Extension` 承载 Digital Human、非必要媒体理解及后续 Care/TimeLetter，独立白名单和独立停止线；
4. 三层共享同一数据 Authority，不创建简化版旁路数据模型；层级通过不自动关闭下一层的法律、Provider、真机、隐私或生产 Gate。

### 3.8 2026-07-15 开发前产品细节确认

产品经理完成 `PDC-D01..D05` 回执。为避免增加重复 Decision ID，本次确认补充既有决定而不新增第二套决策轴：

| 回执 | 选择 | 补充的 Decision | 确认结果 |
| --- | --- | --- | --- |
| `PDC-D01` | `A` | `DR-037/043` | Owner private 与授权 Family Voice 是基础 MVP 门；Visitor Voice 独立 capability/cohort，不阻断基础 MVP；家庭成员客户端必须使用目标人物对应且已授权的精确 profile version |
| `PDC-D02` | `A` | `DR-009/041` | Closed Pilot 保留本地照片草稿和本机预览，明确未云端保存；不得把 local/mock 显示为 uploaded/synced/verified |
| `PDC-D03` | 自定义 `D` | `DR-015` | Candidate 持续持久化；退出页面或服务端动态阈值先到即审核；强杀/断网恢复；模型上下文截断不得丢业务数据 |
| `PDC-D04` | `A` | `DR-003` | Family 支持暂停/终止；任一方可发起，敏感主控关系二次确认；立即撤 grant、保留历史、重建关系需重新邀请授权 |
| `PDC-D05` | `A` | `DR-043` | 首批 Closed Pilot 只开放 Adult Self；Memorial Controller 第二 cohort；Guardian/未成年人独立 G4 |

确认人/角色：产品经理。确认日期：2026-07-15。详细回执和规范化理由见[开发前问题与决策收敛清单](./DreamJourney_V4_开发前问题与决策收敛清单_V1.0.md)。这些确认不自动关闭 G2/G3/G4，也不提升当前实现成熟度。

## 4. 决策队列

### 4.1 MVP 产品范围已确认

- 三 Tab、Family、家庭人物切换、手机登录、Owner Truth Loop、批量候选确认、30日账号恢复、本地草稿、Operator/Admin、AI披露和危机路径已确认。
- 家庭授权 Publication/Visitor 进入 MVP，使用独立发布副本、认证/邀请 grant 和7天 Visitor TTL。
- 声音复刻进入 MVP，数字人作为受控 Beta；Care/TimeLetter 后置。
- Owner private 与授权 Family Voice 是基础 MVP 门，Visitor Voice 独立放行；首批 Closed Pilot 只开放 Adult Self。
- 本地照片草稿可保留但不得冒充云端；Candidate 在退出或动态阈值先到时审核并持续持久化；Family 支持暂停/终止且终止不删除历史 Authority。
- WTMR、统一测量合同、DFX 和四阶段轻量迁移已确认。

产品范围确认只允许路线重新排序，不代表相应 Work Item 已实现或可真实发布。

### 4.2 MVP 仍需关闭的产品实现/外部门

- `DR-009`：真实对象存储、扫描和媒体处理供应商。
- `DR-017/026/031`：中国首发的具体处理地域、跨境、供应商训练/留存/删除和子处理商证据。
- `DR-020`：Hermes 外部凭据整改。
- `DR-022/036`：未成年人、第三方、逝者 Voice/DH 和主控责任条款的专项法律结论。
- `DR-034/035`：legacy 数据分级与 machine/data-rights authorization 详细合同。
- `DR-027`：精确商业成本暂缓；工程配额和熔断仍必须实现。
- 真实短信、备份恢复、Provider、真机、性能和维护窗仍需 G2/G3/G4 证据。

### 4.3 Publication / Visitor MVP Gate

- 只允许独立 PublicationVersion、认证/限次/可过期 grant 和可撤回授权上下文；Family 关系不自动授权。
- Visitor TTL 固定为7天，主控人默认看不到问题正文；举报或法律 hold 只保留最小必要证据。
- 可识别第三方敏感内容默认不公开；产品希望由主控人负责日常发布，但有效异议和法定义务仍可触发暂停。
- 匿名公开访问、社交关注和私人 Projection 直接查询仍不进入 MVP。

### 4.4 Voice / Digital Human MVP Gate

- 声音复刻和复刻 TTS 是 MVP 必需切片；数字人是独立 Beta。
- 基础 Voice MVP 只要求 Owner private 与授权 Family Voice；Visitor Voice 保留独立用途合同，但作为独立 capability/cohort，不阻断基础 MVP。
- 主控人日常选择已确认，但逝者无生前明确授权、未成年人声音/Persona、第三方声音仍需专项法律和 Provider Gate；服务协议不能单独关闭这些门。
- 训练、私人问答、家庭播放、Visitor 和商业展示分用途授权；任意文本合成、跨人物音色借用和无来源人格表达继续禁止。
- 精确商业配额暂缓，但每家庭/用户资产隔离、Provider硬配额、unknown reconcile、文字降级和删除回执必须先实现。

### 4.5 可立即执行的安全默认

- future features 默认关闭，不因当前代码存在而公开。
- assistant/Visitor/runtime 不作为用户事实。
- Publication/Visitor、声音和数字人只在对应 MVP Gate 通过后按受控 cohort 开放。
- 高敏、unknown、未成年人和第三方敏感内容在外部门未关闭前按最高限制处理。
- 删除/撤回先阻断新访问，部分清理未完成时如实显示。
- 不复制或使用 Hermes/AOS 目录中的凭据和 memory 数据。

## 5. 决策变更流程

1. 任何状态变化必须记录日期、决策人/角色、证据和替代方案。
2. `RECOMMENDED_PENDING -> CONFIRMED` 必须有 E2 证据，不能由代码提交自动触发。
3. `EXTERNAL_REQUIRED` 关闭需要合同、供应商回执、真机/生产报告或合规批准的具体引用。
4. 改变 fail-closed 默认必须先更新威胁模型、迁移/回滚和验收门。
5. 已进入开发的决定发生变化时，路线图任务必须重新评估，而不是只改文案。
