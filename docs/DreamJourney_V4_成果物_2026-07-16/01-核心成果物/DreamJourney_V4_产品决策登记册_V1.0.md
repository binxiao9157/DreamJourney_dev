# DreamJourney V4 产品决策登记册

版本：V1.4 2026-07-16 引导式访谈产品决策基线
初版日期：2026-07-12
更新日期：2026-07-16
状态：已同步 M0-M4 风险边界和引导式访谈交互原则；静态记忆、在世本人语音、成年人授权互动、纪念互动和知识许可分别过门，工程、法律、供应商、备案、生产与真实用户证据仍按各自 Gate 独立关闭
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
| DR-002 | C-02：Publication/Visitor 的发布范围 | Product/Scope | `CONFIRMED` | 静态“Ta 的故事”和家庭贡献可在 M0 私人域运行；持续人格化的 Publication/Visitor 查询进入 M2，仅允许完成成年人校验的注册或受邀访问者读取在世主体主动发布的独立、可撤回副本。匿名公开与逝者人格互动不进入 M2 | 没有成年人状态、独立 PublicationVersion、授权上下文、监管发布门和撤回链路时入口关闭 | `WP-S3-01` 拆分为 M0 家庭贡献与 M2 成年授权查询；与 Owner 文字核心隔离 | Product | 2026-07-16 新规调整；M2 仍需身份、隐私、安全评估、算法备案与 G2/G4 |
| DR-003 | C-03：Family/Care/TimeLetter 首发范围 | Product/Scope | `CONFIRMED` | M0 允许经授权的家庭成员提交材料、人物切换和只读“Ta 的故事”；家庭关系不自动产生人格查询权。持续人格化查询进入 M2；Care/TimeLetter 后置，老人健康协同进入 M3 独立产品线 | Care/TimeLetter 默认关闭；Family 未完成 AuthZ 时只能查看公开说明，不得读取或互动 | 家庭共建服务静态记忆核心；互动、健康和后续能力分别过门 | Product | 2026-07-16 新规调整 |
| DR-004 | C-04：本人、家人、逝者纪念人格与主控边界 | Product/Rights/Voice | `CONFIRMED` | 经核验的在世主控人可建立 MemorialVault、邀请 Family Contributor 并管理静态纪念资料；逝者是 Represented Persona，不是登录 principal。M0 不复刻逝者声音、肖像或持续人格。无可验证生前专项授权的逝者 Voice/Portrait/DH 为 `NO_GO`；有完整权利链的成人纪念互动也只能进入 M3 逐案法务与伦理试点 | 身份/死亡事实/关系/素材权利或人工复核缺失时不创建正式纪念档案；逝者高风险能力默认 blocked | 支持家庭静态共建，同时切断“建档即复刻/互动”的错误推导 | Product + Privacy/Legal + Architecture | 2026-07-16 新规调整；M3 仍受 DR-026/031/036/037 与专项法律意见 |
| DR-005 | C-05：首版自助导出范围 | Data rights | `CONFIRMED` | M0 提供本人交互记录、本人上传资料、已确认记忆和自传的可读导出，并提供可机读结构化清单；第三方受限内容、供应商内部资产和争议材料按权利规则裁剪。复制、删除和导出是产品能力，不能仅依赖协议或人工兜底 | 未实现可验证复制/删除/导出前不宣称用户可迁移；任何缺失项和限制必须逐项披露 | 增加 M0 数据权利工程量，换取停服迁移、删除和用户控制的可验证性 | Product + Privacy/Legal | 2026-07-16 新规调整；格式、第三方裁剪和 G4 仍需冻结 |
| DR-006 | C-06：独立发布副本与公开索引 | Architecture/Privacy | `CONFIRMED` | M2 成年授权访问必须读取钉住 Memory Version 的独立脱敏 PublicationVersion、独立索引和独立数据库读取角色；拒绝 `isPrivate=false`、私人 Projection 过滤视图或整库直接暴露 | 不存在独立 Publication authority 与读取角色就不开放 | `WP-S3-01` 是 M2 必需包；保护私人域不被家庭关系或提示词绕过 | Architecture + Privacy/Legal | 2026-07-16 新规调整；G2/G4 后才可真实开放 |
| DR-007 | C-07：未确认材料如何参与问答 | Product/AI | `CONFIRMED` | 确定性回答只使用已确认记忆；未确认材料通过自然问答追问补齐并进入批量候选确认。长期入口固定为一个自然输入，最多提供一条“接着聊”和一条“换个角度”的动态推荐；主题聚类和缺口由系统内部管理，不要求用户维护主题目录。未确认、AI 推断和家属陈述必须保留状态与视角，不能伪装成事实 | 未确认材料不进入确定性 QA/Publication；禁问、敏感、无权或仅由 AI 推断的线索不进入主动推荐 | 降低确认和主题管理负担，需要访谈编排、批量审核、用户边界和可解释差异 | Product + Architecture | 2026-07-16 引导式访谈细化确认 |
| DR-008 | C-08：文字、声音复刻与数字人发布关系 | Product/Conversation | `CONFIRMED` | M0 是非持续人格化的私人文字记忆与有来源问答；M1 只允许完成成年人强身份与活体核验的在世主体克隆本人声音并私用；M2 才允许在世主体主动发布的成年人语音/数字分身互动；逝者互动进入 M3 逐案审查。Conversation/Message Authority 与声音/DH runtime 分开 | Voice/DH 不可用不得阻断 M0；不满足年龄、主体、授权、场景或监管门时拒绝人格化输出并回中性文字 | `WP-V0-01` 按 M1 自身语音、M2 在世数字分身、M3 纪念试点拆分证据 | Product + iOS + Backend | 2026-07-16 新规调整；真实能力仍需法律、Provider、配额、备案和真机 G3/G4 |
| DR-009 | C-09：真实资料处理 vs mock upload | Architecture/External | `EXTERNAL_REQUIRED` | Stage 2 接对象存储、扫描、OCR/ASR/PDF/DOCX processors；视频只存不理解。供应商选择保持 port 隔离 | mock/local-only 入口不公开为云能力 | 需要存储合同、删除 SLA、成本和任务系统 | Architecture + Operations | Stage 2 开发前 |
| DR-010 | C-10：Visitor 身份与邀请模式 | Security/Product | `CONFIRMED` | M2 仅允许已验证成年用户或具有过期/限次 grant 且完成成年校验的受邀访问；匿名入口后置，家庭关系本身不自动产生查询权限，未成年人不得访问虚拟亲属或持续人格互动 | 无成年证明、匿名或无有效授权上下文一律 deny | 降低拟人化互动滥用与未成年人风险，家庭用户需各自登录 | Product + Security | 2026-07-16 新规调整；G2/G4 后开放 |
| DR-011 | C-11：账号注销与上传记录删除 | Data rights | `CONFIRMED` | 账号注销采用“立即撤销访问 + 30 日可披露恢复窗口 + 到期分层 purge”。上传人可不可撤回地删除自己提交的 Source；删除必须级联暂停依赖 Memory/Publication/QA，并保留最小删除回执。纪念账户主控权和共同材料不得因主控账号注销被静默删除 | 账号注销立即撤销 session/grant；Source 删除立即停止未来使用；无 purge receipt 不称完成 | 需要把账号、Vault、Source、声音/DH资产四类删除分开实现 | Product + Privacy/Legal | 2026-07-15 产品确认；法律 hold/第三方权利和供应商回执仍需 G4/G3 |
| DR-012 | C-12：AOS 完整能力主张无源码支撑 | Evidence/Architecture | `REJECTED` | 不把 AOS MemoryStore/Slot/Scatter 当组件集成；只借鉴 raw/derived、promotion、bounded workflow 原则 | Hermes/AOS 目录不进入产品依赖或仓库 | 避免重写和不可验证基础设施 | Architecture | 已由证据审计关闭；重新采用需新证据 |
| DR-013 | C-13：FR 与验证优先级 | Product/Priority | `CONFIRMED` | 依赖顺序为安全/身份/备份恢复基础、M0 记忆资产与私人文字问答、M1 在世成年人本人私有语音、M2 成年授权 Publication/Visitor 与在世数字分身、M3 老人健康和成人纪念试点、M4 知识许可 | 不按旧 P0 标签并行开发；后续阶段未过门不反向阻塞 M0 | 用五级价值门替代“大爆炸式完整 MVP 验证” | Product + Engineering | 2026-07-16 新规调整 |
| DR-014 | C-14：Voice/Digital Human 发布层级 | Product/Voice | `CONFIRMED` | M1 只允许在世成年人训练并私用本人声音；M2 才允许在世主体主动发布的成年人语音或数字分身互动；M3 只对权利链清晰的成人纪念互动做逐案试点。Voice/DH 失败或外部 Gate 未关闭时回退中性文字，不冒充已启用 | 缺主体本人授权、年龄、活体、Provider、真机、质量、地域、评估或备案证据时对应能力 blocked | 保留语音价值并切断家庭代录、未成年人虚拟亲属和逝者自动复刻 | Product + Privacy/Legal | 2026-07-16 新规调整；真实训练/合成仍需 G3/G4 |
| DR-015 | C-15：assistant 回复与批量记忆确认 | Product/AI | `CONFIRMED` | 延续 `userEvidenceOnly`；每轮最多提出一个主要问题，同一线索通常深挖2至4轮后先总结。退出页面前或约5至10轮对话后，再将可追溯用户陈述汇总为候选批次供用户一次审核；两种轮次是独立状态，assistant/Visitor 输出不能自动成为 Source | 未完成批次确认的内容不进入正式记忆、Publication 或人物事实回答；访谈编排器无权直接写 MemoryVersion | 降低确认打扰并保持自然节奏，需要批次来源、逐项撤销、部分接受和访谈状态控制 | Product + Architecture | 2026-07-16 引导式访谈细化确认 |
| DR-016 | C-16：Source/Memory 变化后的发布失效 | Privacy/Contract | `CONFIRMED` | Source 删除、Memory 修正/删除、第三方异议或 grant 过期时，依赖 Publication 同步进入 `suspended`；恢复发布需主控人重审并生成新版本 | 先停未来访问，再异步清索引和对象 | 保证安全优先，可能产生暂时不可用 | Product + Privacy/Legal | 2026-07-15 产品确认；暂停 SLO 由测量合同验收 |
| DR-017 | C-17：地域、匿名、声音、留存、成本未决 | Cross-functional | `EXTERNAL_REQUIRED` | 建立阶段入口门，分别由 DR-023 至 DR-028、DR-031 决定；不得由工程选择默认供应商或地域 | 不采集/出站/公开对应数据 | 可能阻塞真实用户和 provider 扩量 | Product + Privacy/Legal + Finance | 对应阶段开发前 |
| DR-018 | C-18：绝对可信/可控文案 | Product/Legal | `REJECTED` | 禁止“完全可信/完全可控/彻底删除/不会冒用/立即撤回”；使用“用户可管理、显示来源、按披露边界处理，AI 可能出错” | 对外不作不可证明保证 | 降低营销强度，避免错误合规承诺 | Product + Privacy/Legal | 所有公开文案前 |
| DR-019 | C-19：北极星和发布门 | Product/Metrics | `CONFIRMED` | 采用 WTMR：跨会话且至少跨一个自然日复用此前已确认的 active Memory 并显式 helpful；A72 衡量激活，R28 衡量持续复用，GHR 分母保留失败/无引用/未反馈 | 未有服务端事件前不声称达标；onboarding 自循环不计 | 需要服务端事件管线、eligible attempt 和 cohort 基线 | Product + Data | 2026-07-15 产品确认；阈值仍需真实数据校准 |
| DR-020 | C-20：Hermes 目录凭据和权限风险 | Security | `EXTERNAL_REQUIRED` | 立即轮换可见凭据、收紧目录/文件权限、从备份和分享范围移除；DreamJourney 不复制该目录或凭据 | 不读取/导入其配置和 memory 数据 | 外部安全整改，不改产品代码 | Security + 资产 Owner | 立即；任何复用前必须有整改证据 |
| DR-021 | C-21：永久 TimeRiver vs 删除权 | Privacy/Architecture | `REJECTED` | 不采用永久不可删时间河或无法追踪副本的自研存储；所有 authority/projection/object/provider/backup 必须进入删除矩阵 | 无删除证明的存储不接真实用户数据 | 牺牲“永久记忆”叙事，保留数据权利 | Architecture + Privacy/Legal | 目标架构冻结前 |

