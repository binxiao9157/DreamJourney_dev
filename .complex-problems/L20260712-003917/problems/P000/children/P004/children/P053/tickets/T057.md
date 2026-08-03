# 将 Owner Truth、异步 Effect 与 iOS Runtime 拆成可渐进迁移的 Stage 1 工作项

## Problem Definition

Round 3 已固定 Owner 文字核心的目标 Authority，Round 4A/4B 已定义执行合同并拆完 Stage 0 安全底座，但 `WP-S1-01/02/03` 仍只有 package 级目标。若直接从这些目标开始编码，当前 Archive、KBLite、Memory、Context、Timer、Notification、Echo 与 `UIViewController` 容易各自演化成第二套 Authority，且无法证明 shadow、cohort、cutover 与 rollback 是否安全。

## Proposed Solution

1. 将 Round 4C 拆为三个互相依赖但责任不重叠的闭环：
   - `WP-S1-01 Owner Truth Authority`：Source/SourceObject → Candidate → DecisionReceipt → MemoryVersion → Projection → Conversation/Answer/Citation。
   - `WP-S1-02 Async Effect Authority`：transactional Outbox → Job/lease → Provider effect → Inbox/business receipt → reconcile/replay。
   - `WP-S1-03 iOS Composition & Runtime`：Composition Root、typed application ports、AccountLease/generation、Intent/ViewState、Echo runtime 与 audio owner。
2. 每个 package 建立连续且唯一的 `WI-S1-xx-yy`。每个 Work Item 只交付一个主要结果，并填满路线图 1.3 的 16 个字段；当前路径与计划新增路径必须明确区分。
3. `WP-S1-01` 先 additive schema/API 和 legacy facade，再做 shadow compare、backfill、cohort、authorityEpoch cutover 与 legacy writer retirement。没有 provenance 或 DecisionReceipt 的历史内容不得自动升级为 confirmed。
4. `WP-S1-02` 只拥有副作用执行和完成证据，不拥有业务真相。业务聚合与 outbox 同一 UoW；worker 用 lease 与 stable idempotency key；Provider 超时进入 unknown/reconcile，不盲重试；通知送达与业务完成分别记账。
5. `WP-S1-03` 只抽取 composition/application/runtime seam，不重写 Stitch 视觉、导航信息架构或整个 `EchoViewController`。UI 只发 Intent、渲染 ViewState；业务 Authority 仍在 S1-01，设备与 Provider runtime 通过 adapter 隔离。
6. Owner 文字核心必须在 Publication、Voice/DH、Family/Care/TimeLetter 全部关闭时完成 Capture → Review → QA → Correction → Rights。媒体 processor 只作为后置项，mock、临时 URL 或 failed analysis 不得冒充有效记忆事实。
7. 每项绑定具体 Stage 0 前置、release policy、authorityEpoch、迁移波次、部署顺序和 rollback/forward-fix。G0/G1 可以证明内部合同，真实 Postgres/cohort 使用 G2，Provider 使用 G3，设备/产品/法律使用 G4；外部门未关闭时不得标 `VERIFIED`。

## Acceptance Criteria

- 三个 Stage 1 package 均有稳定、连续、单结果的 Work Item，且每项 16 字段完整。
- `WP-S1-01` 覆盖来源与对象、候选审阅、决定回执、不可变版本与纠正链、派生投影、对话引用、legacy shadow/backfill/cutover/retire。
- `WP-S1-02` 覆盖 outbox/UoW、job lease、consumer inbox、业务完成回执、TimeLetter/Echo delayed reply、Provider unknown reconcile、通知分层、dead-letter/replay 与旧 timer 退出。
- `WP-S1-03` 覆盖 Composition Root、Domain/Application ports、AccountLease fence、Archive/Review/QA use cases、Echo runtime actor、audio owner、notification/deeplink adapter、渐进 strangler 与测试承载面。
- Owner 文字核心没有 Voice/DH、Publication、Family/Care/TimeLetter 的硬依赖；可选能力关闭时仍有完整可验收闭环。
- 所有 Authority 切换都有单 writer、authorityEpoch、shadow parity、cohort、go/pause/no-go、rollback 与 legacy retirement 条件。
- 工作项引用当前真实代码证据或显式新增位置，不把现有兼容层、静态检查、mock、模拟器或配置存在误写为生产完成。

## Verification Plan

1. 对照 Product Spec 的 Owner loop、Context、Correction、Rights、runtime 和可选能力边界，以及 Round 3 IAR/BAR/SOR 处置。
2. 复核当前 iOS 的 Archive/KBLite/Memory/Context/Echo/Notification 路径与 backend routes/stores/timers/provider adapters，建立 current → target → migration 映射。
3. 机器检查 Work Item ID 唯一、16 字段完整、依赖无悬空、Stage 1 不依赖 Optional package、所有 cutover 有 gate/rollback。
4. 运行 Product V4 architecture/review/link/invariant checks、Roadmap 结构检查和 `git diff --check`。
5. 由 Round 4E 再做 FR/DR/finding/CR 全量追踪；由 Round 5 独立复审是否存在第二 Authority、过度设计或不可执行任务。

## Risks

- Archive、KBLite、Memory 与 Context 当前职责重叠，若按文件拆任务会复制 Authority；必须按业务事实生命周期拆分。
- Timer/notification/provider callback 已有多条路径，直接替换会丢 effect；先写 outbox/receipt shadow，再 drain 旧 timer。
- `EchoViewController` 体量较大，一次重写会破坏已对齐 UI 和真机链路；只允许按 port/adapter/coordinator 渐进抽取。
- Stage 0 尚为计划态，Stage 1 可以完成设计和 fake/shadow 实现顺序，但 production cutover 必须受 Stage 0 exit gate 阻断。

## Assumptions

- 本轮产出可执行路线图，不修改生产代码、不部署、不宣称真机或 Provider 完成。
- 基线继续使用 iOS `8a1922b` 与 backend `4c0538b`；后续代码变化需重新执行证据漂移检查。
- Family/Care/TimeLetter 当前只作为已有壳层与异步 effect 样例，不在 Round 4C 创建新的公开产品 package。
- Round 4D 负责 Publication、Voice/DH 与组合迁移，Round 4E 负责全量追踪与路线图 checker。
