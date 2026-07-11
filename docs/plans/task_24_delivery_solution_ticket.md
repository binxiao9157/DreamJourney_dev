# 完成 Task 24 跨仓库交付与线上验收

## Problem Definition

后端与 iOS 合同已分别实现，但尚缺统一 gate、最终构建、版本提交推送、后端部署和真实 Postgres 证据。

## Proposed Solution

复核现有 cross-repository gate 已消费新增测试，更新 Task/Lodestar 和部署状态文档；运行后端验证、知识专项 gate、默认 release regression、Simulator/generic iPhoneOS 构建与 diff check。随后分仓库提交推送，按既有安全部署流程更新后端，在线验证 schema、正常分页、snapshot、结构化 410 和 compaction dry-run，不在生产自动 apply 删除。

## Acceptance Criteria

- 本地后端测试、知识 gate、release regression、两个 iOS 构建通过。
- Task 24 文档、状态和 QA 命令可由同事复用。
- 两仓库提交推送且工作区干净。
- 后端部署版本与远端提交一致，健康检查和线上 Postgres knowledge smoke 通过。
- 线上 maintenance 仅 dry-run，并保留报告；不做真机。

## Verification Plan

按 local tests -> builds -> commit/push -> deploy -> deployed smoke -> dry-run report 顺序执行，任一步失败先修复再继续。

## Risks

- 部署环境或 SSH 外部状态可能暂时不可用。
- compaction apply 是破坏性操作，本任务线上只做 dry-run。

## Assumptions

- 既有私密部署访问文档仍有效。
- 当前分支允许推送，后端部署使用 main。