## 3. 跨冲突新增决策

| ID | 证据/主题 | 类型 | 状态 | 方案与备选 | Fail-closed 默认 | 影响 | 决策 Owner | Gate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DR-022 | 未成年人和可识别第三方权利 | Privacy/Product | `EXTERNAL_REQUIRED` | 未成年人只能作为由监护人管理的静态成长资料数据主体，不得向其提供父母、祖辈、兄弟姐妹、伴侣等虚拟亲属，也不得通过改名规避角色实质。儿童成长分析若未来另立项目，必须使用未成年人模式、年龄识别、监护同意、时长/现实提醒、角色屏蔽和支付限制，不输出决定性人格或职业结论 | 未成年人账户或访问者命中虚拟亲属/持续人格场景时服务端硬拒绝；监护证据或专项政策缺失时仅允许最小隔离草稿 | 从当前路线永久删除未成年人虚拟亲属；其余未成年人数据仍属高敏外部门 | Product + Privacy/Legal | 2026-07-16 新规硬边界；其他未成年人资料处理前需 G4 |
| DR-023 | 首发登录与账号恢复 | Security/Product | `CONFIRMED` | 首发采用手机号注册登录，必须实现 SMS OTP、session rotation/revoke、换号/丢号受控恢复和账号关联防冲突；手机号文本不能直接作为数据 owner authority | 未验证手机号或 alias 冲突时不开放高敏数据、家庭邀请或 Provider | 影响短信成本、恢复运营和冒领防护 | Product + Security | 2026-07-15 产品确认；短信与恢复 G2/G4 |
| DR-024 | Operator/Admin 内部访问 | Security/Operations | `CONFIRMED` | Operator 默认仅看脱敏任务元数据；Admin break-glass 需要工单、理由、短时、双人批准、字段最小化和不可修改审计，默认不得修改用户事实 | 内部角色无私人正文默认权限 | 增加运营审批与审计实现 | Security + Operations | 2026-07-15 产品确认 |
| DR-025 | AI 身份、依赖、退出与危机安全 | Safety/Product | `CONFIRMED` | 所有人格化界面持续披露 AI；每连续使用2小时提供可审计提醒；UI、语音和退出关键词由确定性代码立即退出，Persona 不得挽留。自伤、自杀、重大丧失或“想去陪逝者”等高风险表达立即退出人格模拟，切换中性安全助手，并按适用规则联系监护人/紧急联系人；人格不得参与支付劝导、医疗金融或重大现实决策 | 未完成年龄/联系人、地区资源、依赖检测、三通道退出和危机演练时禁止人格化互动 | 需要安全评估、年龄分层、投诉、紧急联系人、时长提醒和地区资源 | Product + Safety/Privacy | 2026-07-16 新规调整；M2/M3 上线前 G4 |
| DR-026 | 首发地域、processor/subprocessor 和跨境 | Privacy/Commercial | `EXTERNAL_REQUIRED` | 产品选择中国作为首发地域；数据库、对象与第三方处理的具体区域、跨境、子处理者、禁训练、留存、删除和事件通知仍需逐供应商核验 | 不把真实正文、声音、生物特征发送给未批准 processor；产品协议披露不能替代处理商合同或法定义务 | 可能限制模型和数字人供应商 | Privacy/Legal + Operations | 产品地域已确认；真实数据出站前需 G4/G3 |
| DR-027 | 多模型、语音、数字人成本停止线 | Finance/Product | `DEFERRED` | 产品接受预算、并发和自动降级原则，但首发暂缓确定商业预算。工程仍必须设置供应商硬配额、异常熔断和文字降级，避免无界费用；不得暂停数据权利任务 | 未批准的 Beta 不扩量；Provider 配额错误时回文字，不借用其他家庭资产 | 首发无法以成本目标验收扩量，需在种子数据后重新确认 | Finance + Product + Operations | 精确预算暂缓；真实扩量和数字人 Beta 扩容前必须重开 |
| DR-028 | Provider Adapter 与资产可迁移性 | Architecture/Commercial | `CONFIRMED` | 接口隔离只保证调用可替换；声音模型、数字人素材和授权可能需重新采集。产品不承诺训练资产跨供应商迁移，正式扩量前披露退出和重训成本 | 无 exit/delete 路径的 provider 不承载高敏正式资产 | 可能增加重新训练成本但降低错误承诺 | Architecture + Commercial | 2026-07-15 产品确认；Provider exit 证据仍需 G3 |
| DR-029 | “Canonical Memory”含义、人物记忆维度和类型化存储合同 | Product/Architecture/Data | `CONFIRMED` | 产品 UI 使用“已确认记忆记录”；技术名 `CanonicalMemory` 只表示 Owner 当前采用版本。采用 Spec 24.4A：共同 Memory Authority 主干 + `MemoryKind/PerspectiveType/EpistemicStatus` 三个正交维度 + versioned typed content schema + `memory_relations`。首批冻结 `experience/knowledge/emotion`，完整本体覆盖 skill/relationship/preference/habit/value/decision/goal/self_narrative；人格为有证据的 PersonaProjection，声音形象为 EmbodimentProfile。拒绝每人一份大 JSON、自由 JSONB、把第三方/AI视角当内容类型以及把 KBLite/图/向量库作为事实 Authority | 未知 kind/schema、视角不明、未确认推断一律 quarantine，不进入 Projection/QA/Publication；情感和第三方关系默认高敏且不批量发布；不用“真相/真实人格”描述用户回忆或模型推断 | 增加 schema registry、relation 表、类型校验、迁移分类和查询策略；研发按合同实现，不再自行决定人物本体 | Product + Architecture + Data + Privacy | 已于 2026-07-14 确认；`WP-S1-01` Schema/API 冻结和真实数据迁移前完成实现符合性验收 |
| DR-030 | 用户明确：PRD/Blueprint/分析可更新且不是最终产物 | Document governance | `CONFIRMED` | V4 Product Spec 定稿后为唯一产品范围权威；旧文档保留历史正文、增加 lifecycle banner 和 V4 链接 | 冲突时按源码事实 + V4 + 决策登记册，不按旧 P0 开发 | 需要更新引用和协作规范 | Product/主控 | Round 2 完成前 |
| DR-031 | 平台/Provider 训练、样本/正文留存和删除条款未证实 | Privacy/Provider | `EXTERNAL_REQUIRED` | 私人记忆、哀伤对话、声音、人脸、健康和未成年人数据默认禁止用于平台通用模型或供应商通用训练；任何例外必须具体目的、单独同意、可拒绝且不影响核心服务。合同需说明用途、地域、留存、删除回执、安全事件和子处理者 | 无可审计数据用途与合同不发送正文、生物特征或高敏数据 | 可能排除部分 provider；影响成本和质量，但保留私人模型可信边界 | Privacy/Legal + Commercial | 任何真实 provider 或训练数据前 |
| DR-032 | 产品事件和指标 Authority | Product/Data | `CONFIRMED` | 事件由服务端事务/outbox 产生，使用稳定 owner/object version/idempotency；排除 QA/mock/internal，客户端事件只补交互；用于 WTMR、A72、R28 和 GHR | 无可验证事件不声称北极星或转化达标 | 需要 typed analytics contract 和隐私最小化 | Product + Data + Privacy | 2026-07-15 产品确认；G2 数据后校准阈值 |
| DR-033 | 产品确认基线与可逆边界 | Architecture governance | `CONFIRMED` | 2026-07-15 产品回复是当前 E2 产品基线；确认项可以进入开发，外部依赖项仍只能做 port、mock、contract 和 fail-closed，不得把产品意图当法律或生产批准 | 外部门未关闭的能力保持 blocked | 结束“全部产品决定开放”状态，同时保留外部门 | Product + Architecture | 2026-07-15 产品确认 |
| DR-034 | Final review RV-11：legacy confirmed 仅在 Projection | Data migration | `RECOMMENDED_PENDING` | 只有 owner/source/decision receipt 完整者可迁为 Memory v1；缺证据进入 `legacy_needs_review`，observed/candidate/rejected/superseded 分级映射，按 authorityEpoch 切换 | legacy 未验证内容不进确定性 QA/Publication | 增加审核和迁移成本，避免丢数据或伪造确认 | Product + Architecture | Round 3 migration 设计前 |
| DR-035 | Final review RV-02/RV-12：撤权后删除/审计失去授权 | Security/Privacy | `RECOMMENDED_PENDING` | 分离 ProcessingBasis/Consent、AccessGrant、WorkAuthorization、DataRightsAuthorization、RetentionHold 和短期 ProviderCapability；禁止通用 system 绕过 | 普通访问撤销，已受理数据权利 job 仅凭最小 operation authorization 继续 | 新增 policy/job authority，修复删除死锁 | Security + Privacy/Legal + Architecture | Round 3 auth/job 设计前 |
| DR-036 | 第三方、未成年人静态资料、逝者用途和权利请求 | Privacy/Product | `EXTERNAL_REQUIRED` | 经核验主控人可承担静态纪念档案的日常内容与冲突处理，但不能用协议替第三方、未成年人或逝者创造新的人格授权。架构按私人保存、AI/QA、Publication、Voice/Persona 分用途，提供 RightsRequest、异议冻结和 receipt；未成年人虚拟亲属/Voice/Persona 直接适用 DR-022 硬拒绝 | 未取得中国首发专项法律意见、监护/关系证据和 Provider 允许前，未成年人静态资料外发、第三方公开和逝者 Voice/DH 均 blocked；有效权利请求可触发 scope hold | 产品日常主控与外部法律边界分离，避免把协议勾选误当免责 | Privacy/Legal + Product | 未成年人静态资料、第三方公开和 M3 逝者高风险申请前需专项 G4；未成年人虚拟亲属不设放行 Gate |
| DR-037 | Voice 资产、用途授权和合成内容绑定 | Voice/Privacy | `CONFIRMED` | M1 训练主体必须是完成成年人强身份、随机授权语句和活体检测的在世本人，仅限私有问答；M2 的发布/Visitor 使用需另行授权。Profile 状态与 grant 分开；合成绑定 answer/publication、text hash、policy、profile version、purpose 和 GeneratedAudio TTL/receipt，不开放任意文本配音、原始下载、跨人物音色或人格化促购 | 主体不是在世本人，或缺用途、来源、授权、标识、TTL/删除回执时拒绝；家庭代录和逝者训练不得复用 M1 | 影响现有 synthesis API 和缓存，降低滥用与声音人格权风险 | Product + Privacy/Legal + Architecture | 2026-07-16 新规调整；M2/M3 需重新评审 |
| DR-038 | Visitor 输入生命周期 | Privacy/Product | `CONFIRMED` | VisitorSession、Message 和 IP/device 派生标识默认 TTL 为7天；主控人默认只看授权使用统计和安全事件，不看问题正文。主动共享、合法争议或 RetentionHold 仅保留最小必要证据 | 到期或撤权停止读取和 Provider 处理；默认不向主控人展示正文 | 增加 MVP Visitor 数据权利与反滥用实现 | Product + Privacy/Legal + Security | 2026-07-15 产品确认；举报/法律保留例外需 G4 |
| DR-039 | 指标、SLO 与统一测量合同 | Product/Operations | `CONFIRMED` | 接受统一测量合同和现有 Projection/Retrieval DFX 作为研发基线；每个指标附 build/env/region/provider、负载、样本、窗口、分母、冷启动、超时和 artifact。未实测前不对用户承诺端到端时延 | 无 measurement metadata 不做 pass 或扩量 | 增加测试与遥测工作，减少选择性报告 | Product + Operations + Privacy | 2026-07-15 产品确认；具体扩量阈值需 G2 |
| DR-040 | 轻量迁移与未来完整迁移体系 | Architecture/Operations | `CONFIRMED` | 百级用户 MVP 采用强制最低版本、提前通知维护窗和四阶段轻量迁移：盘点/备份恢复、离线演练、维护窗冻结写入并切换、24至72小时观察与退役。C00-C11 保留为未来目标，当无法强制升级、无法接受维护窗或进入规模化运营时启用 | 缺 backup/isolated restore、迁移校验或 go/no-go 时不切换；post-cutover 不恢复 legacy 写 Authority | 当前显著降低执行负担，未来仍保留完整安全模型 | Architecture + Operations + Security + Product | 2026-07-15 产品确认；具体窗口/RPO/RTO需实测批准 |
| DR-041 | 账号切换、登出与本地草稿 | Product/Privacy | `CONFIRMED` | switch 只卸载并锁定同 subject 的加密显式草稿；logout 清 runtime/cache/export/notification，草稿只能由同一强验证 subject 恢复并提供清理选择；account delete 立即清全部本地用户数据 | 无 owner proof 的 legacy 数据 quarantine；保留草稿不跨账号显示、上传、索引或送 Provider | 保护未提交内容并增加本地迁移和清理 UX | Product + Privacy/Legal + iOS | 2026-07-15 产品确认 |
| DR-042 | 初创团队 MVP Operating Profile | Product/Architecture/Operations | `CONFIRMED` | 以百级用户、单一中国首发地域、模块化单体、单 Postgres、私有对象存储、单独 Worker、Provider Adapter、可强制升级和可维护窗口为当前 Operating Profile。115项路线按 M0-M4 和规模触发分层 | 不因轻量模式取消 Vault 隔离、来源引用、用途授权、访问撤回、复制/删除/导出、备份恢复和 Provider fail-closed | 让目标架构与初创团队能力匹配，同时保留规模化升级路径 | Product + Architecture + Operations | 2026-07-16 新规调整；工程实现与外部门仍分别验收 |
| DR-043 | M0-M4 产品验证与发布层级 | Product/Release/Architecture | `CONFIRMED` | 采用 `M0 记忆资产 -> M1 在世本人私有语音 -> M2 成年授权互动 -> M3 老人健康/成人纪念试点 -> M4 知识许可`。M0 验证自传、静态故事、Source→Review→QA→Citation→Correction→Copy/Export/Delete；M1 仅在世成年人本人声音；M2 才包含独立 Publication/Visitor 与在世数字分身；M3 逐案处理纪念互动；M4 处理权利目录和收益 | M0 只向受控 cohort 开放，不得以逝者复活、情感替代或完整数字人宣传；下一层未过门只关闭该层入口，不反向阻断 M0 | 解除供应商、真机、备案和纪念法律延期对早期核心价值验证的阻塞，同时与新规风险分层对齐 | Product + Architecture + Operations | 2026-07-16 新规调整；每层实现及适用 G0-G4 仍独立验收 |

