# DreamJourney V4 产品确认后开发执行计划

版本：V1.1
日期：2026-07-15
状态：`DERIVED_EXECUTION_SLICE / NON_AUTHORITY`
基线：iOS `feature/prd-stitch-ui-adaptation@983cda7`；Backend `main@4c0538b`

## 0. 计划定位

本文把 2026-07-15 已确认的五项产品细节转成可执行开发顺序。本文不新增 Product Spec、Domain、Authority、Work Package 或 Work Item，也不覆盖：

1. [V4 Product Spec](../../product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md)
2. [产品决策登记册](../../product/DreamJourney_V4_产品决策登记册_V1.0.md)
3. [当前实现证据矩阵](../../product/DreamJourney_V4_当前实现证据矩阵_V1.0.md)
4. [115 项可执行路线图](./2026-07-12-dreamjourney-v4-executable-development-roadmap.md)
5. [开发前问题与决策收敛清单](../../product/DreamJourney_V4_开发前问题与决策收敛清单_V1.0.md)

冲突时以上述权威顺序为准。本文只负责把现有 Work Item 组织成团队可连续执行的小闭环；Registry 的 `stableRank`、Gate、Authority lease 和 STOP/NO_GO 仍是实际执行控制面。

### 0.1 单一执行入口

本文是日常开发的唯一主入口。启动长期任务后，不要求每轮重新通读 Product Spec、决策登记册、证据矩阵或 115 项路线图。

每个小闭环的最小读取集合只有：

1. 本文当前 Phase/Slice。
2. Registry 中当前一个 Work Item 的 16 个字段、依赖、Gate 和 Authority lease；不通读整个 Registry。
3. 该 Work Item 涉及的源码、测试、最近提交和工作区差异。

仅在以下情况回查其他权威文档：

- 进入或退出一个 Phase，需要核对该阶段完成定义。
- Work Item 与现有代码、产品范围、权限或数据 Authority 出现冲突。
- Product Spec、决策登记册或路线图出现新提交或 hash 变化。
- 需要改变 Work Item、Gate、发布范围或产品口径。

权威文档没有变化时禁止重复全文分析。路线图和 Registry 是审计与机器控制面，不是每轮开发的阅读负担。

### 0.2 当前实施交接点

截至 2026-07-15：

- 五项产品确认已在本地同步到 Product Spec、决策登记册和既有路线图。
- Trace/Registry 已重新生成，仍为 36 FR、43 DR、13 Package、115 Work Item。
- Product V4 QA 为 25/25 通过，但本轮文档变更尚未提交。
- Registry 当前动作为 `PLAN_ASSIGN_OWNER:WI-S0-03-01`，对应 Authority lease 尚未持有。

因此长期任务启动后的明确顺序是：

1. 只提交本轮权威文档、生成物和本文，不混入过程 ledger 或其他脏文件。
2. 为 `WI-S0-03-01` 分配 execution owner 并取得 `CREDENTIAL_CONTROL` Authority lease。
3. 实施 Slice 1A credential inventory/scanner，并完成其验证和独立提交。
4. 通过后自动进入 `WI-S0-03-02`，不得重新从产品分析开始。

## 1. 产品确认输入

| 回执 | 已确认口径 | 落地 Work Item |
| --- | --- | --- |
| `PDC-D01=A` | 基础 MVP 要求 Owner private 与授权 Family Voice；Visitor Voice 独立 capability/cohort。家庭成员客户端必须使用目标人物对应且已授权的精确 profile version | `WI-V0-01-06/07/11` |
| `PDC-D02=A` | Closed Pilot 保留本地照片草稿和本机预览，明确未云端保存，不冒充 uploaded/synced/verified | `WI-S1-01-12`，并受 `WI-S0-06-03/07` 保护 |
| `PDC-D03=D` | Candidate 持续持久化；退出页面或服务端动态阈值先到即审核；强杀/断网恢复；上下文截断不丢业务数据 | `WI-S1-01-03/04`、`WI-S1-03` 对应 typed UI |
| `PDC-D04=A` | Family 支持暂停和终止；立即撤销旧 grant，历史保留；重新建立关系重新邀请和授权 | `WI-S0-02-05`、`WI-S3-01` |
| `PDC-D05=A` | 首批 Closed Pilot 只开放 Adult Self；Memorial Controller 第二 cohort；Guardian/未成年人独立 G4 | `WI-S1-01-10`、`WI-S1-01-11` |

