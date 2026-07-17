# DreamJourney V4 评审与验收清单

版本：V1.4 M0 Guided Interview Baseline + External Gates Open
日期：2026-07-16
状态：`REGULATORY_AND_GUIDED_INTERVIEW_BASELINE_SYNCED_IMPLEMENTATION_UNVERIFIED`
工程基线：iOS `feature/prd-stitch-ui-adaptation@8a1922b`；Backend `main@4c0538b`
边界：本文件已同步新规生效后的产品风险方案、M0-M4、引导式访谈与 Startup Lean Profile；不证明115个Work Item已实现，不关闭G2-G4、安全评估、算法备案或监管发布门，不构成发布批准。

## 1. Authority 与使用规则

本文件是五份固定成果物中的验收控制面，只记录发现处置、进入/退出门、证据和当前未授权事项，不复制完整产品规格或115项路线正文。

1. 产品目标与架构：[Product Spec V4](./DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md)。
2. 引导式访谈专项合同：[引导式访谈与知识丰满化功能说明](./DreamJourney_V4_引导式访谈与知识丰满化功能说明_V1.0.md)。
3. 当前工程事实：[当前实现证据矩阵](./DreamJourney_V4_当前实现证据矩阵_V1.0.md)。
4. 产品决定与外部门：[产品决策登记册](./DreamJourney_V4_产品决策登记册_V1.0.md)。
5. 工程执行顺序：[V4可执行开发路线图](../superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md)。
6. 双向覆盖：[路线追踪矩阵](./DreamJourney_V4_路线追踪矩阵_V1.0.md)与[路线执行注册表](./DreamJourney_V4_路线执行注册表_V1.0.json)。

处置状态只表示审查意见如何进入Authority：

- `FIXED`：成果物中的矛盾已修正或已由现有明确Authority消除。
- `ACCEPTED`：发现成立，已绑定Work Item/Gate/STOP；不表示实现完成。
- `DECISION_REQUIRED`：只能由有权产品/合规/商业Owner关闭。
- `EXTERNAL_REQUIRED`：只能由真实Provider、生产、法律或真机证据关闭。
- `REJECTED_WITH_REASON`：证据不足或与更高Authority冲突，必须保留理由。

双状态规则：`Document status=CLOSED*`只表示评审处置完整；`Underlying status`才表示底层事实。本清单禁止把`OPEN_BLOCKER/PLANNED/EXTERNAL_BLOCKED/DECISION_OPEN/ARTIFACT_COMMIT_REQUIRED`解释为`IMPLEMENTED/VERIFIED`。

## 2. 当前基线与精确覆盖

| Control | Baseline |
|---|---|
| iOS | `feature/prd-stitch-ui-adaptation@8a1922b` |
| Backend | `main@4c0538b` |
| Functional Requirements | 36 |
| Decision Records | 43 |
| Round 3 Findings | 22 |
| Canonical Risks | 12 |
| Work Packages | 13 |
| Work Items | 115 |
| Work Item fields | 1840 |
| Round 5A raw findings | 23（P0=7 / P1=15 / P2=1） |
| Cross-review clusters | 13 |
| Round 4 status | `ROUND4_STATIC_ACCEPTANCE_PASSED_ROUND5_PENDING` |
| Round 5C validation | expected=22 / covered=22 / `VERIFIED=22` / `CHALLENGED=0` |
| Product decision sync | 30 `CONFIRMED` / 7 `EXTERNAL_REQUIRED` / 3 `REJECTED` / 2 `RECOMMENDED_PENDING` / 1 `DEFERRED` |
| Current package status | `REGULATORY_AND_GUIDED_INTERVIEW_BASELINE_SYNCED_IMPLEMENTATION_UNVERIFIED` |

当前实现成熟度和开放外部门不得由本清单改写。特别是：产品 `CONFIRMED` 只允许进入实现，不代表代码存在或真实开放；`RECOMMENDED_PENDING/EXTERNAL_REQUIRED`不等于批准；G0/G1不关闭G2-G4。

## 3. Round 5A Finding Disposition

### 3.1 精确处置表

