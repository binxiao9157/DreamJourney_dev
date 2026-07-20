# M0-B 知识维度与双推荐 G0 基础

日期：2026-07-21

## 本轮范围

后端 `main@c053d14` 新增只读、无 Provider 的 M0-B 领域策略；
`main@5d8c0d1` 让同一 Gate 可在生产 API 镜像内执行。

- 固定六个稳定维度：人生阶段、重要人物、关键选择、专业经验、价值观、愿望与边界。
- `DimensionProjection` 只接纳当前、已确认、可访问、未删除、未撤权、未争议且非 AI-only 的
  Memory 证据指针；其他证据不会提升覆盖。
- 选择器最多输出一条 `continuity`（接着聊）和一条 `breadth`（换个角度）。
- `breadth` 只能指向当前真实缺失的 facet；两条不能重复同一 thread/facet。
- `doNotAsk`、冷却期、连续两次跳过、敏感内容无近期同意、危机、越权、删除/撤权/争议、
  AI-only、未成年人风险与 persona runtime 依赖均在排序前硬过滤。
- 候选必须带 owner/vault 范围；与本次选择范围不一致时不会被选择。

所有输入和输出仅保存 opaque ID、模板 ID、reason code、policy version 与证据引用；不生成问题正文，
不复制记忆内容。

## 明确未做

- 未接现有 `MemoryVersion`、`ConversationThread`、Thread summary 或 `KnowledgeGap` 的真实持久化读取。
- 未创建数据库表、API、job/outbox、Provider 调用、Candidate、DecisionReceipt 或 Memory 写入。
- 未改变公开 Echo 全屏 UI，也未展示推荐、完成百分比或内部评分。
- 未接用户反馈、冷却期持久化、人生地图、语义搜索或推荐评测。

## 验证与部署

- `bash scripts/run-backend-owner-truth-knowledge-recommendation-gate.sh`：10 个领域单测和部署等价
  policy smoke 通过。
- `PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh`：1022 个后端单测及现有验证通过。
- `git diff --check`：通过。
- 已推送并部署后端 `main@5d8c0d1`；服务器 `/ready` 的 database/schema/auth/incident 全部 ready。
- API 容器内执行同一 Gate：通过。生产镜像不带 `tests/` 是刻意的镜像边界，因此容器运行
  dependency-free policy smoke；本地仍运行完整 unittest。

## Gate 与执行状态

这是 Phase 4 / M0-B Slice 4A、4B 的内部 G0 基础，不是完整 M0-B 交付，也不改变当前 active
`WI-S1-01-03` 的状态：

1. 当前 Registry 与 handoff 不增加 evidence item，已实现证据计数不因此变化。
2. 真实 Memory/Thread scoped projection、持久化 replay、API、G1 UIQA、G2 数据验证和 G4 公开
   产品 surface 仍需分别完成。
3. M0-A 的 public Echo surface Gate 仍未完成；现有全屏 Echo 不会因本轮发生视觉或公开行为变化。