## 2. 总体目标和边界

### 2.1 总体目标

按以下顺序把工程推进到可验状态：

```text
Stage 0 安全止损
-> Adult Self Closed Pilot 文字核心
-> Family + Publication/Visitor 文字 MVP
-> Owner/Family Voice MVP
-> Digital Human / 真实媒体 / Care / TimeLetter 独立扩展
```

### 2.2 必须保持的边界

- 继续使用 UIKit、三 Tab 和当前 Stitch 已对齐视觉，不进行无关 UI 重构。
- KBLite 只能作为 Projection/兼容读取，不成为 Memory Authority。
- Family relationship 不等于 AccessGrant；Visitor 不查询私人 Projection。
- 本地照片可以显示，但必须明确未云端保存。
- Provider、模拟器、一次 smoke、音频有声或数字人显示都不能单独证明功能完成。
- Visitor Voice、Digital Human、媒体处理、Care、TimeLetter 均可独立关闭，不影响 Owner 文字核心。
- 不按沉没成本公开已有隐藏功能，不把当前实现状态自动提升为 V4 `VERIFIED`。

## 3. 当前实现处置基线

以下仅用于决定复用动作，最终成熟度仍以 Evidence Matrix 和 Gate evidence 为准。

| 当前模块 | 处置 | 原因与目标 |
| --- | --- | --- |
| `FeatureFlagService` | `ADAPT` | 保留 feature 枚举和 QA 能力；移除 Release 本地默认授权，改为 server ReleasePolicy + capability + AuthZ |
| `DreamJourneyBackendClient` runtime/voice/DH clients | `ADAPT` | 保留 typed client 外形；移除长期 Provider secret 合同，消费产品 session/真短期 credential |
| Backend `main.py` DH response、`tokens.py` realtime config | `RETIRE/ADAPT` | 停止返回腾讯/火山长期 credential；改 broker、后端代理或明确 blocked |
| Archive 本地媒体模型和详情 UI | `ADAPT` | Closed Pilot 只保留 owner-scoped 本地照片草稿和诚实状态；真实 SourceObject 独立后置 |
| KBLite snapshot/change/context | `ADOPT_AS_PROJECTION` | 复用查询和 trace 能力，不允许执行 Candidate review 或写 Confirmed Memory |
| Echo Context/Trace/Evidence Bundle | `ADAPT` | 接 typed Citation、authorityEpoch、Candidate/Memory 状态；不改变公开 Echo 主视觉 |
| Family invitation/relationship/grant 合同 | `ADAPT` | 拆 relationship 与 grant，补 pause/terminate/reinvite 和旧 grant 失效 |
| Voice profile/TTS/role selection | `ADAPT` | 服务端按 target persona 解析精确 profile version，禁止访问者/上一角色/默认音色错配 |
| Tencent Digital Human runtime | `KEEP_BETA` | 仅在 Voice、credential、session 和真机 Gate 后推进，不阻断基础 MVP |
| Care、TimeLetter | `KEEP_HIDDEN` | 保持兼容和 rights/notification 修复，不进入当前 critical path |

## 4. Phase 0：权威文档和执行基线

### 4.1 任务

1. 将五项确认写入 Product Spec、Decision Register、问题清单和既有 Roadmap。
2. 保持 Decision Record 总数 43；五项细节补充既有 `DR-003/009/015/037/041/043`，不创建重复决策轴。
3. 重新生成 Trace/Registry，确保仍为 36 FR、43 DR、13 Package、115 Work Item。
4. 给 Registry 当前 selector `WI-S0-03-01` 分配 execution owner 和 authority lease 后，才进入代码实施。

### 4.2 完成证据

- Product V4 canonical/docs/links/finalization 全部通过。
- Trace/Registry 重生成后无非预期差异。
- `git diff --check` 通过。
- 文档提交与代码实现提交分开，便于审计。

## 5. Phase 1：Stage 0 Credential 与 ReleasePolicy 止损

这是下一轮代码开发的最高优先级；当前确定性第一项是 `WI-S0-03-01`。