### 3.1 Round 3C3C Provider 决策映射

Provider Effect、Credential 与 Exit 迁移沿用以下 Gate：`DR-026` 中国首发地域/processor、`DR-027` 暂缓的商业预算与必须保留的工程熔断、`DR-028` 资产不可默认迁移、`DR-031` 禁训练/留存/删除外部条款、`DR-037` Voice purpose binding、`DR-039` 测量合同。产品已确认资产边界、用途分离和测量原则；`DR-026/031` 仍是外部门，`DR-027` 的精确预算仍为暂缓，不能由设计或静态检查替代。

### 3.2 Round 3C4 组合 Runbook 决策映射

当前 MVP 以 `DR-040/042` 的四阶段轻量迁移为默认 Operating Profile，同时保留 C00-C11 作为规模触发后的完整目标。轻量迁移仍沿用 `DR-023` 手机强身份、`DR-026` 地域/processor、`DR-028` Provider资产退出、`DR-031` Provider数据条款、`DR-035` WorkAuthorization/DataRights、`DR-039` 测量合同和 `DR-041` iOS本地草稿边界。产品确认不能替代真实 backup/restore、迁移校验、维护窗批准和 Provider in-flight 对账。

### 3.3 Round 3D 独立评审映射

IAR-01..07、BAR-01..07、SOR-01..08 已在 Round 3 评审响应中映射到 CR-01..12 与稳定 `WP-*`。2026-07-16 新规风险基线保留 `DR-042` 的初创团队轻量实施方式，并把 `DR-043` 从三级验证改为 M0-M4 发布基线；身份/内部访问由 `DR-023/024/035`，第三方/未成年人由 `DR-022/036`，地域/Provider/Voice由 `DR-026/028/031/037`，依赖/退出/危机由 `DR-025`，成本/测量由 `DR-027/039`，迁移/本地草稿由 `DR-040/041/042` 承载。产品确认不会自动关闭法律、供应商、备案、安全评估、部署、真机和生产证据。

