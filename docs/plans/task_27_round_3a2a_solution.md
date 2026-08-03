# Round 3A2a 后端现状与部署证据审计方案

## Problem Definition

在定义后端目标模块前，需要把当前 FastAPI 路由、store、models、provider、worker、脚本和部署方式形成可追溯证据。现有文档中的功能描述不能替代代码证据，尤其需要识别 `PostgresStore`、JSONB payload、owner/tenant scope 和 provider fallback 的真实耦合。

## Proposed Solution

1. 读取后端仓库结构、入口、路由注册、store/models、provider adapter、后台任务和部署文件。
2. 形成系统现状图：iOS → FastAPI → Postgres / object storage / external providers，以及 API 与 worker/cron 的当前关系。
3. 建立组件证据矩阵，至少覆盖 15 个当前 route/service/store/model/provider/script，记录文件路径、职责、所属产品阶段、主要依赖和风险。
4. 用 Owner Truth Loop、时间信件投递、声音复刻合成、腾讯数智人会话四条链路追踪当前责任。
5. 标记跨模块直接写、JSONB 聚合、ownership shadow/enforce、幂等、credential 和可选能力反向依赖问题。
6. 将审计结果写入 Product Spec 的后端架构章节“当前基线”部分，为 P027 的目标设计提供输入。

## Acceptance Criteria

- 当前部署单元和信任边界有文件证据。
- 至少 15 个后端组件完成证据映射。
- Owner 核心与三个代表性可选/异步链路完成责任追踪。
- 风险按 blocker/high/medium/low 区分，并说明由 Round 3B、3C 或路线图哪一阶段处理。
- 不把尚未读取或未运行的能力标记为已验证。

## Verification Plan

1. 使用 `rg --files`、路由注册和模型/store 定义交叉验证组件数量与文件路径。
2. 对 API route 数、Postgres 表/迁移、worker/cron/provider 配置作抽样复核。
3. 检查文档中的每个“当前实现”结论是否能回指代码或已有 smoke。
4. 运行 Product V4 文档检查与 `git diff --check`。

## Risks

- 仓库内存在历史兼容路径，容易把已废弃代码误判为主链路。
- 部署服务器配置不全部在 Git 中，需把未验证配置标成外部证据缺口。
- 路由数量和表数量可能随当前提交变化，必须记录审计 commit。

## Assumptions

- 后端基线仓库为 `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend` 的当前 `main`。
- 本轮只读审计后端，不修改后端生产代码或部署环境。