### 5.1 Slice 1A：无值 Credential Inventory

对应：`WI-S0-03-01`

任务：

1. 建立不输出 secret value 的 source/history、`.app/.appex`、Info.plist、dSYM、response/header、runtime/oslog、QA export、container、backup inventory。
2. 扫描 iOS 与 Backend 当前合同，记录 credential kind、owner、surface、rotation status、replacement path。
3. 把扫描接入现有 release QA，但报告只包含种类、位置、hash/状态，不包含值。

验证：fixture 正负样本、历史提交扫描、Release artifact 扫描、日志/证据包检查、`git diff --check`。

退出条件：所有长期 system/provider credential 表面可枚举；发现项都有 owner、containment 和 rotation action。

### 5.2 Slice 1B：Response Kill Switch 与 No-Store

对应：`WI-S0-03-02/03/06`

任务：

1. Backend 停止在 `/digital-human/sessions` 返回腾讯长期 `appkey/accesstoken`。
2. Backend 停止在 realtime config/token 路径返回火山长期 `appToken/apiKey`。
3. 为 auth/provider capability response 增加 `Cache-Control: no-store` 和日志 allowlist。
4. iOS 删除 system/shared token 和全量 `LocalConfig` 注入依赖；Provider 不可用时明确回文字/关闭能力。

验证：Backend 单测、API contract smoke、iOS static contract check、Release build secret scan、旧客户端错误合同测试。

停止条件：若 Provider 没有真正可撤销、带 scope/TTL/audience 的移动端 credential，则相关直连能力保持关闭，不用自制 `expiresAt` 冒充短期凭据。

### 5.3 Slice 1C：Realtime Voice 与 Digital Human 安全接入路径

对应：`WI-S0-03-04/05/07`

任务：

1. 评估 Provider 官方 broker/session 能力；支持则服务端 mint per-session credential。
2. 不支持则选择后端代理或暂时关闭直连，不在 iOS 留共享 key。
3. 完成旧 credential rotation/revoke/drain，并保留无值 receipt。

验证：replay/expired/wrong-subject/wrong-device/old-build deny；Provider sandbox 和撤销回执属于 G3，不用 mock 关闭。

### 5.4 Slice 1D：Server-authoritative ReleasePolicy

对应：`WI-S0-06-01..08`

任务：

1. 定义版本化 `ReleasePolicySnapshot`：feature、audience、cohort、minClient、TTL、emergencyRevision。
2. iOS 实现 account/app-version scoped cache；missing/expired/offline/unknown 时按风险 deny/read-only。
3. 修改 `FeatureFlagService`：Release 不再通过 `defaultEnabled` 授权 Family、Voice、DH、Care、TimeLetter 或媒体云能力；QA override 仅 Debug/UIQA 当前进程生效。
4. UI route 与 backend command 使用同一 captured policy decision，effect 前重验撤销。
5. 增加 public release scope regression：fresh install、upgrade、offline、expired、deep link、旧持久化 flag、command deny。

退出条件：未批准功能误露为零；policy/capability/AuthZ 三轴可解释；Owner 文字入口在扩展全关时仍可用。

## 6. Phase 2：Stage 0 平台前置闭环

Credential 和 ReleasePolicy 不能替代其他 Stage 0 门。按 Registry stableRank 继续：

| 工作包 | 目标 | 关键退出证据 |
| --- | --- | --- |
| `WP-S0-04` | versioned migration、request/job UoW、readiness、backup/isolated restore | G2 真实 Postgres migration/restore/replay |
| `WP-S0-07` | operation/provider/rights/release 事件、证据包、incident 和成本分母 | 无正文/secret 的 current evidence manifest |
| `WP-S0-02` | 手机强身份、resource AuthZ、relationship/grant、old-client boundary | A/B 跨账号 deny、session refresh/revoke、对象级 AuthZ |
| `WP-S0-01` | AccountSessionActor/Lease、本地 owner store/cache/notification 隔离 | switch/logout/delete/late callback 不跨 owner |
| `WP-S0-05` | access-first rights、删除/恢复/Provider/backup 分层回执 | 不以 tombstone 或单字段宣称彻底删除 |

并行限制：schema、typed contract、fake 和 shadow 可以并行；未取得 Authority lease 的任务不得切生产 writer；没有 backup/restore 证据不得做不可逆 migration cutover。