### 3.4 2026-07-14 Memory Ontology 架构修订

产品评审明确确认并扩展 `DR-029`，其规范落点为 Product Spec 24.4A，执行落点为 `WP-S1-01`。研发可以选择满足合同的内部代码组织和优化方式，但不得改变 MemoryKind、视角/认知状态分离、版本化 Schema、关系 Authority、人格 Projection 以及声音形象非事实权威等产品不变量；如需变更，必须新增决策并重新评审。

### 3.5 2026-07-14 Memorial Persona 架构修订

产品评审明确确认并扩展 `DR-004`：直系/近亲属完成身份、死亡事实和关系核验后，可以建立由在世主控人管理的逝者 MemorialVault，邀请家庭成员共同提交材料和完善私人、静态知识库。规范落点为 Product Spec 8.3、12.7、16.6、17.4 和 24.4B；M0 执行复用 `WP-S0-02/05/06`、`WP-S1-01/02/03`，不新增并行 Authority。`WP-S3-01/WP-V0-01` 只有在 M2/M3 对应 Gate 通过后才可使用。

该确认不采用“近亲属继承逝者授权”的表述。近亲属保护和个人信息请求权、产品日常主控权、逝者生前意愿证据以及每个 Voice/Portrait/DH/Publication purpose 的能力决定是四个不同对象。`DR-022/026/031/036/037`、首发法域专项法律意见、Provider 允许、生成内容标识和拟人化互动服务义务仍保持开放或外部门，不能因 `DR-004=CONFIRMED` 自动关闭。

