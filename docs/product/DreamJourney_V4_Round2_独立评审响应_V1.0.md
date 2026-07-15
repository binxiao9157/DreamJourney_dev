# DreamJourney V4 Round 2 独立评审响应

版本：V1.0 Working Draft
日期：2026-07-12
范围：产品定位、领域模型、隐私安全、指标、运营和 Product Spec 完整性
关联：[Product Spec V4](./DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md) · [决策登记册](./DreamJourney_V4_产品决策登记册_V1.0.md)

## 1. 响应状态

| 状态 | 含义 |
| --- | --- |
| `ACCEPTED` | 异议成立，Product Spec/登记册已按建议修正 |
| `PARTIALLY_ACCEPTED` | 核心风险成立，但实现或产品选择仍需外部决定 |
| `DECISION_REGISTERED` | 无法由本轮直接决定，已进入明确 Decision ID 和 fail-closed |
| `REJECTED_WITH_REASON` | 经证据核对不采用，并记录原因 |

## 2. 产品与范围审查响应

| Review ID | 严重度 | 异议 | 响应 | 规范落点 | 残余项 |
| --- | --- | --- | --- | --- | --- |
| PV-01 | Blocker | 当前老人/家庭回忆提示与泛 Owner PRD 目标漂移 | `ACCEPTED` | Spec 2.1 收紧为 18+、中文 iPhone、有资料且愿意审核的 Owner；DR-022 | 60+ 只作为获客 cohort，需数据验证 |
| PV-02 | Blocker | 高风险表达进入 5-10 分钟延迟回信，系统 prompt 声称“不是机器人” | `ACCEPTED` | Spec 15.4、16.5、20；DR-025 | Stage 0 需落实代码和地区安全政策 |
| PV-03 | Blocker | 当前没有 Source/Candidate/Memory/Conversation authority | `ACCEPTED` | Spec 9、10、14、20 | Round 3 定义增量 schema/API/migration |
| PV-04 | High | observed 可未经 Owner 确认成为问答事实 | `ACCEPTED` | Spec 11.3、12.4、15.1；DR-007 | 需 legacy observed 迁移和 context policy 实现 |
| PV-05 | High | Care/Family/TimeLetter/Voice/DH 当前默认开启，阶段边界失效 | `ACCEPTED` | Spec 3、19.1、20；DR-003/DR-014 | Stage 0 改 server/release policy 并补误露 gate |
| PV-06 | High | 没有产品事件管线，原指标无法计算且易被自动生成刷高 | `ACCEPTED` | Spec 6、19.3/19.4；DR-019/DR-032 | 事件 schema/outbox 和基线在路线图实现 |
| PV-07 | Medium | 四 Tab Blueprint 会暴露尚不存在的产品域 | `ACCEPTED` | Spec 5；DR-001 | 只有 Publication/Visitor 形成高频任务后再评审第四 Tab |

## 3. 领域、权限与状态审查响应

| Review ID | 严重度 | 异议 | 响应 | 规范落点 | 残余项 |
| --- | --- | --- | --- | --- | --- |
| DM-01 | Blocker | principal、业务角色、Persona 主体和 runtime persona 混用 | `ACCEPTED` | Spec 8、9、16.2；DR-023/DR-024 | 目标 auth/role schema 在 Round 3 定义 |
| DM-02 | Blocker | Archive、Knowledge、Candidate 和 Memory 缺少唯一 authority | `ACCEPTED` | Spec 9、20 | 现有 JSONB/KBLite 只作迁移输入/Projection |
| DM-03 | Blocker | 私人 Projection 可被误作公开过滤视图，runtime 可能反写事实 | `ACCEPTED` | Spec 10、15.5；DR-006/DR-015 | Stage 3 前需隔离测试和 Public Index |
| DM-04 | High | 业务、处理、上传和 provider 状态混在一个 status | `ACCEPTED` | Spec 11.1 至 11.7 | 目标 typed enums 与 legacy 映射由 Round 3 定义 |
| DM-05 | High | privacy、consent、visibility、publication 被布尔/字符串混合 | `ACCEPTED` | Spec 12；DR-005/DR-006/DR-035 | ProcessingBasis/Consent、AccessGrant 与 policy engine 待实现 |
| DM-06 | High | 纠正、删除、撤回缺少同步阻断和异步传播回执 | `ACCEPTED` | Spec 13；DR-011/DR-016/DR-021 | SLA 数值和 provider/backup 合同待确认 |
| DM-07 | High | 当前 `isPrivate/generationAllowed/system` 等会继续污染新模型 | `ACCEPTED` | Spec 20 的冻结/替换；证据矩阵 P0 风险 | 路线图必须先 shadow/read adapter，再切 authority |