## 7. Phase 3：Adult Self Closed Pilot 文字核心

### 7.1 Slice 3A：Source Authority

对应：`WI-S1-01-01/02`

- 新增 versioned Source/Candidate/Decision/Memory schema 与 authorityEpoch。
- 先实现文字 `CreateSource` command/receipt；当前 Archive 创建页通过 adapter 接入。
- 本地照片只作为明确未云端保存的 owner draft，不参与 verified SourceObject 或模型处理。

验证：owner/Vault 约束、幂等、删除、跨账号、旧 payload owner 伪造、migration rollback。

### 7.2 Slice 3B：Candidate 生成和动态审核

对应：`WI-S1-01-03/04`

- ExtractionResult 只能生成 pending Candidate，不能直接写 KBLite confirmed/Memory。
- Message、Source、Candidate、review batch 持续落库。
- Server policy 根据 pending count/context budget 产生 `reviewDue`；页面退出或 `reviewDue` 先到即提示。
- 强杀、断网、后台恢复同一 batch；普通候选批量，敏感候选逐条。
- `accept/correct/reject` terminal transition 与 immutable DecisionReceipt 同一 UoW。

验证：exit/threshold race、context truncation、duplicate decision、crash/relaunch、offline recovery、cross-vault、敏感批量拒绝、G2 并发唯一。

退出条件：模型上下文清空或截断时业务记录仍完整；每个 terminal Candidate 恰一 receipt。

### 7.3 Slice 3C：Memory、Projection、QA 与 Correction

对应：`WI-S1-01-05..08`

- DecisionReceipt 创建 immutable MemoryVersion，CAS 保证恰一 current。
- KBLite 由 MemoryVersion/rights 事件重建，只作为 Projection。
- `/context/build` 只读取 active confirmed Memory/Projection，回答返回 typed Citation。
- “回答错误”创建 correction Candidate，不原地覆盖事实。

验证：projection rebuild、source/memory revoke、citation resolution、stale correction、context permission、无来源事实为零。

### 7.4 Slice 3D：Legacy shadow 与 Adult Self cohort cutover

对应：`WI-S1-01-09/10`、`WP-MIG-01` 适用项

- 旧 Archive/KBLite/memories/conversation 数据按 provenance 分级；无 owner/source/decision receipt 的内容进入 review/quarantine。
- 先 shadow parity，再按 Vault CAS 提升 authorityEpoch。
- 首批只开放 Adult Self；Memorial Controller 不随首批自动进入。
- 扩展功能全部关闭时，Capture -> Review -> Memory -> QA -> Correction -> Rights 仍通过。

验证：真实 Postgres、backup/restore、old client、second writer、rollback/forward fix、release-like regression。

Closed Pilot 退出条件：一个强认证 Adult Self 完成文字 Source -> Candidate decision -> MemoryVersion -> citation QA -> correction -> delete/rights 最小闭环，且跨账号、第二 Authority、无来源事实和未解释副作用为零。

## 8. Phase 4：Product MVP Family 与 Publication/Visitor 文字链

### 8.1 Family relationship/grant

对应：`WI-S0-02-05`

- relationship 与 AccessGrant 独立；历史 accepted family 不自动补 grant。
- 支持邀请、接受、暂停、终止、重新邀请。
- 任一方可发起终止；敏感主控关系二次确认。
- terminate 原子递增 relationship epoch、撤 active grant、写 receipt。
- 重新邀请产生新关系/授权身份，不恢复旧 grant。
- Source、Publication、TimeLetter 保留/删除按自身 Authority 和 rights 合同执行。

验证：手机号重用、pending/failed、无 grant、purpose mismatch、expiry、terminate/reinvite、旧 grant replay、历史误删为零。

### 8.2 Publication/Visitor 文字 MVP

对应：`WI-S3-01-01..09`

- Owner 从 active MemoryVersion 创建独立脱敏 PublicationVersion，经预览和二次确认发布。
- Public Store/Index 与 private Projection 物理/权限隔离。
- Visitor 使用认证或过期/限次 grant；默认 TTL 7 天。
- Owner 只看聚合指标/举报，默认不看 Visitor 问题正文。
- 修正、删除、异议或 grant 变化先 suspend/withdraw，再重建副本。

