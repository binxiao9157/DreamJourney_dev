# DreamJourney V4 Round 3 独立架构评审响应

版本：V1.0
日期：2026-07-12
状态：Round 3D disposition 完成；实现与外部门仍按矩阵状态执行
输入：[iOS独立评审](./DreamJourney_V4_Round3_iOS独立评审_V1.0.md) · [后端独立评审](./DreamJourney_V4_Round3_后端独立评审_V1.0.md) · [安全隐私运维独立评审](./DreamJourney_V4_Round3_安全隐私运维独立评审_V1.0.md)

## 1. Disposition 规则

| Disposition | 含义 |
| --- | --- |
| `ACCEPTED_SPEC_FIX` | 目标规范表达不足；本轮已修正文档，但生产代码仍不因此完成 |
| `ACCEPTED_IMPLEMENTATION_GAP` | 目标架构正确，当前实现缺口进入 Round 4 工作包 |
| `ACCEPTED_EXTERNAL_GATE` | 结论成立，但只能由产品/法律/合同/provider/生产/真机证据关闭 |
| `PARTIALLY_ACCEPTED` | 接受其中一部分；另一部分有当前源码或范围证据限制，必须写明 |
| `DUPLICATE` | 与 canonical finding 同根因；保留独立来源并指向同一工作包 |
| `REJECTED_WITH_EVIDENCE` | 不接受，必须给出当前源码或目标不变量反证 |

`DUPLICATE` 不删除原 ID；`ACCEPTED_SPEC_FIX` 不表示代码已修；任何生产、法律或 Provider 外部门都不能由本响应关闭。

## 2. Canonical Risks 与稳定工作包

| Risk | Canonical issue | Round 4 package | Stage / Gate |
| --- | --- | --- | --- |
| CR-01 | AccountSession、generation、owner-scoped local store与legacy auto-claim | `WP-S0-01 Account & Local Isolation` | Stage 0；账号A/B与logout/delete gate |
| CR-02 | Strong identity、server-derived principal、route/resource AuthZ与system scope | `WP-S0-02 Identity & AuthZ Enforce` | Stage 0；production deny-by-default |
| CR-03 | 客户端/system/provider长期credential与轮换/broker | `WP-S0-03 Credential Stop-Loss` | Stage 0 + Provider external gate |
| CR-04 | Postgres request UoW、versioned migration、readiness、backup/restore | `WP-S0-04 DB Foundation & Recovery` | Stage 0；真实Postgres/restore gate |
| CR-05 | owner-bound schema与Source→MemoryVersion→Projection单Authority | `WP-S1-01 Owner Truth Authority` | Stage 0 owner constraint；Stage 1 domain cutover |
| CR-06 | Transactional outbox、Inbox/business receipt和unknown effect | `WP-S1-02 Async Effect Authority` | 现有公开effect先止损；完整worker Stage 1/2 |
| CR-07 | iOS composition、Echo/Voice/DH runtime actor与UI解耦 | `WP-S1-03 iOS Composition & Runtime` | AccountLease后；不阻断文字核心 |
| CR-08 | Server ReleasePolicy、future default-off、Publication/Visitor独立域 | `WP-S0-06 Release Scope Stop-Loss` / `WP-S3-01 Publication` | Stage 0关闭误露；Stage 3才实现公开域 |
| CR-09 | 第三方/未成年人、Voice/DH purpose、Provider state/delete/exit | `WP-V0-01 Voice/DH Governance` | Voice Beta 0 + External gate |
| CR-10 | Rights、分层delete、receipt、restore与不可逆补偿 | `WP-S0-05 Rights & Deletion` | Stage 0；Privacy/Legal + provider/backup gate |
| CR-11 | operation/audit/incident、指标分母与Provider成本熔断 | `WP-S0-07 Operations Evidence` | Stage 0最小证据；增长目标可延后 |
| CR-12 | Composite migration、old-client/timer/credential retirement与DR | `WP-MIG-01 Composite Migration Drills` | C00-C11；C07/C10/C11前真实演练 |

Round 4 必须使用这些 package ID，或提供一一对应的重命名映射；不能把同一风险拆成互不知情的平行任务。

## 3. 22 项 Finding Disposition

