# 跨仓库知识治理组合 Gate 与交付证据

## Problem Definition

后端治理 builder、Archive 来源级联事务和 iOS consumer 已分别实现，但现有 release QA 尚未把四类动作、owner/revision/change-feed、Context 过滤、iOS response/outbox/generation gate 串成稳定回归入口。Task 16 文档也尚未从计划态更新到实际完成状态。

## Proposed Solution

在后端新增可重复的知识治理与来源级联 smoke runner，复用现有 unittest/fake Postgres 证据覆盖 confirm、reject、correct、deleteSource、Archive owner 冲突、组合事务、Context 过滤与 change feed。iOS 将 governance model/client/outbox/coordinator guard 接入 release QA package 的轻量检查；新增 `RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 组合开关执行后端 smoke 和完整 iOS 治理 gate，默认公开 MVP 回归不依赖隐藏治理 UI。最后运行两仓库全量非真机验证、workspace Simulator 和 generic iPhoneOS 构建，并更新 canonical 架构、Task 16、状态文档及 Closure 证据。

## Acceptance Criteria

- 后端 runner 一键覆盖四类治理、owner 权限、revision conflict、幂等、change feed、Archive 来源级联和 rejected/superseded Context 过滤。
- iOS release QA package 默认执行治理模型/client/coordinator 轻量 guard，不出现公开治理入口。
- `RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 可选组合 gate 同时运行后端治理 smoke、iOS outbox/three-way/governance smoke。
- 后端全量内存/fake Postgres 验证通过；不要求本机未配置的真实 Postgres。
- Simulator Debug workspace build、generic iPhoneOS 无签名 build、两仓库 `git diff --check` 通过。
- canonical 设计、Task 16 checklist 和新增状态文档准确记录已完成能力、已验证证据和未纳入范围。
- iOS 与后端分别形成范围清晰的本地提交，不推送、不部署。

## Verification Plan

1. 运行新增后端治理/source cascade smoke runner。
2. 运行所有 governance iOS model/static/outbox/coordinator 和 three-way/proposal/context smoke。
3. 运行 release QA package check 与开启 `RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 的 release regression。
4. 运行后端既有全量验证入口以及 fake Postgres tests。
5. 运行 DreamJourney workspace Simulator Debug 和 generic iPhoneOS 无签名构建。
6. 运行两仓库 `git diff --check`、检查公开 UI 关键词/入口 guard，并审阅最终 diff。

## Risks

- release regression 现有开关较多，组合 gate 必须保持可选，避免日常公开 MVP 回归依赖后端环境。
- 后端默认测试可能读取真实 Postgres DSN；runner 应显式选择内存与 fake Postgres 测试，不把环境缺失误判为代码失败。
- Closure/Lodestar 自动同步文件会产生较大文档 diff，提交时需与功能代码分组审阅。

## Assumptions

- 本轮不连接真机、不部署线上服务、不增加公开知识治理 UI。
- CocoaPods workspace 与腾讯 SDK 已在当前本地环境可用于通用 iOS 构建。
- 真实 Postgres deployed smoke 留给后续部署验收，本任务以 deterministic memory/fake Postgres 为准。