验证：private query deny、grant/revoke/expiry、7日TTL、prompt injection、举报、withdraw SLA、跨账号、真实 PG/restore。

Product MVP-P 退出条件：Family 与 Visitor 每次 allow 都有有效授权证据，Visitor 只引用 Public Citation，撤回后新访问为零。

## 9. Phase 5：Owner / Family Voice MVP

执行顺序沿用 `WP-V0-01`：01/04 止损 -> 02 schema -> 03 training -> 05 quality -> 06 audio -> 07 role -> 10 rights -> 11 exit。Digital Human 的 08/09 单独属于 Beta，不阻断基础 Voice MVP。

### 9.1 Voice Authority 与合成

- Consent 按 training、owner private、family playback、Visitor、commercial purpose 分离。
- Provider ready 只进入 preview；Owner 试听接受后，精确 profile version 才 active。
- synthesis 绑定 answer/publication、textHash、profileVersion、purpose、outputMode、TTL 和 receipt。
- 任意文本 + 任意 profile 的通用合成不能进入正式链路。

### 9.2 Family Role Voice Selection

对应：`WI-V0-01-07`

- 服务端 `ResolveRoleVoice` 以 viewer、target persona/subject、grant、consent、quality 和 profileVersion 决策。
- 家庭成员客户端播放目标 Owner/Represented Persona 回响时使用目标人物 profile，不使用 viewer profile。
- 角色切换清 pending request/cache/audio，并以 generation fence 忽略旧回调。
- 不可用时明确回文字或标注系统默认音色；不得使用上一角色/全局槽位冒充。

验证：不同 viewer 同一 target、同一 viewer 不同 target、快速切换、撤回 consent、删除 profile、stale callback、cache owner/purpose 隔离。

### 9.3 Voice MVP Exit

- 基础退出只评估 Owner private 与授权 Family Voice。
- Visitor Voice 保留合同和独立 capability/cohort，默认关闭，不阻断基础 MVP。
- Provider 训练、试听、TTS、删除、成本、真机听感分别保留 G3/G4，非真机最高只能到 `INTERNAL_READY/EXTERNAL_BLOCKED`。

退出条件：试听音色与 Echo 目标人物音色一致；每轮可解释 target/profileVersion/purpose/fallback；跨人物错用、默认音色误标、旧角色尾音和未授权合成为零。

## 10. Phase 6：独立扩展，不进入当前 critical path

| 能力 | 进入条件 | 当前动作 |
| --- | --- | --- |
| Tencent Digital Human | Voice/credential/session/audio owner 稳定，素材/配额/真机门关闭 | 保持 Beta；只做 port、session receipt、fail-closed 和 QA |
| 真实 SourceObject/媒体理解 | Adult Self 文字核心稳定；对象存储、地域、scan/delete Provider 合同关闭 | 本地照片继续诚实展示；真实上传和 processor 独立 cohort |
| Visitor Voice | Publication 文字链、独立 purpose、滥用、成本、Provider、真机门关闭 | 合同保留、默认关闭 |
| Memorial Controller | 死亡事实、亲属关系、主控任命和争议流程可验证 | 第二 cohort，不与 Adult Self 首批同波 |
| Guardian/未成年人 | 专项法律、监护证明、年龄和 Provider G4 | blocked/独立 cohort |
| Care、TimeLetter | Owner core 价值成立且各自权限/通知/rights 决定完成 | 保持 hidden，不占当前关键路径 |

## 11. 连续执行顺序

开始每项前必须读取当前实现、最近提交和已有 QA，避免重复。推荐连续小闭环如下：

