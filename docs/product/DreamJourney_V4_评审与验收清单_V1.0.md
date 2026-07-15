# DreamJourney V4 评审与验收清单

版本：V1.2 Product Confirmed Staged Baseline + External Gates Open
日期：2026-07-15
状态：`PRODUCT_DECISIONS_SYNCED_IMPLEMENTATION_UNVERIFIED`
工程基线：iOS `feature/prd-stitch-ui-adaptation@8a1922b`；Backend `main@4c0538b`
边界：本文件已同步独立方案评审第21章产品回复、三级验证策略与 Startup Lean Profile；不证明115个Work Item已实现，不关闭G2-G4，不构成发布批准。

## 1. Authority 与使用规则

本文件是五份固定成果物中的验收控制面，只记录发现处置、进入/退出门、证据和当前未授权事项，不复制完整产品规格或115项路线正文。

1. 产品目标与架构：[Product Spec V4](./DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md)。
2. 当前工程事实：[当前实现证据矩阵](./DreamJourney_V4_当前实现证据矩阵_V1.0.md)。
3. 产品决定与外部门：[产品决策登记册](./DreamJourney_V4_产品决策登记册_V1.0.md)。
4. 工程执行顺序：[V4可执行开发路线图](../superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md)。
5. 双向覆盖：[路线追踪矩阵](./DreamJourney_V4_路线追踪矩阵_V1.0.md)与[路线执行注册表](./DreamJourney_V4_路线执行注册表_V1.0.json)。

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
| Current package status | `PRODUCT_DECISIONS_SYNCED_IMPLEMENTATION_UNVERIFIED` |

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
| `STOP-R5-04` | C05 V1范围与当前ReleasePolicy | `STOP` | V4为唯一范围Authority；R3仅可按Closed Pilot开放；Family/Publication/Voice 属Product MVP并须各自server gate与证据；DH/媒体/Care/TimeLetter default-off；offline deny |

## 5. Gate Evidence Checklist

| Gate | 可关闭内容 | 最低证据 | 不可推导 |
|---|---|---|---|
| G0 | 代码、schema/contract、静态规则 | unit/contract/static、generic build、negative fixture、diff | 真实DB、Provider、设备、产品/法律批准 |
| G1 | 模拟器/UIQA/release暴露 | simulator smoke、截图、交互日志、fresh/upgrade/offline policy | 真机权限、真实Provider质量、生产隔离 |
| G2 | 部署/Postgres/迁移/恢复 | versioned migration、concurrency、restore、readiness、deployed smoke、观察窗 | Provider、真机、产品/法律 |
| G3 | Provider能力与退出 | scoped credential、quota/region、quality/cost、delete/exit receipt、故障注入 | 真机听感、产品/法律同意 |
| G4 | 真机/产品/Privacy/Legal/Commercial | 设备证据、产品签字、法律/隐私/运营批准、真实用户/合同 | 不能由G0-G3自动关闭 |

### 5.1 后端 Projection/Retrieval DFX 门

以下验收指向 Product Spec 18.2A 的完整指标合同，不包含 ASR/TTS/Voice Clone/Digital Human 等第三方执行时间：

- 基准负载：10 QPS 连续30分钟；1秒内100并发突发；明确每个 Vault 的 MemoryVersion/Source/relation 数据规模与冷/热缓存。
- 延迟：`T_retrieval` 稳态 p95 <= 600ms、p99 <= 1,000ms；100并发突发 p95 <= 1,500ms、p99 <= 2,500ms；各 stage 必须独立上报。
- 正确性：跨 Vault 泄漏、未授权候选、已删除/撤权 Source、错误 citation、重复/丢失 relation 扩展均为0；无来源回答不得伪装确定事实。
- 可用性与容量：10 QPS完成率、queue/in-flight/连接池/lock、timeout/cancel/retry、Context Packet <= 256KB、过载确定性拒绝或裁剪均有证据。
- 新鲜度与恢复：Projection lag p95 <= 2s、p99 <= 10s；projector可从 Memory event 从零重建；checkpoint/重复/乱序/故障恢复通过。
- 安全、隐私、可观测性、可维护性和成本：分别记录授权拒绝、最小日志、trace关联、回归<=10%、DB/CPU/内存/存储增长；每份报告携带 build/env/region/规格/负载/样本/窗口/分母/冷启动/排除项和 artifact hash。

这些是 DR-039 已确认的研发基线，不是当前实测通过；缺生产等价压测报告时 G2 仍保持开放。

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
| `WP-S3-01` | `EXTERNAL_BLOCKED` | Family委托、public snapshot/index/grant/7日TTL/withdraw、Privacy/Security G4 | 产品范围已确认；证据前 default-off，不得公开 |
| `WP-V0-01` | `EXTERNAL_BLOCKED` | Voice purpose/provider/delete/exit/quality/真机 G3/G4；DH 独立证据 | Voice为MVP、DH为Beta；证据前对应能力 default-off |
| `WP-MIG-01` | `PLANNED` | L0 inventory/restore、L1离线演练、L2维护窗go/no-go、L3观察；规模触发后完整C门 | 当前执行Lean；只拥有迁移证据，不拥有业务状态 |