| Finding | Severity | Disposition | Canonical risk | 判断与证据 | Spec / DR 落点 | Roadmap package | Owner / Gate |
| --- | --- | --- | --- | --- | --- | --- | --- |
| IAR-01 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-01 | UserManager/BackendAuthSessionStore只有局部锁和sessionId保护，没有统一AccountLease/generation CAS；目标29.1-29.3正确 | Spec 22.6、29.1-29.3、34.9 | WP-S0-01 | iOS + Security；A/B/switch/logout/crash |
| IAR-02 | BLOCKER | `ACCEPTED_IMPLEMENTATION_GAP` | CR-01 | Archive legacy auto-claim、`user_001`和DigitalHumanContext owner来源违反目标owner边界；不在文档层掩盖 | Spec 27.4、29.4、34.1；DR-041 | WP-S0-01 | iOS + Data/Privacy；owner mismatch quarantine |
| IAR-03 | BLOCKER | `ACCEPTED_IMPLEMENTATION_GAP` | CR-02 | iOS shared token/Bearer fallback和payload userId仍存在；目标server-derived principal正确 | Spec 25、30.1-30.6；DR-023/035 | WP-S0-02 + WP-S0-03 | Security + iOS/Backend；production enforce |
| IAR-04 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-07 | 已有Echo generation/context guard可复用，但未绑定AccountLease且coordinator无明确actor isolation | Spec 22.1-22.6、29.3 | WP-S1-03 | iOS；actor/concurrency/runtime tests |
| IAR-05 | HIGH | `PARTIALLY_ACCEPTED` | CR-08 | 接受FeatureFlag future默认开启问题；Widget“未清理”结论受审查范围限制：KBLiteManager switch调用activate，SnapshotStore 53-70删除旧文件且generation guard存在，但仍需统一AccountLifecycle | Spec 19、22.3-22.5、29.5 | WP-S0-06 + WP-S0-01 | Product+iOS；server policy/TTL/offline deny |
| IAR-06 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-05 | raw client与Archive直sync属于legacy baseline；目标typed facade、epoch与single Authority正确 | Spec 24、28、30、34 | WP-S1-01 + WP-MIG-01 | iOS/Backend/Data；old client read-only |
| IAR-07 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-07 | EchoVC职责过载成立；采用渐进strangler，不做一次性VC重写 | Spec 22.1-22.7 | WP-S1-03 | iOS；先抽application/runtime ports |
| BAR-01 | BLOCKER | `ACCEPTED_IMPLEMENTATION_GAP` | CR-02 | backend anonymous/shadow/fallback是当前P0风险；route registry不等于对象AuthZ | Spec 23.8、25、30.4；DR-023/024/035 | WP-S0-02 | Security+Backend；unknown/policy error deny |
| BAR-02 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-04 | 单连接、startup DDL、health不查DB与目标UoW/migrator/readiness冲突 | Spec 23.6、27-28、34.5 | WP-S0-04 | Backend/Data/SRE；real Postgres + restore |
| BAR-03 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-05 | generic upsert可改user_id；需要复合owner key、冲突拒绝和typed schema | Spec 24.1-24.3、25.6、27.3 | WP-S0-02 + WP-S1-01 | Backend/Data/Security；cross-vault corpus |
| BAR-04 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-06 | TimeLetter delivered与Mailbox非原子，当前test未覆盖crash gap | Spec 26.2-26.4、31、34.3 | WP-S1-02 | Backend/Worker；delivered-without-outbox=0 |
| BAR-05 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-05 | Source/Candidate/MemoryVersion不存在、Context/KBLite仍混用是Stage1主缺口 | Spec 9-10、23.7、24.3-24.6 | WP-S1-01 | Product/Backend/Data；confirmed-only Context |
| BAR-06 | HIGH | `ACCEPTED_EXTERNAL_GATE` | CR-09 | mock object、mock DH与Voice pending不能证明businessUsable/externalVerified；目标33节正确 | Spec 26.5-26.10、32-33；DR-026/028/031/037 | WP-V0-01 + WP-S1-01 + WP-S1-02 | Provider/Privacy/Operations；真实provider/真机 |
| BAR-07 | HIGH | `ACCEPTED_IMPLEMENTATION_GAP` | CR-10 | soft delete/local delete没有完整module/object/provider/backup receipt和restore/replay | Spec 13、24.7、28、34.3/34.7；DR-011/035 | WP-S0-05 + WP-S0-04 | Privacy/Backend/SRE；rights/restore drill |
| SOR-01 | BLOCKER | `DUPLICATE` | CR-02 | 独立安全视角确认IAR-03/BAR-01同根因；保留攻击面证据，不创建第三套AuthZ任务 | Spec 12、16、25、30 | WP-S0-02 | Security；canonical BAR-01/IAR-03 |
| SOR-02 | BLOCKER | `ACCEPTED_SPEC_FIX` | CR-03 | 目标30.6/33.3已有原则，但Stage0未把credential inventory、artifact scan、泄漏轮换和真短期broker列为明确退出门；本轮补齐 | Spec 3.1、20、30.6、33.3 | WP-S0-03 | Security+Provider owner；rotation/scan/external TTL |
| SOR-03 | HIGH | `DUPLICATE` | CR-08 | 与IAR-05的release fail-open同根因；Publication目标已明确独立域，当前不得开放 | Spec 3.3、9-10、19；DR-002/006/010 | WP-S0-06 + WP-S3-01 | Product/Privacy；canonical IAR-05 |
| SOR-04 | HIGH | `ACCEPTED_EXTERNAL_GATE` | CR-09 | minor/third-party/Voice purpose规则需产品、Privacy/Legal与Provider证据；工程不能代为批准 | Spec 8、12、16-17；DR-022/031/036/037 | WP-V0-01 | Product+Privacy/Legal；真实数据前 |
| SOR-05 | BLOCKER | `ACCEPTED_IMPLEMENTATION_GAP` | CR-10 | 本地tombstone/disable不得显示完整删除；目标分层receipt正确 | Spec 13、16-17、26/32/33；DR-011/031/035 | WP-S0-05 | Privacy+Backend+Provider；access先撤/partial披露 |
| SOR-06 | HIGH | `PARTIALLY_ACCEPTED` | CR-09 | 接受purpose binding、禁止dual-send和exit要求；不要求删除内部通用TTS adapter，但公开/业务接口必须绑定Answer/purpose/policy/profile/requestHash | Spec 17、26、33；DR-028/031/037 | WP-V0-01 | Voice/Privacy/Architecture；Beta0 gate |
| SOR-07 | HIGH | `ACCEPTED_SPEC_FIX` | CR-11 | Section18/19已有测量原则，但Stage0需明确最小operation/rights/incident/cost evidence；增长目标值可等真实基线 | Spec 3.1、6、18-19；DR-019/027/032/039 | WP-S0-07 | Operations+Finance+Privacy；measurement metadata |
| SOR-08 | BLOCKER | `PARTIALLY_ACCEPTED` | CR-12 | 缺DR/restore会阻断V4 cutover/contract，成立；但不把当前单机compose本身判为现有legacy服务必须立即停机。Stage0补restore/readiness基线，迁移门维持no-go | Spec 3.1、20、28、34；DR-034/040 | WP-S0-04 + WP-MIG-01 | SRE/Data/Security；C07/C10/C11前 |

## 4. Round 3D 对目标规格的修正

本轮只修正规范和阶段门，不宣称实现完成：

1. Stage 0 增加 AccountLease/local store隔离、禁止auto-claim/固定fallback owner。
2. Stage 0 增加credential inventory、artifact/header/log scan、泄漏轮换、真短期broker退出门。
3. Stage 0 增加request-scoped DB UoW、versioned migrator、DB/schema readiness、backup隔离restore基线。
4. Stage 0 增加分层rights/delete状态和当前公开异步effect的stable receipt/reconcile止损。
5. Stage 0 增加最小operation/rights/incident/provider cost evidence；增长目标值延后。
6. 保持Publication/Visitor、公开Voice/DH、复杂Family/Care/TimeLetter不阻塞Owner Truth Loop；现有代码默认关闭并保留兼容。

## 5. 未关闭边界

- 22项 finding 的“响应完成”不等于对应生产代码修复。
- `WP-*` 必须在 Round 4 解析为代码范围、schema/API、测试、部署、回滚和退出门。
- DR/Privacy/Legal/Provider/Finance/Operations/真机/生产门保持未关闭。
- 凭据潜在暴露必须由资产 Owner 实际轮换并形成证据；本文不保存或复述 secret。