1. `WI-S0-03-01` credential inventory/scanner。
2. `WI-S0-03-02` response kill switch/no-store/log allowlist。
3. `WI-S0-03-03/06` mobile shared token 与 LocalConfig/provider direct path 退役。
4. `WI-S0-03-04/05/07` voice/DH broker 或 blocked 决策、rotation/revoke。
5. `WI-S0-06-01/02` ReleasePolicySnapshot 与 offline/expired deny。
6. `WI-S0-06-03..07` default-off、captured command gate、QA override、release regression。
7. 按 Registry 继续 `WP-S0-04` DB/migration/restore、`WP-S0-07` evidence、`WP-S0-02/01/05` 身份/隔离/rights。
8. `WI-S1-01-01/02` Source foundation。
9. `WI-S1-01-03/04` Candidate 持久化、动态审核和 DecisionReceipt。
10. `WI-S1-01-05..08` Memory/Projection/QA/Correction。
11. `WI-S1-01-09/10` shadow、Adult Self cohort cutover 和 Closed Pilot exit。
12. `WI-S0-02-05` Family terminate/reinvite/grant。
13. `WI-S3-01-01..09` Publication/Visitor 文字 MVP。
14. `WI-V0-01-01..07/10/11` Owner/Family Voice MVP。
15. Visitor Voice、Digital Human、真实媒体和后置域按独立 Gate 再进入。

一个小闭环验证并提交后，自动选择同一序列中下一个未完成项；不得越过 STOP/Gate，也不得因为 UI 已存在跳过底层 Authority。

## 12. 每轮实现与验证合同

### 12.1 实现前

- 读取本文当前 Slice，以及 Registry 中当前 Work Item 的全部 16 个字段；不通读其他未变化文档。
- 读取该 Work Item 的相关源码、最近提交、工作区差异和已有脚本，确认没有重复实现。
- 声明本轮 Work Item、Authority lock、现有实现处置和不会触碰的模块。
- 数据或行为变化先补 unit/static/smoke；UI 变化先固定 ViewState/fixture。

### 12.2 实现后

至少运行：

1. 相关 Swift/Backend 单测或静态检查；
2. 对应 smoke/gate；
3. `git diff --check`；
4. iOS Simulator 或 generic iPhoneOS build；
5. Backend 合同变化时运行 FastAPI smoke 和真实 Postgres deployed smoke；
6. UI 变化时运行模拟器 UIQA 并保存截图；
7. Provider/真机项只记录 `INTERNAL_READY/EXTERNAL_BLOCKED`，直到真实证据完成。

### 12.3 提交与部署

- 每个独立闭环单独提交，提交信息包含 Work Item 与结果。
- iOS 与 Backend 分仓提交，不混入过程 ledger 或无关脏文件。
- Backend 合同或 schema 变化先 push，再部署、readiness、migration、smoke；未验证不标 `VERIFIED`。
- 不自动推送远程，除非用户明确要求；不可逆 migration、credential revoke、真实数据 purge 必须有批准和 rollback/compensation 证据。

## 13. Stop Conditions

出现以下任一情况立即停止对应 lane，但保留 Owner 文字降级：

- 长期 system/provider credential 出现在客户端、response、header、日志、QA 导出或 artifact。
- 跨账号/跨 Vault 读取或写入成功。
- DB backup/isolated restore、migration head 或 request/job UoW 无法证明。
- Candidate/Memory 出现无 Source/DecisionReceipt 的事实写入。
- Family relationship 被当成 grant，或 terminate 后旧 grant 仍可访问。
- 本地照片显示已同步/verified，但没有真实对象 receipt。
- Family Voice 使用 viewer、上一角色或默认音色冒充目标人物。
- Provider unknown 被当成 success，或删除没有分层 receipt 却显示彻底完成。
- Digital Human、Visitor Voice、Care、TimeLetter 或媒体扩展故障阻断 Owner 文字核心。

## 14. 计划完成定义

本计划不是以“115 项全部编码”作为单一完成点，而是按产品层级分别关闭：

1. `Stage 0 Exit`：身份、隔离、credential、DB/restore、rights、release policy、evidence 可证明。
2. `Closed Pilot Exit`：Adult Self 文字 Owner Truth Loop 可真实使用、引用、纠正和删除。
3. `Product MVP-P Exit`：Family relationship/grant 与 Publication/Visitor 文字链通过。
4. `Product MVP-V Exit`：Owner/Family Voice 用途、音色、合成、删除和真实设备证据通过；Visitor Voice 不作为阻断项。
5. `Beta/Future`：Digital Human、Visitor Voice、真实媒体、Care、TimeLetter 各自独立决定，不修改前四层完成事实。

任何层级只有适用 Gate evidence current 且审批完成才能 promotion；文档、代码存在、模拟器、单次 smoke 或 Provider ready 均不能替代。
