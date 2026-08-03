# Round 3 目标架构与增量迁移方案

## Problem Definition

当前 iOS/后端已经形成 Archive、KBLite、Echo、Voice/DigitalHuman、Family/Care/TimeLetter 和大量 QA gate，但缺 Source/Candidate/Confirmed Memory/Conversation authority、typed schema、对象存储和统一 Job/Outbox。目标架构必须补齐权威模型，同时保护现有用户数据、公开 UI 和稳定 runtime，不能按新术语重建两个平行系统。

Round 2 只授权推荐目标、ADR 备选和可逆迁移设计；39 项 Decision 中多数未 E2 确认，因此 Round 3 不关闭身份、地域、provider、Publication/Visitor 或恢复期限等产品选项，也不执行生产迁移。

## Proposed Solution

1. 采用模块化单体后端 + Postgres + 私有对象存储 + 独立 worker 的近期架构；不预设微服务、专用向量库、Redis 或通用 Agent 编排。
2. 定义 iOS AppShell/Feature/Domain/Repository/Infrastructure/Runtime 边界，在现有 UIKit 和 coordinator 上渐进抽取，不进行 UI 框架重写。
3. 定义后端 Identity/AuthZ、Persona、Source/Ingestion、Memory Review、Projection、Conversation/Context、Data Rights/Audit/Jobs 模块；Publication/Visitor、Voice/DH、Family/Care/TimeLetter 作为可选模块或 provider ports。
4. 为核心对象设计 typed relational schema、稳定 ID、owner/persona、version、state、policy、evidence、outbox 和 receipt；JSONB 仅保存版本化扩展 metadata。
5. 定义 `/v2` typed API、ServerCommandContext、幂等/expectedVersion、分页、错误码和兼容 adapter；客户端不提交可信 principal/time/policy。
6. 定义 Job/Outbox、object storage、processor/provider ports、observability 和 data-rights machine authorization。
7. 采用“新 authority 单写 → outbox 生成 Projection/legacy compatibility → shadow 双读比较 → per-owner authorityEpoch 切换”；禁止双 authority 写入。
8. 为 legacy KBLite/Archive/voice/family/timeLetter 分别给出 inventory、映射、quarantine、cutover、rollback 和 retire 条件。
9. 把所有开放 Decision 映射成 ADR 选项和配置扩展点，不在 schema 中偷做产品决定。
10. 进行 iOS、后端和安全/运维三类独立审查，修正 blocker 后再进入 Round 4。

## Acceptance Criteria

- Product Spec 包含可独立阅读的目标系统上下文、iOS/后端模块图、data authority、schema、API、jobs、provider ports、安全和迁移章节。
- 每个核心对象都有 authority table、ID/owner/version/state、删除/审计责任和当前模型映射。
- 当前模块被标为保留、适配、兼容投影、隔离/后置或退役，且不要求大规模重写。
- `/v2` 与现有 API/客户端兼容方案、错误/幂等/并发/分页合同明确。
- legacy migration 不丢 Owner 决定，也不把缺 receipt/source 的 KBLite confirmed 自动升级。
- rollback 不把 legacy 恢复成 authority；生产切换按 owner/cohort 且有 kill switch。
- Publication/Visitor、Voice/DH、Family/Care/TimeLetter 保持独立模块和默认关闭策略。
- 至少两类独立架构复审无未处理 blocker/high。
- Product V4 checks、架构一致性检查、链接和 `git diff --check` 通过。

## Verification Plan

1. 建立 architecture contract 静态检查，验证模块、表、API、迁移阶段、Decision/FR 引用和禁止模式。
2. 用 Owner 创建/审核/问答/纠正/导出/删除六条 sequence 验证 authority 与 transaction boundary。
3. 用旧客户端、legacy missing receipt、重复 command、迟到 provider callback、rollback 和账号删除恢复做失败模式演练。
4. 独立 reviewer 分别检查 iOS 可迁移性、后端数据/接口和安全/运维。
5. 运行 Product V4 两项检查与 `git diff --check`。

## Risks

- 目标 schema 过度完整，路线图无法按小闭环增量落地。
- 为兼容旧客户端形成永久双 authority 或双写。
- 把未确认产品选项固化成数据库约束。
- 过早引入 Redis/vector/microservices，增加成本和一致性问题。
- 数据权利 job 或 provider callback 获得过宽 machine 权限。

## Assumptions

- 当前百级种子阶段优先模块化单体和 Postgres。
- 新 authority 可先 shadow/QA-only，不要求本轮修改生产业务代码。
- Round 4 再把架构切成逐项可执行任务、估算和验收 artifact。