### 3.6 2026-07-15 产品逐项确认（历史基线）

产品负责人已完成独立方案评审第21章的40项回复。以下内容作为历史输入保留；与 2026-07-16 新规风险基线冲突的部分，以 3.8 和修订后的 DR-002/003/004/005/008/010/013/014/022/025/031/037/043 为准：

1. 保留三个主 Tab；当前采用百级用户、单一中国地域和四阶段轻量迁移；
2. 历史回复曾把手机登录、本人/纪念人物记忆、家庭人物切换、家属贡献、文字问答、家庭授权 Publication/Visitor 和声音复刻合并为 Product MVP，并把数字人作为 Beta Extension；该捆绑已被 M0-M4 解耦；
3. 未确认材料通过对话追问形成候选，在退出页面前或约5至10轮后批量确认，不逐轮打断；
4. 历史回复曾希望全龄人物资料进入产品范围；2026-07-16 起只允许监护人管理未成年人静态成长资料，未成年人虚拟亲属、Voice/Persona 和持续人格化互动硬拒绝；
5. 历史回复曾不提供首版自助批量导出；2026-07-16 起 M0 必须提供交互数据复制、可读导出、机器可读清单和删除状态。账号注销仍采用30日恢复，上传人删除自己的 Source 为不可撤回操作并触发依赖暂停；
6. 家庭和 Visitor 使用独立、可撤回授权上下文；Visitor 默认 TTL 为7天，主控人默认看不到访问者问题正文；
7. 产品希望由主控人承担家庭冲突、第三方内容和逝者高风险能力的日常选择，但服务协议不能替代平台法定义务、第三方权利请求或中国首发专项法律意见；
8. 历史回复曾将声音复刻放入 Product MVP、数字人放入 Beta Extension；2026-07-16 起改为 M1 在世成年人本人私有 Voice、M2 在世主体主动发布 Voice/DH、M3 成人纪念互动逐案审批；
9. 接受 WTMR、统一测量合同和 DFX 基线；精确成本和配额商业参数首发暂缓，但工程硬配额、熔断和文字降级不得暂缓。

