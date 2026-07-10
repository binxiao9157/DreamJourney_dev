# P0 知识证据完整性与 Context 隔离

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_14_p0-knowledge-evidence-and-context-isolation.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 知识证据完整性与 Context 隔离

## 背景

Task 12/13 已完成统一知识主链路、revision、Mutation V2、tombstone 和三方合并，但当前对话提取仍把 user/assistant 文本拼成普通 transcript 交给 provider；Context 和 iOS 本地 fallback 也没有统一执行事实置信度门禁。若不先收紧，AI 回复可能被重新当成用户事实，低置信事实也可能进入 Echo。

Canonical 设计：`docs/superpowers/plans/2026-07-11-product-knowledge-base-architecture-v2.md`。

## 固定合同

- `/kb/extract` additive 支持 `extractionSchemaVersion=2`、`sourcePolicy=userEvidenceOnly` 和 indexed structured turns。
- 只有 `role=user` 的 turn index 可以成为实体证据。
- provider 返回实体缺少有效 user turn index、引用 assistant/越界 turn 时必须过滤。
- response 增加不含正文的 `evidencePolicy` 计数摘要；旧 transcript 合同继续兼容。
- `KBFact.confidence` 只有 `high/confirmed` 可进入后端 generationContext 和 iOS 本地生成 fallback。
- 时间信件非收件人、未到期和无效 family/care viewer 的 Context 隔离必须有自动化回归。

## 范围

- 完成产品知识库架构与 PRD 设计文档。
- 后端 structured extraction 校验、provider prompt、post-filter 与策略摘要。
- 后端 Context KBLite confidence filter 和跨收件人隔离回归。
- iOS structured turns 上送和本地 confidence filter。
- 静态检查、后端 smoke、release regression、generic Simulator/iPhoneOS 构建。
- 分别提交 iOS/后端；未明确要求前不推送或部署。

## 不在范围

- 真实视觉 provider、真实语音/视频采集或真机验收。
- 公开知识治理 UI。
- 向量数据库、字段级 CRDT、全局 Postgres 连接池重写。
- 一次性完成 proposal、persona schema、change-feed compaction 等后续 P1。

## 步骤

- [x] 审计 PRD、iOS/后端现状和 Task 12/13 基线。
- [x] 固定产品知识库 canonical 架构与本任务合同。
- [ ] 实现并测试后端证据完整性和 Context P0 policy。
- [ ] 实现并测试 iOS structured turns 和本地生成门禁。
- [ ] 接入跨仓库 QA/release gate，运行非真机构建和回归。
- [ ] 更新状态文档、关闭 ledger、分别提交两仓库。

## 成功标准

- assistant-only 内容不能落成 KBLite 实体。
- provider 无来源或错误来源的实体会被过滤，且 response/日志不包含原始正文。
- low/medium fact 可留作候选，但不会进入 Echo 后端/本地生成上下文。
- 写给其他收件人的时间信件、无效家庭关系和错误 care viewer 不会进入 Context。
- Task 12/13 mutation、tombstone、三方合并与旧合同回归不退化。
- 后端全量验证、iOS release regression、generic Simulator/iPhoneOS 构建和 `git diff --check` 通过。

## 递归 Ledger

- 待初始化


## Success Criteria

- assistant-only 内容不能落成 KBLite 实体。
- provider 无来源或错误来源的实体会被过滤，且 response/日志不包含原始正文。
- low/medium fact 可留作候选，但不会进入 Echo 后端/本地生成上下文。
- 写给其他收件人的时间信件、无效家庭关系和错误 care viewer 不会进入 Context。
- Task 12/13 mutation、tombstone、三方合并与旧合同回归不退化。
- 后端全量验证、iOS release regression、generic Simulator/iPhoneOS 构建和 `git diff --check` 通过。