| Finding | Sev | Cluster | Disposition | Document status | Underlying status | Authority / Gate | Verification |
|---|---|---|---|---|---|---|---|
| `R5A-PROD-001` | P0 | C04 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S1-01` / G2 | Source→Candidate→Decision→MemoryVersion→Citation回放 |
| `R5A-PROD-002` | P0 | C01 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-02`、`WP-S0-03` / G2、G4 | 强身份、跨Vault corpus、client secret为0 |
| `R5A-PROD-003` | P0 | C05 | `FIXED` | `CLOSED` | `PLANNED` | Product Spec §0.2；`WP-S0-06` / G1 | 发布清单只引用V4 Stage Gate，不引用V1“完整MVP” |
| `R5A-PROD-004` | P1 | C06 | `ACCEPTED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` | `WP-S3-01` / G2、G4 | private role deny、grant撤销、Public Index清除 |
| `R5A-PROD-005` | P1 | C07 | `ACCEPTED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` | `WP-V0-01` / G3、G4 | purpose、删除receipt、真机、成本与退出 |
| `R5A-PROD-006` | P1 | C11 | `FIXED` | `CLOSED_WITH_EXTERNAL_GATES` | `PRODUCT_CONFIRMED_IMPLEMENTATION_OPEN` | DR-001..043 的 Owner/Gate | 2026-07-15 产品证据已登记；外部门、实现、适用范围和失效条件继续逐项验收 |
| `R5A-PROD-007` | P1 | C12 | `FIXED` | `CLOSED` | `METRIC_IMPLEMENTATION_OPEN` | DR-019/032/039；`WP-S0-07` / G2 | WTMR/DFX 已确认；仍需服务端事件、receipt对账与真实 cohort 基线 |
| `R5A-ENG-001` | P0 | C01 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-02` / G2、G4 | 无token/跨账号/未分类route/异常均401或403 |
| `R5A-ENG-002` | P0 | C02 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-03` / G0、G3 | Release artifact/header/log/network secret scan |
| `R5A-ENG-003` | P1 | C03 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-01`、`WP-S0-05` / G1、G2 | A/B切换、logout/delete、crash/relaunch矩阵 |
| `R5A-ENG-004` | P1 | C02 | `ACCEPTED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` | `WP-S0-03`、`WP-V0-01` / G3 | per-session credential TTL/replay/close与撤销 |
| `R5A-ENG-005` | P1 | C08 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S1-02` / G2 | crash replay、duplicate worker、Inbox唯一性 |
| `R5A-ENG-006` | P1 | C09 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-04`、`WP-MIG-01` / G2 | versioned migration、isolated restore、rollback drill |
| `R5A-ENG-007` | P1 | C04 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S1-01` / G2 | correction/delete/stale projection/cross-account citation |
| `R5A-ENG-008` | P2 | C13 | `ACCEPTED` | `CLOSED` | `ARTIFACT_COMMIT_REQUIRED` | Roadmap/QA Governance / G0 | clean checkout可重生成Registry/Trace且hash一致 |
| `R5A-RISK-001` | P0 | C01 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-02` / G2、G4 | deny-by-default route/object/system scope corpus |
| `R5A-RISK-002` | P0 | C02 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-03` / G0、G3 | client/provider credential inventory、rotation、replay deny |
| `R5A-RISK-003` | P1 | C03 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-01`、`WP-S0-05` / G1、G2 | logout/delete/cache/export/notification owner隔离 |
| `R5A-RISK-004` | P1 | C05 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-06` / G1、G2 | fresh install/upgrade/offline/TTL/cohort default-off |
| `R5A-RISK-005` | P1 | C08 | `ACCEPTED` | `CLOSED_WITH_EXTERNAL_GATE` | `OPEN_BLOCKER` | `WP-S1-02` / G2、G3、G4 | outbox/receipt/reconcile/APNs arrival corpus |
| `R5A-RISK-006` | P1 | C09 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` | `WP-S0-04` / G2 | pool/UoW/readiness/migration/restore/RPO-RTO |
| `R5A-RISK-007` | P1 | C10 | `EXTERNAL_REQUIRED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` | `WP-S0-04`、`WP-S0-05`、`WP-S1-02` / G2、G3 | object HEAD/checksum/scan/delete/restore/region/SLA |
| `R5A-RISK-008` | P1 | C07 | `EXTERNAL_REQUIRED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` | `WP-V0-01` / G3、G4 | purpose/crisis corpus/provider delete/exit/真机/cost |

### 3.2 处置统计

- Raw findings：23/23。
- `FIXED`：3。
- `ACCEPTED`：18。
- `DECISION_REQUIRED`：0。
- `EXTERNAL_REQUIRED`：2。
- `REJECTED_WITH_REASON`：0。
- P0 document disposition：7/7 closed。
- P0 underlying implementation：0/7 complete；全部保持`OPEN_BLOCKER`或`PLANNED`。

## 4. P0 Release Stop

以下是去重后的P0发布阻断。除非Authority/Gate提供真实证据，否则任何客户端、后端、文档或发布材料不得将对应能力标记为完成。

| Stop ID | Issue cluster | Current decision | Required exit evidence |
|---|---|---|---|
| `STOP-R5-01` | C01 Identity/AuthZ | `STOP` | 强身份、server-derived owner、全路由/对象deny、跨Vault G2、G4身份决定 |
| `STOP-R5-02` | C02 Client/Provider credential | `STOP` | Release无system/provider长期secret、旧credential撤销、broker/TTL/replay G3 |
| `STOP-R5-03` | C04 Owner Truth | `STOP` | 单Authority Source→Candidate→Decision→MemoryVersion→Projection与G2回放 |
| `STOP-R5-04` | C05 旧范围与当前ReleasePolicy | `STOP` | V4.4为唯一范围Authority；R3仅按M0开放；M1-M4各自server gate与证据；未成年人虚拟亲属、无生前专项授权逝者Voice/DH硬拒绝；offline deny |
| `STOP-REG-01` | 未成年人虚拟亲属 | `STOP` | 服务端按年龄+角色实质拒绝父母/祖辈/兄弟姐妹/伴侣等虚拟亲属；改名、监护人同意或客户端隐藏都不能放行 |
| `STOP-REG-02` | 非本人或不合格 Voice 训练 | `STOP` | M1仅在世成年人subject=actor；随机授权语句、活体和质量通过；Family代录、第三方、未成年人、逝者请求Provider effect=0 |
| `STOP-REG-03` | M2/M3 拟人化互动安全控制 | `STOP` | 成年/联系人、持续AI标识、依赖与2小时提醒、UI/语音/关键词退出、危机切换、投诉和人格化促购/重大决策阻断全部通过 |
| `STOP-REG-04` | 监管发布程序 | `STOP` | 适用安全评估报告、算法备案/变更、年度核验计划和应用商店合规包均有有效证据 |
| `STOP-REG-05` | 私人/敏感数据通用训练 | `STOP` | 平台和Provider默认禁训练；任何例外具备具体目的、单独同意、可拒绝与可审计训练数据清单 |
| `STOP-REG-06` | M0 数据控制与迁移 | `STOP` | 本人交互/资料/确认记忆/自传可复制、可读导出、可机读清单和删除；第三方裁剪与缺失披露可验证 |
| `STOP-GIC-01` | 引导式访谈被简化为推荐卡片或旁路事实库 | `STOP` | 一个自然入口；最多一条连续性和一条完整性推荐；单轮一个主要问题；跳过/暂缓/禁问；敏感与跨Vault阻断；Orchestrator不写MemoryVersion；GIC验收集通过 |

## 5. Gate Evidence Checklist

| Gate | 可关闭内容 | 最低证据 | 不可推导 |
|---|---|---|---|
| G0 | 代码、schema/contract、静态规则 | unit/contract/static、generic build、negative fixture、diff | 真实DB、Provider、设备、产品/法律批准 |
| G1 | 模拟器/UIQA/release暴露 | simulator smoke、截图、交互日志、fresh/upgrade/offline policy | 真机权限、真实Provider质量、生产隔离 |
| G2 | 部署/Postgres/迁移/恢复 | versioned migration、concurrency、restore、readiness、deployed smoke、观察窗 | Provider、真机、产品/法律 |
| G3 | Provider能力与退出 | scoped credential、quota/region、quality/cost、delete/exit receipt、故障注入 | 真机听感、产品/法律同意 |
| G4 | 真机/产品/Privacy/Legal/Regulatory/Commercial | 设备证据、产品签字、法律/隐私/运营批准、安全评估、算法备案、上架材料、真实用户/合同 | 不能由G0-G3自动关闭 |

### 5.1 后端 Projection/Retrieval DFX 门

以下验收指向 Product Spec 18.2A 的完整指标合同，不包含 ASR/TTS/Voice Clone/Digital Human 等第三方执行时间：

- 基准负载：10 QPS 连续30分钟；1秒内100并发突发；明确每个 Vault 的 MemoryVersion/Source/relation 数据规模与冷/热缓存。
- 延迟：`T_retrieval` 稳态 p95 <= 600ms、p99 <= 1,000ms；100并发突发 p95 <= 1,500ms、p99 <= 2,500ms；各 stage 必须独立上报。
- 正确性：跨 Vault 泄漏、未授权候选、已删除/撤权 Source、错误 citation、重复/丢失 relation 扩展均为0；无来源回答不得伪装确定事实。
- 可用性与容量：10 QPS完成率、queue/in-flight/连接池/lock、timeout/cancel/retry、Context Packet <= 256KB、过载确定性拒绝或裁剪均有证据。
- 新鲜度与恢复：Projection lag p95 <= 2s、p99 <= 10s；projector可从 Memory event 从零重建；checkpoint/重复/乱序/故障恢复通过。
- 安全、隐私、可观测性、可维护性和成本：分别记录授权拒绝、最小日志、trace关联、回归<=10%、DB/CPU/内存/存储增长；每份报告携带 build/env/region/规格/负载/样本/窗口/分母/冷启动/排除项和 artifact hash。

这些是 DR-039 已确认的研发基线，不是当前实测通过；缺生产等价压测报告时 G2 仍保持开放。

### 5.2 M0-M4 产品与监管 Gate

| 阶段 | 必须为 PASS | 任一失败时 |
| --- | --- | --- |
| M0 | 强身份/Vault隔离、Source→Memory→Citation、一个自然入口与连续性/完整性双推荐、访谈用户控制、静态纪念非第一人称陪伴、Family贡献AuthZ、复制/导出/删除、通用训练默认禁用、未成年人虚拟亲属硬拒绝 | M0 `NO_GO` |
| M1 | 在世成年人subject=actor、随机授权语句、活体/质量、独立同意、持续AI标识、受限文本、不可下载、Provider删除回执和真机 | Voice `NO_GO`；M0继续 |
| M2 | 在世主体主动发布、独立Publication/Index/读取角色、成年Visitor、联系人、依赖/2小时提醒、三通道退出、危机中性助手、投诉、人格化促购/重大决策阻断、安全评估、算法备案和上架材料 | Publication/Visitor/DH `NO_GO`；M0/M1继续 |
| M3 | 老人本人健康授权与无诊断；或成人纪念逐案生前授权/素材权利/近亲属争议/法律伦理/Provider/紧急下线全部通过 | 对应试点 `NO_GO`；前序阶段继续 |
| M4 | 权利目录、授权合同、受益人、计量结算、争议和无代理权声明 | 知识许可/收益 `NO_GO` |

监管证据必须记录法域、适用性结论、提交/备案编号、版本、有效期、负责人和原始 artifact hash。文档提到相关制度、代码存在安全分支或产品负责人签字，都不能单独关闭安全评估和算法备案门。

### 5.3 M0 引导式访谈 Gate

完整验收采用[引导式访谈与知识丰满化功能说明](./DreamJourney_V4_引导式访谈与知识丰满化功能说明_V1.0.md)中的 `GIC-001..016`。M0 至少必须保存以下证据：

- 入口与推荐：自然输入始终可用；任一时刻推荐不超过两条；两条分别可解释为连续性和完整性，没有候选时允许为空。
- 节奏与状态：每轮最多一个主要问题；同一线索2至4轮后总结；访谈深挖计数与5至10轮 Candidate 批次计数独立；用户换话题后不被强行拉回。
- 用户边界：“这次跳过、以后再聊、不再问”具有不同持久化语义；`do_not_ask` 主动推荐与追问命中数必须为0。
- 权威边界：推荐依据能回放到有权访问的 MemoryVersion、用户保存的待续线索或冷启动 Blueprint；未确认 Candidate 不提高已确认覆盖；Orchestrator 创建/修改 MemoryVersion 的次数必须为0。
- 安全与隐私：未经近期主动许可的创伤、丧亲、疾病和家庭冲突推荐数为0；跨Vault、撤权、删除、争议、禁问和仅由AI推断的候选全部在展示前阻断。
- 体验验证：不得以持续增长的主题目录代替自然输入；不得显示伪精确人生完成百分比；至少以受控用户研究验证问题自然度、跳过可理解性和长期推荐不重复。

只有静态 UI 截图、推荐点击率或一段模型演示不能关闭 `STOP-GIC-01`。工程需同时提供状态持久化、策略负向测试、Authority 回放和 G1/G2 证据。

## 6. 不可逆与高代价操作

执行前必须存在Authority、双人或指定Owner批准、receipt与rollback/compensation边界：

| Operation | Required authority | Precondition | Postcondition / receipt | Failure boundary |
|---|---|---|---|---|
| 强身份绑定/账号合并 | Identity/AuthZ | 可证明challenge、冲突检测、旧session revoke | binding/session/revoke receipt | 不自动认领legacy owner |
| 数据purge与账号清理 | Rights/Deletion | access先撤、对象清单、retention/backup/provider策略 | 分层delete/unsupported/partial/completed receipt | 不用本地tombstone宣称全删 |
| Publication公开/索引 | Publication | 独立snapshot、grant、Privacy/Product G4 | publish/index/grant receipt | private Projection永不直读；可撤回 |
| Voice训练/删除/公开使用 | Voice Governance | purpose、本人证明、profile/sample版本、Provider G3/G4 | train/delete/asset/consent receipt | 删除或pause后deny；无fallback冒充 |
| Authority cutover | Migration Evidence | shadow compare、backup/restore、go/no-go、held lock | epoch/cutover/rollback/retirement manifest | 不可逆外部effect走compensation/reconcile |
| Credential rotation/revoke | Credential Authority | inventory、Owner、blast radius、broker兼容 | revoke/rotate/scan receipt | 旧credential不能因客户端兼容继续有效 |

## 7. 13 Package Acceptance Summary

| Package | Current state | Required evidence before VERIFIED | Current authorization |
|---|---|---|---|
| `WP-S0-01` | `PLANNED` | AccountLease、owner store、A/B/logout/delete G1/G2 | 不授权执行；先分配Owner/lock |
| `WP-S0-02` | `PLANNED` | 强身份、全route/object deny、cross-vault G2、G4 | `STOP-R5-01` |
| `WP-S0-03` | `PLANNED` | inventory、secret scan、rotation/revoke、G3 broker | `STOP-R5-02` |
| `WP-S0-04` | `PLANNED` | UoW/pool、migration head、readiness、restore G2 | 不授权cutover |
| `WP-S0-05` | `PLANNED` | 分层rights/delete/provider/backup receipt G2-G4 | 不授权purge完成声明 |
| `WP-S0-06` | `PLANNED` | server ReleasePolicy、default-off、G1/G2 | `STOP-R5-04` |
| `WP-S0-07` | `PLANNED` | operation/incident/rights/cost事件与真实分母 G2 | 不授权指标达标声明 |
| `WP-S1-01` | `PLANNED` | Owner Truth单Authority、projection/citation/correction G2 | `STOP-R5-03` |
| `WP-S1-02` | `PLANNED` | outbox/job/inbox/unknown reconcile、crash corpus G2/G3 | 不授权delivered完成声明 |
| `WP-S1-03` | `PLANNED` | composition/lease/runtime/audio owner G0/G1/G4 | 不授权Voice真机完成 |
| `WP-S3-01` | `EXTERNAL_BLOCKED` | M0 Family静态贡献；M2在世发布主体、独立snapshot/index/role、成年grant/7日TTL、依赖/退出/危机、withdraw、评估/备案 G2/G4 | M0静态切片与M2互动分开；证据前M2 default-off |
| `WP-V0-01` | `EXTERNAL_BLOCKED` | M1在世本人Voice；M2在世DH；M3成人纪念逐案，各自purpose/provider/delete/exit/quality/真机/监管 G3/G4 | 未成年人/Family代录/无授权逝者硬拒绝；其余证据前 default-off |
| `WP-MIG-01` | `PLANNED` | L0 inventory/restore、L1离线演练、L2维护窗go/no-go、L3观察；规模触发后完整C门 | 当前执行Lean；只拥有迁移证据，不拥有业务状态 |

## 8. 决策与外部门

- 2026-07-16 已确认三Tab、手机号、M0-M4、静态Family、M1本人Voice、M2成年Publication/Visitor/在世DH、M3受监管试点、复制/导出/删除、WTMR/DFX和Startup Lean Profile；这些决定不能替代适用G2-G4。
- M0 关闭身份、Vault隔离、文字Authority、静态纪念、来源引用、纠正、复制/导出/删除和受控cohort；M1-M4不作为其退出依赖。
- M1-M4 只有在前序必要能力和各自实现、Provider、法律、监管与真机门关闭后才可发布；后续阶段失败不撤销已验证前序阶段。
- 只有`CONFIRMED` Decision可形成产品范围批准；`RECOMMENDED_PENDING`只能支持可逆设计、mock、shadow或fail-closed。
- `DECISION_REQUIRED`必须记录Owner、批准人、范围、依据和失效条件。
- `EXTERNAL_REQUIRED`必须记录环境、Provider/法律/合同/设备证据、时间和可复验标识。
- Identity 产品形态、成年Visitor范围、M1-M3 Voice/DH层级和指标已确认；地域/processor、Provider条款、未成年人静态资料、第三方/逝者高风险用途、监管程序、DR-035和真实实现证据仍不得被产品确认替代。
- P0安全默认可以先执行风险收缩；产品确认项仍需真实实现与外部门后才可公开。

## 9. 发布、Rollback 与 Exit

### 9.1 发布前

- 当前selector只能给出`PLAN_ASSIGN_OWNER:WI-S0-03-01`，不构成执行授权。
- Work Item进入`IN_PROGRESS`前必须有GO、Owner、同Owner持有的HELD authority lease、依赖和适用Gate证据。
- 任一P0 STOP、open incident、expired evidence、决策/依赖变化都会触发replan。
- M0-M4 使用独立 ReleasePolicy audience/cohort；M1-M4在未通过自身Gate前默认关闭；未成年人虚拟亲属、Family代录与无生前专项授权逝者复刻永久deny；离线和policy过期均deny。

### 9.2 Rollback

- Pre-cutover可回滚代码、flag、worker和兼容读写。
- Post-cutover不得把新业务Authority切回legacy；使用forward-fix、compat read、pause、reconcile和明确epoch。
- 已发送通知、Provider训练/删除/收费、公开索引等不可逆effect只能compensate/reconcile，不能伪装事务回滚。

### 9.3 Exit / Retirement

- Provider exit要求资产清单、portability/替代策略、credential revoke、对象/模型删除receipt和成本终止证明。
- Legacy retirement要求零读写观察窗、contract/revoke证据、retirement manifest和恢复边界。
- 产品能力退出仍需保留用户数据权利、审计与必要兼容读，不以隐藏入口替代删除/撤权。

## 10. 当前未授权事项

- 不授权把115个Work Item标记为实现或Verified。
- 不授权把Owner Truth、Source/Candidate/MemoryVersion写成当前生产Authority。
- 产品范围允许R3文字核心、静态Family与复制/导出进入受控M0；M1本人Voice、M2成年Publication/Visitor/在世DH、M3健康/成人纪念和M4许可分别过门。在当前实现和适用G1-G4/监管证据缺失时，不授权向真实用户开放对应能力，也不授权Care/TimeLetter。
- 不授权客户端持有system token或长期Provider credential。
- 不授权把mock upload、local tombstone、`delivered`字段或runtime capability解释为真实Provider/删除/投递完成。
- 不授权使用V1 PRD的“完整MVP/P0”口径覆盖V4 Stage Gate。
- 不授权声称WTMR/A72/R28/GHR、SLO、RPO/RTO、Provider成本或质量已达标。

## 11. Round 5C 验证结论与 Round 5D 状态

- 三份 Round 5A 原始报告与 23 条 disposition 可读，第一轮 P0 文档处置 7/7；底层实现 0/7 被标记完成。
- 三位第二轮审查者使用新上下文且未读取 Round 5A 原始报告；产品 7/7、工程 7/7、风险 8/8，共 22/22 `VERIFIED`、0 `CHALLENGED`。
- 第二轮只新增 `R5C-PROD-001` P2；该互链问题已在 Round 5D 修复。
- Round 5 历史成果物曾统一为 `REVIEWED_BASELINE_PENDING_COMMIT`；2026-07-15 产品回复已在核心成果物形成增量基线，Trace/Registry 仍是派生视图且不改变工程成熟度。
- `R5A-ENG-008` 继续为 `ARTIFACT_COMMIT_REQUIRED`。提交与 clean-checkout 重生成前，不得升级为 artifact-complete。

## 12. Review Evidence

- [Round5A 产品独立复审](./reviews/DreamJourney_V4_Round5A_产品独立复审.md)
- [Round5A 工程独立复审](./reviews/DreamJourney_V4_Round5A_工程独立复审.md)
- [Round5A 安全隐私运维独立复审](./reviews/DreamJourney_V4_Round5A_安全隐私运维独立复审.md)
- [Round5A 独立复审索引](./reviews/DreamJourney_V4_Round5A_独立复审索引.md)
- [Round5C 产品盲审](./reviews/DreamJourney_V4_Round5C_产品盲审.md)
- [Round5C 工程盲审](./reviews/DreamJourney_V4_Round5C_工程盲审.md)
- [Round5C 风险盲审](./reviews/DreamJourney_V4_Round5C_风险盲审.md)
- [Round5C 盲审覆盖索引](./reviews/DreamJourney_V4_Round5C_盲审覆盖索引.md)
- [Round5D 最终静态验收报告](./reviews/DreamJourney_V4_Round5D_最终静态验收报告.md)
- [2026-07-15 独立方案评审与产品回复](./DreamJourney_V4_方案架构评审解读_独立方案评审_2026-07-15.md)
- [2026-07-15 产品决策同步与静态验收报告](../05-交付记录/DreamJourney_V4_2026-07-15_产品决策同步与静态验收报告.md)

## 13. Round 5C 新发现处置

| Finding | Sev | Disposition | Document status | Underlying status | Authority / Gate | Verification |
|---|---|---|---|---|---|---|
| `R5C-PROD-001` | P2 | `FIXED` | `CLOSED` | `PRODUCT_DECISIONS_SYNCED_IMPLEMENTATION_UNVERIFIED` | 五份核心成果物 / 2026-07-15 同步验收 | Product Spec、Evidence Matrix、Decision Register、Roadmap 均反向链接本清单；状态、代码基线和不过度声明边界一致。 |

该修复只关闭文档互链问题。`R5A-ENG-008` 的 clean-checkout artifact 证据仍为 `ARTIFACT_COMMIT_REQUIRED`，不因本处置自动关闭。

## 14. 2026-07-16 新规适配同步结论

1. 当前发布分层改为 M0-M4：M0 记忆资产验证；M1 在世成年人本人私有 Voice；M2 在世主体主动发布与成年 Visitor；M3 老人健康和成人纪念互动逐案试点；M4 知识许可与收益。旧三级名称仅保留为 Work Item 兼容标签。
2. M0 数据与体验规则已关闭：一个自然输入、连续性/完整性双推荐、单轮一个主要问题、跳过/暂缓/禁问、引导问答、每5–10轮或退出批量确认、30日账号恢复、上传人 Source 不可撤回删除、交互数据复制/可读导出/机器可读清单以及删除状态可见。
3. 指标与执行档位已关闭：WTMR、Projection/Retrieval DFX、百级用户 Startup Lean Profile。
4. 外部门未关闭：M2/M3 的主体与成年人核验、地域/processor、Provider禁训练/留存/删除、上线前安全评估、算法备案/年度核验、应用商店材料、G2部署、G3 Provider与G4真机/法律。
5. 未成年人虚拟亲属、未成年人 Voice/Persona、家庭代录、无生前专项授权逝者 Voice/DH、人格化促购和 Persona 参与重大现实决策为硬拒绝，不再作为“待外部审批即可开放”的候选。
6. 当前 M0 受控试点仍为 `NO_GO`，直到强身份/Vault隔离、数据复制/导出/删除、真实部署与恢复证据关闭；M1-M4 分别保持默认关闭，不阻塞 M0 工程验证。
7. 引导式访谈产品原则已确认，但当前实现证据为 `MISSING/PARTIAL`；在 `STOP-GIC-01` 关闭前，不得将静态问题卡、普通聊天记录或 KBLite 图谱宣传为“AI 已能系统丰满个人知识库”。