## 4. 隐私、伦理与商业反方审查响应

| Review ID | 严重度 | 异议 | 响应 | 规范落点 | 残余项 |
| --- | --- | --- | --- | --- | --- |
| CR-01 | Blocker | 强身份、owner 写入、审计和删除未闭环却采集最高敏感数据 | `ACCEPTED` | Spec Stage 0、16、18；DR-023/DR-024/DR-031 | 真实用户数据前完成工程和外部验收 |
| CR-02 | Blocker | Owner 不是第三方或未成年人的权利代理人 | `ACCEPTED` | Spec 8.1、12.5/12.6、16.1/16.4；DR-022/DR-036 | 年龄核验、异议渠道和法域规则待确认 |
| CR-03 | Blocker | Publication 撤回无法收回截图、录音或外部副本 | `ACCEPTED` | Spec 11.5、13、17.3；DR-016/DR-018 | 公开前确认撤回 SLO 和风险披露 |
| CR-04 | Blocker | 复刻声音/数字人把幻觉升级为冒充风险 | `ACCEPTED` | Spec 17、18.3；DR-004/DR-014/DR-028/DR-031 | 成人闭测、活体、水印/披露和 kill switch 外部门 |
| CR-05 | Blocker | 数据库、对象、备份和 provider 无法支持“立即彻底删除” | `ACCEPTED` | Spec 13、16.4；DR-011/DR-018/DR-021 | 各层 SLA/receipt 和恢复演练待实现/确认 |
| CR-06 | High | “一生认知平台”过宽，没有单一产品假设 | `ACCEPTED` | Spec 1 至 3、7；DR-002/DR-013 | 先用 WTMR/A72/R28/GHR 验证 Owner 价值 |
| CR-07 | High | Adapter 不等于声音/数字人资产和授权可迁移 | `ACCEPTED` | Spec 17.3、19.3；DR-028 | provider 采购前需 exit plan 和迁移成本 |
| CR-08 | High | Care/危机需要运营体系，不能只靠 prompt | `ACCEPTED` | Spec 15.4、16.5、19；DR-003/DR-025 | 地区资源、责任人和值班/升级未定前 Care 关闭 |
| CR-09 | High | Canonical Memory 容易被误解为客观真相 | `ACCEPTED` | Spec 9.1、15.3；DR-029 | 技术名可保留，UI/文案统一“已确认记忆记录” |
| CR-10 | High | 多 provider/媒体/公开治理成本没有硬停止线 | `ACCEPTED` | Spec 18、19.3；DR-027 | 报价和两周基线后确认预算值 |

## 5. Round 2 响应结论

- 三类初始审查共 24 项高风险异议，全部有 Product Spec 或 Decision ID 落点。
- `ACCEPTED` 不表示工程已完成；只表示产品规范接受了问题并给出目标行为。
- 所有残余产品/合规/商业项继续保持 `RECOMMENDED_PENDING` 或 `EXTERNAL_REQUIRED`，不得因本响应表改成完成。
- Round 2 最终 reviewer 的新增问题使用 `RV-xx` 追加，并在进入 Round 3 前关闭 blocker。

## 6. 最终产品/安全 reviewer 响应

| Review ID | 严重度 | 异议 | 响应 | 规范落点 | 残余项 |
| --- | --- | --- | --- | --- | --- |
| RV-01 | Blocker | 没有已确认的 Round 3 架构输入，且 FACT/推荐状态混用 | `ACCEPTED` | Spec 0.1 状态映射、19.1 FACT 拆分、21.5 Architecture Input Freeze；DR-033 | 无 E2 的产品项只能形成 ADR 备选，开发前仍需确认 |
| RV-02 | Blocker | 普通 grant 撤销后删除、导出和审计任务失去授权 | `ACCEPTED` | Spec 12.2/12.4、13；DR-035 | Round 3 落地 machine principal 与 operation-scoped authorization |
| RV-03 | High | Data Subject 非 principal，minor/third-party 用途规则互相冲突 | `ACCEPTED` | Spec 12.6、13.2、16.1/16.4；DR-036 | 年龄保障、主体证明和法域流程仍需外部确认 |
| RV-04 | High | 危机安全在 Stage 0 policy/Stage 1 实现之间冲突 | `ACCEPTED` | Spec 3.1/15.4；矩阵 FR-SAFE-001；DR-025 | Stage 0 必须实现并验收，Stage 1 只校准质量 |
| RV-05 | High | Voice paused/revoked/delete 混用，任意文本合成可进入 Beta | `ACCEPTED` | Spec 11.6、13.2、17.2；DR-037 | provider 水印/TTL 与真实删除仍是外部门 |
| RV-06 | High | WTMR/GHR 可被 onboarding 自循环和选择性分母美化 | `ACCEPTED` | Spec 6、18.4；DR-019/DR-032/DR-039 | 目标值等待服务端事件和两个观测周 |
| RV-07 | High | Visitor Message/IP/device 没有 TTL、可见性和删除规则 | `ACCEPTED` | Spec 13.2、15.5；DR-038 | TTL 数值和举报 hold 由 Stage 3 决策关闭 |
| RV-08 | High | FR 主阶段与矩阵复合阶段不一致 | `ACCEPTED` | 矩阵第 5 节改为单一主交付阶段，决策/外部门独立 | Round 4 为每个任务补最终完成阶段和依赖 |
| RV-09 | Medium | 实现成熟度、外部门、决策和暴露混成一轴 | `ACCEPTED` | 矩阵第 1/5 节四轴模型与 36 行重构 | 复合 release readiness 由 Round 5 清单计算 |
| RV-10 | Medium | Round 1 基线和退出门不可完全复现 | `PARTIALLY_ACCEPTED` | 矩阵 2.1/8 补 commit、dirty、执行状态和 PASS/PARTIAL | 每 FR 的测试/部署 artifact 仍由 Round 4/5 补齐 |