上述是产品 E2 决策证据。`EXTERNAL_REQUIRED`、`DEFERRED` 和仍为 `RECOMMENDED_PENDING` 的项目没有因产品回复自动关闭。

### 3.7 2026-07-15 三级产品验证策略确认（已被 M0-M4 取代）

产品负责人曾接受“Closed Pilot、Product MVP、Beta Extension”分级建议。该分层保留为历史追踪，但自 2026-07-16 起不再作为当前发布命名；旧 Closed Pilot 的低风险文字核心映射为 M0，旧 Product MVP 的 Voice 与 Publication/Visitor 分别映射为 M1/M2，旧 Beta Extension 的能力按 M2/M3 重新过门：

1. `M0` 以 R3 Owner 文字核心、自传和静态“Ta 的故事”为价值验证切片，并增加可验证复制/导出；
2. `M1` 只增加在世成年人克隆本人声音的私有使用，不包含家庭代录、未成年人或逝者声音；
3. `M2` 承载在世主体主动发布、成年 Visitor、持续人格化语音/数字分身，并增加安全评估、算法备案、年龄/联系人、依赖提醒、2小时提醒、确定性退出和投诉机制；
4. `M3` 承载老人健康协同和权利链清晰的成人纪念互动逐案试点，`M4` 承载知识许可与收益；
5. 五层共享同一数据 Authority，不创建简化版旁路数据模型；层级通过不自动关闭下一层的法律、Provider、真机、隐私、备案或生产 Gate。

