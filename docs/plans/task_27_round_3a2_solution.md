# Round 3A2 系统上下文、部署单元与后端模块边界方案

## Problem Definition

当前 FastAPI 后端已经承载登录、档案、上下文、回响、消息、家庭、时间信件、声音复刻和腾讯数智人等能力，但路由、`PostgresStore`、JSONB payload、provider adapter 与定时任务边界不够稳定。需要在不重建后端、不提前微服务化的前提下，定义可渐进治理的模块化单体与运行拓扑。

## Proposed Solution

1. 保留一个 FastAPI API 部署单元、同仓库 worker 进程、Postgres 和私有对象存储，provider 只通过后端 adapter 访问。
2. 定义系统上下文和信任边界：iOS 为不可信客户端；API 负责认证、授权、校验和同步命令；worker 负责异步任务；Postgres 为结构化 authority；对象存储保存媒体对象；外部 provider 不成为产品权威数据源。
3. 将后端划分为模块化单体：Identity/AuthZ、Persona、Source/Ingestion、Memory Review、Projection、Conversation/Context、Data Rights/Jobs/Audit，以及可选 Publication/Visitor、Voice/Digital Human、Family/Care/Time Letter。
4. 每个模块记录拥有的数据、公开 commands/queries/events、允许依赖与禁止跨模块直接写表规则；跨模块同步调用仅通过 application port，异步副作用使用 outbox/job。
5. 对当前 route/service/store/provider 组件建立迁移矩阵，分类为保留、适配、拆分、兼容、后置或退役。
6. 明确近期非目标：微服务、Redis、专用向量数据库、通用 Agent runtime；只有出现可量化吞吐、隔离、延迟或独立扩缩容证据后才重新决策。
7. 定义 Owner 核心最小运行集；Voice、数字人、家庭、关怀、时间信件和外部 AI provider 关闭时，Capture → Review → Owner QA → Correction 仍可运行。

## Acceptance Criteria

- 形成 iOS、API、worker、Postgres、对象存储、外部 provider 的系统上下文图、信任边界和部署单元说明。
- 至少定义 8 个后端模块的职责、数据所有权、commands/queries/events 和允许依赖。
- 至少 12 个当前后端 route/service/store/provider 组件完成迁移分类。
- Owner 核心最小运行集和可选模块关闭行为明确。
- 微服务、Redis、专用向量库、通用 Agent runtime 的暂缓原因与进入证据明确。
- 方案能在现有 FastAPI/Postgres 代码上渐进落地，不要求一次性目录重排或数据库重建。

## Verification Plan

1. 抽查当前 FastAPI 路由、store、models、provider 和脚本，确认映射基于真实代码而非概念命名。
2. 用 Owner 核心链路追踪每个部署单元和模块责任，确认不存在对 Voice/Family/AI provider 的强依赖。
3. 用时间信件到期投递、声音合成、数字人会话三个异步/外部场景检验 worker、outbox、provider adapter 和失败恢复边界。
4. 检查跨模块写入、JSONB payload、owner/tenant scope 和审计责任，记录必须在后续合同轮次解决的风险。
5. 由独立后端/架构 reviewer 评估模块是否过细、是否只是目录包装、是否遗漏现有部署约束。

## Risks

- 只移动文件而没有收敛数据所有权和事务边界，形成名义模块化。
- `PostgresStore` 继续成为跨模块万能入口，绕过 authorization 与 audit。
- 为未来能力预设过多抽象，拖慢 Owner 核心交付。
- worker 与 API 同时处理同一任务时出现重复副作用，需要后续 outbox/idempotency 合同约束。

## Assumptions

- 本轮只更新目标架构成果物，不重排后端生产代码。
- 现有 FastAPI、Postgres、容器部署和公开 API 合同继续作为增量迁移基线。
- 数据/API/授权/job 的字段级合同在 Round 3B 细化，本轮只固定模块所有权与运行拓扑。