## 7. 最终工程一致性 reviewer 响应

| Review ID | 严重度 | 异议 | 响应 | 规范落点 | 残余项 |
| --- | --- | --- | --- | --- | --- |
| RV-11 | Blocker | KBLite/snapshot 的 legacy confirmed 无安全 authority 迁移规则 | `ACCEPTED` | Spec 20.1/20.2；DR-034 | Round 3 定义 inventory/schema/epoch 与迁移 smoke |
| RV-12 | High | UsageGrant 无 authority、签发和 data-rights 例外 | `ACCEPTED` | Spec 12.1 至 12.4；DR-035 | 目标 policy schema/API 在 Round 3 |
| RV-13 | High | Voice consent 混在资产状态，重录/失败/删除路径不完整 | `ACCEPTED` | Spec 11.6、13.2、17.1/17.2；DR-037 | provider-specific operation mapping 在 Round 3/Voice Beta |
| RV-14 | High | 30 日恢复与立即删除 DAG 冲突 | `ACCEPTED` | Spec 11.8、13.2；DR-011 | 恢复期限仍需产品确认，状态机支持 0 或 30 日 |
| RV-15 | Medium | client request 可伪造 principal、server time、policy version | `ACCEPTED` | Spec 11.7 拆 ClientRequest/ServerCommandContext | Round 3 typed API 必须禁止同名信任 |
| RV-16 | Medium | SLO 缺 endpoint、负载、样本、窗口和分母 | `ACCEPTED` | Spec 18.4；DR-039 | 具体 target 在基线报告后调整 |
| RV-17 | Medium | FR-PRIV-001 iOS maturity 偏高 | `ACCEPTED` | 矩阵 FR-PRIV-001 改 `PARTIAL` 且注明仅 Knowledge/Echo scope | 账号切换/登出全业务清理进入 Stage 0 路线 |
| RV-18 | High | Owner 自访问始终要求 AccessGrant，但没有签发规则 | `ACCEPTED` | Spec 12.2/12.4：Owner 由 resource ownership 授权，AccessGrant 仅用于非 Owner 委托 | Round 3 policy test 覆盖 Owner 与 delegated principal 分支 |
| RV-19 | High | FR-PRIV-004 主阶段仍混合 Stage 0 决策和 Stage 1 交付 | `ACCEPTED` | Spec 第 4 节与矩阵均改为 Stage 1 主交付，DR-005 保留 Stage 0 决策门 | Round 4 在依赖图中表达 Gate，不再改主阶段 |

## 8. Round 2 最终响应结论

- 两名最终 reviewer 及定向复核共提出 3 个 blocker、11 个 high 和 5 个 medium；3 个 blocker 和 11 个 high 均已在 Product Spec/登记册/矩阵中关闭。
- High/Medium 的产品合同矛盾均已修正；仍需实现或外部确认的内容有明确 Decision ID、Stage gate 或 Round 3 设计任务。
- Round 3 只获准进行推荐架构、ADR 备选和可逆迁移设计，不代表未决产品项已批准，也不允许直接执行生产迁移。
- 产品/安全 reviewer 定向复核：RV-01、RV-02 均关闭，Round 3 `PASS`。
- 工程一致性 reviewer 定向复核：legacy authority blocker 与准入前 High 均关闭，无剩余 Blocker/High，Round 3 `PASS`。