### 3.8 2026-07-16 新规生效后的产品风险基线

依据《寻梦环游产品问题、风险分级与整体规避方案 V1.0》，当前架构增加以下不可被研发或运营绕过的产品不变量：

1. 产品定位是“生前沉淀、私人记忆、授权调用与传承”，不是复活逝者、替代亲人、心理治疗或 AI 代理决策；营销、通知、支付和 Persona prompt 使用同一禁用表达清单。
2. 未成年人虚拟亲属永久移出路线；监护人同意不能把父母、祖辈等虚拟亲属变为可发布能力。
3. M0 的“Ta 的故事”是静态纪念档案；持续人格化互动不因家庭关系、账户主控权或素材上传自动获得许可。
4. M1 只允许在世成年人本人声音；逝者、第三方、家庭代录和未成年人声音不得复用此流程。
5. M2/M3 上线前必须完成适用的安全评估报告、算法备案、AI 标识、年龄/联系人、依赖与2小时提醒、确定性退出、投诉举报和危机演练。
6. 私人和敏感数据默认不训练平台或供应商通用模型；复制、删除、导出和停服迁移不能只依赖人工承诺。
7. 逝者无生前专项授权的 Voice/Portrait/DH 保持 `NO_GO`；即使权利链完整，也只允许在 M3 逐案法务与伦理评审后试点。

### 3.9 2026-07-16 引导式访谈与知识丰满化确认

本节是 `DR-007` 与 `DR-015` 的交互和架构细化，不新增决策编号，也不改变43项决策总数。完整功能合同见[引导式访谈与知识丰满化功能说明](./DreamJourney_V4_引导式访谈与知识丰满化功能说明_V1.0.md)。产品负责人确认：

