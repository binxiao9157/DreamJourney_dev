# P025: Round 3A2：系统上下文、部署单元与后端模块边界

Status: done
Parent: P020
Root: P000
Source Ticket: T018 (split)
Source Check: none
Package: problems/P000/children/P003/children/P020/children/P025
Body: problems/P000/children/P003/children/P020/children/P025/README.md
Ticket(s): T020

## Problem
后端已有 58 个路由和 18 张表，但 main/PostgresStore 与 JSONB 聚合承担过多责任，需要定义模块化单体和 worker/object/provider 边界，同时避免过早微服务化。

## Success Criteria
- 定义 iOS/API/worker/Postgres/object storage/provider 的系统上下文、信任边界和部署单元。
- 后端核心与可选模块有职责、拥有数据、commands/queries/events 和允许依赖。
- 至少 12 个当前后端服务/route/store 组件有迁移分类。
- 明确近期不引入微服务、Redis、专用向量库和通用 Agent runtime 的进入证据。
- Owner 核心在关闭可选模块/provider 时仍可独立运行。
- 该问题属于 T018，因为它负责服务端责任和运行拓扑。

## Subproblems
- P026: Round 3A2a：后端现状与部署证据审计
- P027: Round 3A2b：后端目标拓扑与模块边界

## Results
- R019

## Latest Check
C019

## Bodies
- Problem: problems/P000/children/P003/children/P020/children/P025/README.md
- Ticket T020: problems/P000/children/P003/children/P020/children/P025/tickets/T020.md
- Result R019: problems/P000/children/P003/children/P020/children/P025/results/R019.md
- Check C019: problems/P000/children/P003/children/P020/children/P025/checks/C019.md

## Follow-ups
- none