## 8. 决策与外部门

- 2026-07-15 已确认三 Tab、手机号、Family、受控 Publication/Visitor、Voice Product MVP、DH Beta Extension、删除/TTL、WTMR/DFX、三级验证和 Startup Lean Profile；这些决定可以进入实现，但不能替代适用 G2-G4。
- Closed Pilot 只需关闭自身的身份、Vault隔离、文字Authority、来源引用、纠正、删除、受控cohort和适用G1/G2/G4证据；Family/Publication/Visitor/Voice不作为其退出依赖。
- Product MVP 只有在Closed Pilot通过且Family/Publication/Visitor/Voice各自适用门关闭后才可发布；Beta Extension不参与Product MVP退出。
- 只有`CONFIRMED` Decision可形成产品范围批准；`RECOMMENDED_PENDING`只能支持可逆设计、mock、shadow或fail-closed。
- `DECISION_REQUIRED`必须记录Owner、批准人、范围、依据和失效条件。
- `EXTERNAL_REQUIRED`必须记录环境、Provider/法律/合同/设备证据、时间和可复验标识。
- Identity 产品形态、Visitor 范围、Voice 层级和指标已确认；地域/processor、Provider 条款、未成年人/第三方/逝者高风险用途、DR-035 和真实实现证据仍不得被产品确认替代。
- P0安全默认可以先执行风险收缩；产品确认项仍需真实实现与外部门后才可公开。

## 9. 发布、Rollback 与 Exit

### 9.1 发布前

- 当前selector只能给出`PLAN_ASSIGN_OWNER:WI-S0-03-01`，不构成执行授权。
- Work Item进入`IN_PROGRESS`前必须有GO、Owner、同Owner持有的HELD authority lease、依赖和适用Gate证据。
- 任一P0 STOP、open incident、expired evidence、决策/依赖变化都会触发replan。
- Closed Pilot、Product MVP、Beta Extension 使用独立 ReleasePolicy audience/cohort；Family/Publication/Voice 在未通过自身 Gate 前默认关闭；DH/非必要媒体/Care/TimeLetter 默认关闭；离线和 policy 过期均 deny。

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
- 产品范围已授权R3文字核心进入受控Closed Pilot，Family、受控Publication/Visitor与Voice进入Product MVP，Digital Human和非必要媒体进入Beta Extension；但在各自当前实现和适用G1-G4证据缺失时，仍不授权向真实用户开放对应能力，也不授权Care/TimeLetter。
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
- [2026-07-15 产品决策同步与静态验收报告](../DreamJourney_V4_成果物_2026-07-15/05-交付记录/DreamJourney_V4_2026-07-15_产品决策同步与静态验收报告.md)

## 13. Round 5C 新发现处置

| Finding | Sev | Disposition | Document status | Underlying status | Authority / Gate | Verification |
|---|---|---|---|---|---|---|
| `R5C-PROD-001` | P2 | `FIXED` | `CLOSED` | `PRODUCT_DECISIONS_SYNCED_IMPLEMENTATION_UNVERIFIED` | 五份核心成果物 / 2026-07-15 同步验收 | Product Spec、Evidence Matrix、Decision Register、Roadmap 均反向链接本清单；状态、代码基线和不过度声明边界一致。 |

该修复只关闭文档互链问题。`R5A-ENG-008` 的 clean-checkout artifact 证据仍为 `ARTIFACT_COMMIT_REQUIRED`，不因本处置自动关闭。

## 14. 2026-07-15 产品回复同步结论

1. 产品范围已关闭：三 Tab、手机号、Closed Pilot文字核心、Product MVP的Family/人物切换/受控Publication/Visitor/Voice Clone、Beta Extension的Digital Human与非必要媒体、Care/TimeLetter后置。
2. 数据与体验规则已关闭：引导问答、每5–10轮或退出批量确认、30日账号恢复、上传人 Source 不可撤回删除、Visitor TTL 7日、Owner不见家庭/Visitor问答正文。
3. 指标与执行档位已关闭：WTMR、Projection/Retrieval DFX、百级用户 Startup Lean Profile。
4. 外部门未关闭：未成年人/第三方/逝者高风险用途、地域/processor、Provider禁训练/留存/删除、真实成本、G2部署、G3 Provider与G4真机/法律。
5. 当前公开发布结论仍为 `NO_GO`：原因是实现和外部证据不足，不再是产品范围未决；Closed Pilot也只有在自身适用门取得真实证据后才能转为受控 `GO`。
