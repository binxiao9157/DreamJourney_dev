# P020: Round 3A：系统上下文与 iOS/后端模块边界

Status: done
Parent: P003
Root: P000
Source Ticket: T017 (split)
Source Check: none
Package: problems/P000/children/P003/children/P020
Body: problems/P000/children/P003/children/P020/README.md
Ticket(s): T018

## Problem
现有 iOS ViewController/Services 和后端单文件路由承载了多个业务含义，需要在不重写 UIKit 或拆微服务的前提下定义清晰模块、依赖方向和当前代码迁移定位。

## Success Criteria
- 给出客户端、API、worker、Postgres、对象存储和 provider 的系统上下文与部署单元。
- 定义 iOS AppShell/Feature/Domain/Repository/Infrastructure/Runtime 层及允许依赖方向。
- 定义后端 Identity、Source、Memory、Conversation、Projection、DataRights/Jobs/Audit 和可选模块边界。
- 当前关键模块逐项标记保留、适配、兼容投影、后置或退役。
- 不引入无指标证明的微服务、Redis、专用向量库或通用 Agent runtime。
- 该问题属于 T017，因为数据合同和迁移需要稳定模块责任边界。

## Subproblems
- P024: Round 3A1：iOS 目标分层与当前模块迁移
- P025: Round 3A2：系统上下文、部署单元与后端模块边界

## Results
- R020

## Latest Check
C020

## Bodies
- Problem: problems/P000/children/P003/children/P020/README.md
- Ticket T018: problems/P000/children/P003/children/P020/tickets/T018.md
- Result R020: problems/P000/children/P003/children/P020/results/R020.md
- Check C020: problems/P000/children/P003/children/P020/checks/C020.md

## Follow-ups
- none
