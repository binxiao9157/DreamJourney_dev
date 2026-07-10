# P002: 中间件集成与跨账号 FastAPI 验证

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
现有 auth middleware 只比较声明 userId 与 principal，不能在 enforce 模式中区分合法家庭委托和真实越权，也没有可供 QA 判断规则来源的授权证据。

## Success Criteria
- 策略评估器接入 middleware，未知路由继续走 Task 9 ownership fallback。
- 默认 shadow 不改变现有业务响应。
- 合法家庭/时间信件访问标记 delegated，enforce 测试不会误拦。
- 伪造 viewer 和普通用户调用 system-only 在 enforce 测试中返回 403。
- 新增安全的 policy/decision/reason 响应头并保持旧 ownership 响应头兼容。

## Subproblems
- none

## Results
- R001

## Latest Check
C001

## Bodies
- Problem: problems/P000/children/P002/README.md
- Ticket T002: problems/P000/children/P002/tickets/T002.md
- Result R001: problems/P000/children/P002/results/R001.md
- Check C001: problems/P000/children/P002/checks/C001.md

## Follow-ups
- none
