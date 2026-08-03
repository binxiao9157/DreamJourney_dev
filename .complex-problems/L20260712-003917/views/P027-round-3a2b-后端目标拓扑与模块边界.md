# P027: Round 3A2b：后端目标拓扑与模块边界

Status: done
Parent: P025
Root: P000
Source Ticket: T020 (split)
Source Check: none
Package: problems/P000/children/P003/children/P020/children/P025/children/P027
Body: problems/P000/children/P003/children/P020/children/P025/children/P027/README.md
Ticket(s): T022

## Problem
在现状证据基础上，需要定义保留 FastAPI/Postgres 的模块化单体、同仓库 worker、私有对象存储和 provider adapter 边界，并证明关闭可选模块后 Owner 核心仍可独立运行。

## Success Criteria
- 定义 iOS、API、worker、Postgres、对象存储和外部 provider 的系统上下文、信任边界与部署单元。
- 至少 8 个后端模块有职责、数据所有权、commands/queries/events、允许和禁止依赖。
- 至少 12 个现有组件映射为保留、适配、拆分、兼容、后置或退役。
- 明确 Owner 核心最小运行集和可选模块/provider 关闭行为。
- 明确不立即引入微服务、Redis、专用向量库和通用 Agent runtime，并定义重新评估证据。
- 给出可渐进实施、验证与回滚的顺序，不要求一次性目录或数据库重建。
- 该问题属于 T020，因为它将现状证据转化为可执行服务端架构。

## Subproblems
- none

## Results
- R018

## Latest Check
C018

## Bodies
- Problem: problems/P000/children/P003/children/P020/children/P025/children/P027/README.md
- Ticket T022: problems/P000/children/P003/children/P020/children/P025/children/P027/tickets/T022.md
- Result R018: problems/P000/children/P003/children/P020/children/P025/children/P027/results/R018.md
- Check C018: problems/P000/children/P003/children/P020/children/P025/children/P027/checks/C018.md

## Follow-ups
- none