1. 长期主入口只有一个自然输入“今天想聊点什么？”，不把“随便聊、继续故事、选择主题”长期并列为三个入口。
2. 系统最多展示两条动态推荐，固定分工为“接着聊”与“换个角度”；两条不能只是同一评分榜的前两名，没有安全候选时可以少于两条。
3. 第一条优先延续近期主动表达、待续或未完成故事；第二条优先补足重要但覆盖较弱的知识维度，并与第一条去重。
4. 主题可以增长，但由系统内部聚类、合并和收敛；人生地图和语义搜索是次级回顾工具，用户不负责维护成百上千个主题。
5. 模式半显性、当前话题轻度可见；深挖轮次和疲劳状态保持内部。用户始终可选择“这次跳过、以后再聊、不再问这个话题”。
6. 推荐优先级为“用户明确意愿 > 情绪与隐私安全 > 对话连续性 > 知识完整性 > 系统判断的重要性”；创伤、丧亲、疾病和家庭冲突不得仅因知识缺口大而主动推荐。
7. 每轮最多一个主要问题，同一线索通常深挖2至4轮后总结；Candidate 仍在退出或约5至10轮后批量审核，两套节奏不得混为一套计数器。
8. `Interview Orchestrator`、ConversationThread 和知识覆盖只是对话控制或 Projection；不能越过 Source→Candidate→DecisionReceipt→MemoryVersion 权威链，也不能把 AI 推断当作用户事实。

## 4. 决策队列

### 4.1 M0-M4 产品范围已确认

- M0：三 Tab、手机登录、自传、静态“Ta 的故事”、Family 材料贡献与人物切换、一个自然输入与两类动态推荐、引导式访谈、Owner Truth Loop、批量候选确认、来源引用、纠正、复制/导出/删除、30日账号恢复和本地草稿。
- M1：在世成年人完成强身份、随机授权语句和活体核验后，克隆并私用本人声音。
- M2：在世主体主动发布独立副本，成年 Visitor 在授权范围内进行文字/语音/数字分身互动。
- M3：老人主动授权的健康协同，以及权利链清晰的成人纪念互动逐案试点；Care/TimeLetter 不自动并入。
- M4：权利目录、知识许可、受益人和收益结算。
- WTMR、统一测量合同、DFX 和四阶段轻量迁移继续有效。

产品范围确认只允许路线重新排序，不代表相应 Work Item 已实现或可真实发布。

### 4.2 各阶段仍需关闭的产品实现/外部门

- `DR-009`：真实对象存储、扫描和媒体处理供应商。
- `DR-017/026/031`：中国首发的具体处理地域、跨境、供应商训练/留存/删除和子处理商证据。
- `DR-020`：Hermes 外部凭据整改。
- `DR-022/036`：未成年人静态资料、第三方、逝者 Voice/DH 和主控责任条款的专项法律结论；未成年人虚拟亲属不进入待决队列，直接禁止。
- `DR-034/035`：legacy 数据分级与 machine/data-rights authorization 详细合同。
- `DR-027`：精确商业成本暂缓；工程配额和熔断仍必须实现。
- 真实短信、备份恢复、Provider、真机、性能和维护窗仍需 G2/G3/G4 证据。

### 4.3 M2 Publication / Visitor Gate

- 只允许在世主体主动发布的独立 PublicationVersion、成年身份、认证/限次/可过期 grant 和可撤回授权上下文；Family 关系不自动授权。
- Visitor TTL 固定为7天，主控人默认看不到问题正文；举报或法律 hold 只保留最小必要证据。
- 可识别第三方敏感内容默认不公开；产品希望由主控人负责日常发布，但有效异议和法定义务仍可触发暂停。
- 匿名公开访问、未成年人虚拟亲属、逝者人格互动、社交关注和私人 Projection 直接查询仍不进入 M2。

### 4.4 M1/M2/M3 Voice / Digital Human Gate

- M1 只允许在世成年人本人声音与私人 TTS；M2 才允许在世主体授权的成年 Visitor 声音/数字分身；M3 才可能处理成人纪念互动。
- 无生前明确用途授权的逝者 Voice/DH 保持 `NO_GO`；未成年人虚拟亲属和未成年人 Voice/Persona 不进入当前路线；服务协议不能单独关闭这些门。
- 训练、私人问答、发布/Visitor 和商业展示分用途授权；任意文本合成、音频下载、跨人物音色借用、情感促购和无来源人格表达继续禁止。
- M2/M3 额外要求安全评估、算法备案、成年人校验、紧急联系人、依赖/2小时提醒、确定性退出、投诉和危机演练。
- 精确商业配额暂缓，但每家庭/用户资产隔离、Provider硬配额、unknown reconcile、文字降级和删除回执必须先实现。

### 4.5 可立即执行的安全默认

- future features 默认关闭，不因当前代码存在而公开。
- assistant/Visitor/runtime 不作为用户事实。
- Publication/Visitor、声音和数字人只在对应 M1/M2/M3 Gate 通过后按受控 cohort 开放。
- 未成年人虚拟亲属、无生前专项授权的逝者复刻、人格化促购和人格参与重大现实决策为硬拒绝，不进入灰度。
- 高敏、unknown、未成年人和第三方敏感内容在外部门未关闭前按最高限制处理。
- 删除/撤回先阻断新访问，部分清理未完成时如实显示。
- 不复制或使用 Hermes/AOS 目录中的凭据和 memory 数据。

## 5. 决策变更流程

1. 任何状态变化必须记录日期、决策人/角色、证据和替代方案。
2. `RECOMMENDED_PENDING -> CONFIRMED` 必须有 E2 证据，不能由代码提交自动触发。
3. `EXTERNAL_REQUIRED` 关闭需要合同、供应商回执、真机/生产报告或合规批准的具体引用。
4. 改变 fail-closed 默认必须先更新威胁模型、迁移/回滚和验收门。
5. 已进入开发的决定发生变化时，路线图任务必须重新评估，而不是只改文案。
