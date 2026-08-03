# DreamJourney V4 当前方案开发进展快照

日期：2026-07-23
状态：`SNAPSHOT / PAUSED_AFTER_WI-S1-03-07_G0-A / NOT_A_RELEASE_APPROVAL`

## 1. 文档目的与口径

本文把 DreamJourney V4 当前实现、执行计划、提交证据和未关闭 Gate 汇总为一个可读快照。它用于回答三个不同的问题，三者不能混为一个“完成率”：

1. **实现/证据覆盖**：某个 Work Item 是否已有代码、脚本、构建或部署证据。
2. **产品可用性**：对应能力是否已达到公开 M0 或后续 M1-M4 的发布条件。
3. **外部验收**：是否已获得 Postgres、Provider、真机、产品、隐私、法律或监管层面的证据。

因此，本文不会把“有代码”“G0 静态检查通过”“已部署 shadow”写成“产品已经完成”或“可以公开发布”。

### 1.1 本次快照依据

- 终版日常执行入口：`docs/superpowers/plans/2026-07-17-dreamjourney-v4-final-requirements-execution-plan.md`
- 当前执行交接：`docs/superpowers/status/2026-07-17-v4-current-execution-handoff.json`
- 保守 Work Item Registry：`docs/product/DreamJourney_V4_路线执行注册表_V1.0.json`
- 终版产品定义与实现证据矩阵：`docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`、`docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- iOS / Backend Git 状态与最近提交。

### 1.2 当前仓库基线

| 仓库 | 当前分支与提交 | 同步状态 | 说明 |
| --- | --- | --- | --- |
| iOS | `feature/prd-stitch-ui-adaptation@6f1a5a5` | 相对 `origin/feature/prd-stitch-ui-adaptation` 本地领先 308 个提交 | 最新本地提交是 `feat(echo): enforce audio session ownership`；尚未因此报告自动推送。 |
| Backend | `main@4224dd3` | 与 `origin/main` 对齐 | 最近为 callback reconciliation shadow 的部署记录。 |

> 计划文件头部保留的 `075a75a/a45170d` 是当时写计划时的历史基线，不是本快照时的实际 Git HEAD。后续更新计划头部时应同步校正，但不影响本次以 Git 实际状态为准的判断。

### 1.3 工作区保护

iOS 工作区在本次快照前已存在大量非本 Work Item 的改动，包括 `.closure-lodestar/`、`.complex-problems/`、`docs/plans/task_27_*`、`progress.md`、`findings.md`、旧 QA 脚本和 Xcode 工程文件等。本报告不把这些未提交/来源未确认的内容计入 V4 已交付能力，也不应对其执行清理、回退或批量提交。

Backend 工作区本次检查为干净状态。

## 2. 总体进度：证据覆盖不等于产品完成

### 2.1 Work Item 证据覆盖

V4 Registry 固定有 **115** 个 Work Item。current handoff 中已有 **89** 个 Work Item 具备至少一项实现、验证、部署或外部门状态证据，覆盖率为 **77.4%**。

这是“已经被执行系统识别并记录”的覆盖率，**不是** M0 发布完成率，也不是全产品完成率。其状态组成如下：

| handoff 状态前缀 | 数量 | 正确解读 |
| --- | ---: | --- |
| `INTERNAL_READY` | 65 | 已有 scoped 实现/验证，仍至少缺一个 G1/G2/G3/G4 或发布切流条件。 |
| `IMPLEMENTED` | 9 | 已编码，但依赖、外部 Gate 或完整验收仍开放。 |
| `COMPLETE` | 3 | 仅对应其 scoped 合同完成，不代表关联产品 Lane 已发布。 |
| `VERIFIED` | 2 | 对该 Work Item 当前声明的 scoped Gate 已有证据。 |
| `IMPLEMENTED_SHADOW` / `IMPLEMENTED_OBSERVE` | 3 | 只在 shadow/观测边界生效，不能作为生产路径放行依据。 |
| `INTERNAL_PREFLIGHT` | 2 | 只完成前置检查。 |
| `DEPLOYED` | 1 | 已部署但恢复切流仍为 `NO_GO`。 |
| `EXTERNAL_BLOCKED` | 2 | 明确缺 Provider/真机等外部证据。 |
| `CLOSED_WITH_RISK_EXCEPTION` | 1 | 已接受风险豁免，不等于 Provider 或生产安全验证。 |
| 其他 scoped readiness | 1 | 只证明对应适配器的 G0。 |

Registry 仍把 Work Item 保持为 `PLANNED/STOP/NO_GO` 是有意设计：Registry 管计划和依赖，handoff 管已取得的证据。两者不一致不是代码冲突，前提是不能只看 Registry 重复开发，也不能只看 handoff 越权宣布发布完成。

### 2.2 按 Work Package 的证据覆盖

| Work Package | 已有证据 / 总数 | 当前判断 |
| --- | ---: | --- |
| `WP-S0-01` iOS 账号与本地隔离 | 8 / 8 | 范围内 G0/G1/G2 证据较完整，仍有安全/真机类外部门。 |
| `WP-S0-02` 身份与路由 AuthZ | 6 / 6 | 已有 typed token、route/authz 和 Postgres 证据；强身份 Provider 与历史 rebind 仍未闭合。 |
| `WP-S0-03` 凭据控制 | 7 / 7 | inventory、响应边界、移动端路径退役等已落实；旧凭据未轮换为已记录风险豁免。 |
| `WP-S0-04` 数据库/恢复 | 5 / 5 | 工具和演练已做，但恢复切流 `NO_GO`，不是完成。 |
| `WP-S0-05` 数据权利 | 5 / 6 | 本地/后端状态合同已有；真实对象、Provider、备份删除仍缺。 |
| `WP-S0-06` ReleasePolicy 与安全止损 | 9 / 9 | 默认关闭、能力分轴、QA override、安全止损均有证据，仍不替代完整产品/监管门。 |
| `WP-S0-07` 运营证据 | 9 / 9 | 事件、readiness、观测和部署 smoke 已有；真实运营观察窗仍另算。 |
| `WP-S1-01` Owner Truth | 12 / 12 | Source/Candidate/Decision/Memory/Projection 等核心合同均有 scoped 证据，尚未形成完整 M0 对外闭环。 |
| `WP-S1-02` 异步 effect | 10 / 11 | effect/receipt/dead-letter 等边界已做；真实媒体处理 Work Item 仍未完成。 |
| `WP-S1-03` iOS composition/runtime | 10 / 10 | 架构 seam、runtime 生命周期、Echo 音频 owner 均有 scoped 证据；当前 G1/G4 仍开放。 |
| `WP-MIG-01` 迁移与切流 | 3 / 12 | 仅 inventory、schema lineage、identity preflight；尚未进入迁移波次与 cutover。 |
| `WP-V0-01` Voice/Digital Human 治理 | 4 / 11 | 默认拒绝、目的同意、训练前置和 capability shadow 已做；并非 M1/M2 可发布。 |
| `WP-S3-01` Publication/Visitor | 1 / 9 | 仅完成公开入口默认拒绝与非放行审计；功能本身未建设。 |

### 2.3 对产品层级的结论

| 产品层级 | 当前结论 | 不能作出的声明 |
| --- | --- | --- |
| M0 记忆资产 | **核心技术底座与 Owner Truth 合同正在形成，但未达到公开 M0 发布门**。 | 不能称“可信记忆资产、完整权利闭环、正式引导式访谈、可迁移/可删除”已完整上线。 |
| M1 在世成年人本人私有 Voice | **默认关闭，只有治理/训练前置/运行时复用资产**。 | 不能称声音复刻可公开、合规或已经完成本人身份、活体、质量、删除回执与真机验收。 |
| M2 成年授权 Publication / Visitor / Digital Human | **默认关闭，只有拒绝入口和既有技术资产**。 | 不能称有独立发布副本、成年 Visitor、公开数字人或持续人格化互动。 |
| M3 老人健康 / 成人纪念试点 | **未启动**。 | 不能使用现有 Family、Care、Voice 或 DH 壳层绕过逐案权利、伦理和监管门。 |
| M4 知识许可与收益 | **未启动**。 | 不能宣称知识授权、收益结算或数字传承产品已设计完成。 |

### 2.4 按终版计划 Phase 的落点

| Phase | 终版目标 | 当前落点 | 进入下一 Phase 前的关键事实 |
| --- | --- | --- | --- |
| 0 | 终版需求晋升、证据重算、唯一日常入口 | 已形成终版计划、Registry、handoff 和证据矩阵；日常执行入口已统一。 | 计划文件头部的历史 Git 基线应在后续文档维护时同步到当前 HEAD。 |
| 1 | Stage 0：恢复、身份、AuthZ、本地隔离、权利、运营 | 绝大多数 Work Package 已有 scoped 证据。 | 恢复仍 `NO_GO`；对象/Provider/备份删除、强身份 Provider 与 G4 外部门未关。 |
| 2 | M0 Authority 与可测试架构 | Owner Truth、effect、iOS composition 的核心合同和迁移已有大量证据。 | 尚未形成正式 M0 authority cutover 或公开用户闭环。 |
| 3 | M0-A 最小引导式访谈 | 边界命令、线程隔离、安全 override、QA-only 操作面已开始。 | Orchestrator、自然主题、完整会话节奏、批量确认和公开 UI 仍未完成。 |
| 4 | M0-B 双推荐与知识地图 | 有 KBLite compatibility 和 knowledge dimension 的初始 read/receipt 证据。 | 无正式两条推荐、覆盖度计算、reason/evidence 体验和反优化验收。 |
| 5 | M0-C 评测、迁移与发布闭环 | inventory、shadow、cutover admission 的前置证据存在。 | 无 cohort cutover、完整 rollback、M0 发布回归或 G4 放行。 |
| 6 | R4 真实媒体质量 | 媒体 Source/Object 边界、intent/commit shadow 有基础。 | 对象存储直传、真实处理、worker、质量与删除闭环未完成。 |
| 7 | M1 在世本人私有 Voice | 只完成 default-deny 治理、训练 preflight 与 capability shadow。 | 本人证明、同意、活体、质量、Provider/delete receipt、真机和产品门均未关。 |
| 8 | M2 Publication / Visitor / Digital Human | 仅有 public entry default-deny 与 non-admission 审计。 | Publication、成年 Visitor、独立读取域、数字人发布和监管门尚未建设。 |
| 9 | M3/M4 试点与商业权利 | 未启动，按终版范围默认关闭。 | 必须在 M0-M2 条件满足并完成专项法律/伦理/商业决策后才可启动。 |

## 3. 已落地的技术能力

### 3.1 Stage 0：身份、隔离、数据权利与运行安全

已落地或已有 scoped 证据的基础能力包括：

- iOS `AccountSessionActor`、`AccountLease`、账户生命周期协调、owner-scoped 本地存储、legacy quarantine 与部分本地清理边界。
- 后端 token family、route authentication、资源 owner/vault/purpose/grant/epoch 的 AuthZ 合同，以及 Postgres smoke。
- 凭据 inventory/scanner、Provider 响应最小化、移动端 system credential 路径收敛、ReleasePolicy/FeatureFlag、QA override 与默认拒绝策略。
- 版本化 migration、request/job scoped UoW、`/ready`、备份/隔离恢复工具、数据权利状态与删除 receipt 合同。
- 事件、readiness、operation/effect 证据和安全止损的基础合同。

代表性代码/模块：

- iOS：`DreamJourney/Sources/App/AccountSessionActor.swift`、`AccountLease.swift`、`AccountLifecycleCoordinator.swift`、`AccountPrivateMediaStore.swift`。
- Backend：`app/services/auth_sessions.py`、`route_authentication.py`、`resource_authorization.py`、`data_rights_*.py`、`app/db/readiness.py` 与 `db/migrations/0002` 至 `0010`。

### 3.2 M0 Owner Truth 主干

后端已形成或正在使用以下可复用主干：

```text
Source Command
-> Candidate Extraction / Review / Decision
-> Memory Activation / MemoryVersion / Projection
-> Citation / Correction
```

对应模块位于 `app/domain/owner_truth/`、`app/services/owner_truth_*.py`，并有 `0011` 至 `0041` 的相关迁移。iOS 已具备 Owner Truth contracts/repository、自然输入 use case、AccountLease 围栏、QA-only boundary surface 等接入基础。

已经明确完成的局部边界包括：

- `skipOnce`、`cooldown`、`doNotAsk` 的 typed、owner-scoped、captured-policy 路由；其中 `doNotAsk` 的恢复必须显式确认。
- `skipOnce` 仅在下一段 owner narrative 成功落库后原子消费；不会泄漏给下一轮。
- 高风险表达在 narrative append 之前走中性安全 override，不写入访谈或推进版本。
- 同 owner、同 vault 的多线程 preference 隔离；错配 `session/thread` 不写入。
- QA-only UI 可重复验证边界操作，Release 不创建该调试控件。

这意味着“受控的访谈状态边界”已开始可测；但它**不等于**完整的 Interview Orchestrator、自然主题识别、两条动态推荐、知识覆盖度、批量确认体验或公开 M0 引导式访谈都已完成。

### 3.3 异步 effect、消息与时间信件

已经有以下合同/壳层：

- async effect 结构、provider query/reconciliation shadow、dead-letter/replay request、worker-loss/readiness evidence。
- 时间信件的封存、到期投递、mailbox/in-app message 的局部合同和 typed admission shadow。
- Echo delayed reply、业务消息通知的合同与部分 owner scope 验证。

当前仍不能把它们称为统一生产 effect kernel：真实 provider 调用、对象存储、worker/outbox、投递/重放/删除的完整操作闭环仍有独立 Work Item 和 Gate。

### 3.4 iOS Echo、音频 owner 与数字人运行层

现有 iOS 已保留 Echo、Context/Evidence、数字人 runtime、PCM/口型、Voice/DH adapter 等技术资产，并将其纳入 V4 的受控范围。最新的 `WI-S1-03-07` 做了一个明确而有限的稳定性收敛：

- Echo capture、普通本地 Echo TTS、腾讯数智人播放都必须通过可注入的 `AudioSessionCoordinator` 取得精确 lease。
- coordinator 只在系统 driver 激活成功后提交状态；播放抢占 capture 失败时保留/恢复旧 capture；陈旧 release、interruption、resume 不能改变新 owner。
- `DialogEngineManager` 在 Echo 已持有受管 lease 时只复用该 lease；Archive/Profile/Memoir 的直接音频路径未在本 Work Item 中迁移。
- 已通过静态检查、fake-driver smoke、generic iPhoneOS `build-for-testing` 和 `git diff --check`。

关键限制：当前只关闭 **G0 代码合同**。模拟器交互 G1、真机麦克风/蓝牙/路由/打断/口型/音色一致性 G4 都未关闭。

### 3.5 Voice / Digital Human 治理边界

已存在 Voice Clone、TTS、腾讯数字人等旧实现与调试积累，但 V4 只承认以下前置能力：

- 在世本人 Voice/DH 目的与同意的 default-deny schema；
- 默认阻断不合格训练请求与样本 intent；
- scoped capability shadow、Provider 响应边界与最小化；
- iOS Echo/音频 owner 的可复用运行时基础。

这些是后续 M1/M2 的必要前提，不是 M1/M2 放行。尤其不能由 Family 关系、家人角色、历史 voiceProfile 或客户端配置自动获得 Voice、肖像、Persona 或数字人授权。

### 3.6 既有 Archive、Family、Knowledge、Profile 壳层

原公开 MVP 已保留 Archive / Echo / Profile 三 Tab、Stitch 全屏视觉、媒体详情、家庭/关怀/消息/时间信件/知识库等 UI 或合同资产。V4 的处理方式是“保留并逐步接入 owner-scoped Authority”，而不是推倒重做 UI。

当前限制如下：

- KBLite 只能作为 Projection/兼容读取，不能继续成为确认事实 Authority。
- Family 在 M0 只允许静态材料贡献、人物切换与静态故事；关系不自动带来查询、Voice/DH 或 Persona grant。
- Care、TimeLetter、隐藏媒体、数字人不因现有 UI 或 mock 合同自动进入公开 M0。

## 4. 当前明确未完成或未放行的事项

### 4.1 Stage 0 的硬 Gate

1. **恢复切流仍为 `NO_GO`**：最近隔离 Postgres 恢复发现 361 条历史 owner orphan，且 cutoff 后全库 command/outbox/deletion/provider replay bundle 缺失；G3 设备与发布态恢复证据也未提供。恢复工具已部署，不代表允许切流。
2. **真实删除未闭环**：账号/数据状态、soft delete、purge receipt 已有部分合同；对象存储、Provider、备份删除和外部删除回执仍需 G3/G4。
3. **强身份与全路由 AuthZ 仍缺生产级门**：typed contract 与 Postgres smoke 不等于 Identity Provider、历史身份 rebind、全渠道真实客户端/深链/通知/Widget 的正式验收。
4. **凭据风险已豁免但未轮换**：旧凭据不轮换是显式风险豁免，不能被报告为 Provider credential 安全验证完成。

### 4.2 M0 还缺的产品闭环

1. 面向公开 M0 的完整 Source -> Candidate -> DecisionReceipt -> MemoryVersion -> Projection 体验与正式 cutover。
2. 正式 Interview Orchestrator：长期自然输入、每轮单问题、2-4 轮总结、5-10 轮/退出时批量确认、主题/疲劳状态与真实用户控制体验。
3. Knowledge Dimension Projection、两条动态推荐、理由/证据、可读回顾工具与反优化评测。
4. 带来源的 Owner QA、纠正、数据复制/可读导出/机读清单/删除传播的完整用户闭环与第三方裁剪。
5. Legacy shadow、cohort cutover、回滚和 M0 发布回归；现有 M0 证据大多仍是 scoped 内部合同。

### 4.3 M1/M2/M3/M4 的剩余范围

- **M1 Voice**：成年人本人强身份、随机授权语句、活体、SNR/质量、Provider 训练/删除回执、AI 标识、撤回、真机质量与连续稳定性。
- **M2 Publication / Visitor / DH**：独立 Publication snapshot、在世主体主动发布、成年人验证、独立 Visitor principal/读取域、滥用与退出控制、AI 标识、监管/上架材料和真机/成本证据。现在仅有 default-deny/non-admission。
- **M3**：老人健康协同与成人纪念互动必须逐案进入，当前没有可放行产品路径。
- **M4**：权利目录、受益人、许可、计量、结算、争议和合同都尚未启动。

### 4.4 真实媒体与异步处理

`WI-S1-02-11` 尚无 evidence。对象存储直传、文件校验、OCR/ASR/PDF/DOCX、真实媒体 worker、可重试和可删除处理仍是后置 R4 工作，不能把当前 mock/upload-intent/详情壳层称为真实媒体能力。

## 5. 当前暂停点

当前 active Work Item 为 `WI-S1-03-07`，Authority lock 为 `IOS_COMPOSITION`，但 lease 已释放。已完成子切片：

`WI-S1-03-07-G0-A-ECHO_AUDIO_SESSION_COORDINATOR_ENFORCEMENT`

当前交接状态明确为：

```text
G0: 已验证（静态、fake driver、generic iPhoneOS build）
G1: OPEN（需要模拟器 UIQA）
G4: OPEN（需要真机音频、路由、打断、麦克风恢复等证据）
next: PAUSED_BY_USER_BEFORE_G1_OR_NEXT_WORK_ITEM
```

暂停是用户明确要求，并非技术 blocker。恢复时必须显式选择：

1. 先补 `WI-S1-03-07` 的 G1 模拟器 UIQA；或
2. 按终版计划选择下一个不与 `IOS_COMPOSITION` 冲突的 Work Item。

不得把 G0 自动提升为真机完成，也不得因 handoff 中 `activeWorkItem.state=IN_PROGRESS` 而在用户暂停期间继续开发。

## 6. 推荐的恢复后执行顺序

以下顺序遵守 V4 “M0 先行、M1-M4 默认关闭”的产品边界：

1. **收尾当前 Echo 音频 G1**：仅做模拟器 UIQA，验证 capture -> Tencent playback -> capture 恢复、角色切换与失败 fallback；不声称真机完成。
2. **处理 Stage 0 恢复 `NO_GO` 的修复计划**：owner orphan quarantine/reconciliation、可信 replay bundle、再跑隔离恢复；未经两项通过不得讨论切流。
3. **完善 M0 Owner Truth 的公开闭环**：从正式 Source/Decision/Memory Authority 和引导式访谈开始，而不是继续扩展数字人、声音或公开 Visitor。
4. **建设 M0 知识推荐与评测**：先 Projection、reason/evidence、两条推荐和用户控制，再做 cohort cutover。
5. **M0 发布闭环**：数据权利、导出/删除传播、legacy shadow、回滚、G1/G2/G4 发布证据。
6. **M1 Voice 独立 Lane**：只有在 M0 文字主线不受阻且本人授权/Provider/真机 Gate 可用时启动。
7. **M2/M3/M4 继续默认关闭**：Publication/Visitor/DH、健康与纪念试点、知识许可都不应因已有技术壳层提前公开。

## 7. 结论

当前工程已经从“只有公开 MVP 壳层和若干 Provider 调试链路”推进到“有明确 V4 产品边界、115 项可追踪计划、89 项 scoped 证据、Owner Truth/账户隔离/异步 effect/音频 runtime 的可测试基础”。

但它仍处于**内部实现与证据积累阶段**：M0 没有完成发布闭环，恢复切流为 `NO_GO`，真实删除/Provider/真机/外部合规 Gate 尚未关闭，M1-M4 全部必须保持默认关闭。后续开发应以完成 M0 的可信记忆资产闭环为主，不应被既有声音复刻、腾讯数字人或 UI 壳层带偏优先级。
