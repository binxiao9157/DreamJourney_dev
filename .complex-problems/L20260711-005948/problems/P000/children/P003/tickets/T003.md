# 知识 V2 跨仓库 QA 与交付收敛

## Problem Definition

后端 Mutation V2 与 iOS 三方合并已分别实现，但 release regression 尚未形成一个可重复的跨仓库门，现有状态文档也仍描述 v1 全量 graph 语义，后续维护者容易漏跑 tombstone 与冲突验证。

## Proposed Solution

扩展部署态 knowledge smoke，使其在真实后端依次验证 v1 seed、v2 upsert/tombstone、幂等、change metadata、409 与 Context 结果。将 iOS 三方合并 model smoke 纳入 release QA，并提供单一环境开关串起本地模型与部署后端检查。更新 Task 13 和统一知识管线状态文档，明确 v2 合同、运行命令、未部署状态及兼容边界。

## Acceptance Criteria

- 部署态 smoke 验证 tombstone 删除、同类型 upsert、v2 metadata、幂等和 stale revision。
- release regression 可通过一个明确开关运行知识 V2 组合 gate，默认不要求外部后端环境。
- release QA package 静态检查能发现模型 runner 或文档接入被移除。
- 文档准确列出两仓库提交、验证命令、部署要求和剩余风险。
- 两仓库工作树通过 `git diff --check`，后端全量验证和 iOS 构建通过。

## Verification Plan

- 运行后端 `verify_backend.sh` 与本地/部署等价 v2 smoke。
- 运行 iOS knowledge model、knowledge pipeline、release package checks。
- 运行 release regression 的知识 V2 组合开关（使用本地 FastAPI 或明确记录未部署线上验证）。
- 运行 iOS generic Simulator build。

## Risks

- 未部署 Task 13 后端前，公网环境无法通过 v2 deployed smoke；脚本必须默认关闭且给出明确配置错误。
- QA 脚本不得输出 access token 或知识正文。

## Assumptions

- 本轮允许提交本地两仓库，但未明确要求前不推送、不部署。
- 不做真机、公开 UI 或向量数据库改动。
