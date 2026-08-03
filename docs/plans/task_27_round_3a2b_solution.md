# Round 3A2b 后端目标拓扑与模块边界方案

## Problem Definition

后端现状已确认是单 FastAPI app、跨域 `PostgresStore`、JSONB 聚合和 host timer。需要在保留现有部署与 API 兼容面的同时，定义可以真正约束数据所有权、事务和可选能力依赖的模块化单体，而不是只重命名目录或提前拆微服务。

## Proposed Solution

1. 推荐部署为同仓库/同镜像的 API 与 Worker 两个进程、一个 Postgres、一个私有对象存储；不把 Redis、独立向量库或通用 Agent runtime 作为近期依赖。
2. 定义 12 个逻辑模块：Identity/AuthZ、Persona/Consent、Source/Ingestion、Memory Review/Authority、Projection/Retrieval、Conversation/Context、Data Rights/Audit、Jobs/Notification，以及可选 Publication/Visitor、Voice/Digital Human、Family/Care、Time Letter。
3. 每个模块定义拥有的表/对象、commands、queries、events、允许依赖和禁止跨域写入。
4. 所有 HTTP request/response 通过 typed `/v2` contract；现有 58 条路由作为兼容 facade 调 application command/query，不再直接访问万能 store。
5. API/worker 使用连接池和每请求/每 job 事务；跨模块副作用通过 transactional outbox、job lease、idempotency key 和 receipt 完成。
6. 外部 provider 仅由后端 adapter 调用，credential 不下发 iOS；provider output 只能形成 Candidate、GeneratedAudio 或 runtime receipt。
7. Owner 核心最小运行集为 Identity、Persona、Source、Memory、Projection、Conversation、DataRights/Jobs；关闭所有可选域/provider 时仍能完成文字 Capture → Review → Owner QA → Correction。
8. 明确现有组件的渐进迁移分类和实施顺序，保留 KB receipt/revision、DH lease、refresh rotation 等有效控制。

## Acceptance Criteria

- 系统上下文包含 API、worker、Postgres、私有对象存储、iOS 与 provider 的信任边界。
- 至少 8 个模块记录职责、拥有数据、commands/queries/events、允许与禁止依赖。
- 至少 12 个现有组件映射到目标模块和迁移动作。
- 明确 Owner 核心最小运行集、可选模块关闭行为和 fallback。
- 明确微服务、Redis、专用向量库、通用 Agent runtime 的重新评估证据。
- 提供不重写现有 API/UI 的渐进迁移与回滚顺序。

## Verification Plan

1. 用 Owner Truth Loop 验证模块和部署单元责任是否闭合。
2. 用账号删除、TimeLetter dispatch、Voice synthesis、Digital Human lease 检查跨模块事务与 provider 边界。
3. 逐项对照 P026 的 blocker/high，确认目标边界有明确处理位置，不用抽象名称掩盖风险。
4. 检查关闭 Voice/DH/Family/Care/TimeLetter/provider 后 Owner 核心仍可运行。
5. 运行 Product V4 文档、后端证据和 `git diff --check`；再交独立架构 reviewer 复核。

## Risks

- 只拆 Python 文件却继续共享万能 store，形成名义模块化。
- 过早要求所有旧路由切换 typed schema，造成大爆炸迁移。
- outbox/job 被设计成通用工作流平台，超出当前业务复杂度。
- 为未来向量检索或 Agent 预留过多抽象，拖慢 Stage 0/1。

## Assumptions

- 近期保留 FastAPI、Postgres、容器部署和现有域名。
- Round 3B 负责字段级 schema、API/AuthZ、outbox/job/provider 合同；本轮只固定边界与责任。
- 本轮不修改后端生产代码或服务器。
