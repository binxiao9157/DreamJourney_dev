# P003: Context Packet 驱动真实 Echo 生成

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T003

## Problem
Echo 当前异步请求 `/context/build` 只记录 trace，真实回复仍由 `DialogEngineManager` 注入 `query:nil` 最近摘要。需要把 query-scoped selected context 传入真实生成，同时避免增加不可控等待、旧回调污染和双重知识注入。

## Success Criteria
- final 用户回合使用 generation/turn token 绑定 Context Packet。
- 正常路径将 selected context 形成可控文本并传给回复生成。
- Context 请求超时/失败时使用本轮 query 的本地 KBLite 上下文。
- backend context 与旧 local recent summary 不会同时注入。
- Echo trace、数字人、声音复刻、等待回信状态机合同保持兼容。
- 非真机 smoke 能区分 backend context、local fallback 和 stale callback ignored。

## Subproblems
- P005: 后端生成上下文合同
- P006: iOS 每轮 Echo RAG 注入

## Results
- R004

## Latest Check
C004

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T003: problems/P000/children/P003/tickets/T003.md
- Result R004: problems/P000/children/P003/results/R004.md
- Check C004: problems/P000/children/P003/checks/C004.md

## Follow-ups
- none
