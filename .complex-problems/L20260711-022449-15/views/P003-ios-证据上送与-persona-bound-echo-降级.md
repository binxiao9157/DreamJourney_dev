# P003: iOS 证据上送与 Persona-bound Echo 降级

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T003

## Problem
iOS 将 user/assistant 拼成字符串上送，精提取节流水位可能长期退化；family persona 的 Context 失败会读取 viewer 私有 KBLite，Context 响应也未完整绑定当前 gate。

## Success Criteria
- iOS 上送 indexed structured turns 和 sourcePolicy，并保留旧服务端兼容策略。
- 独立后端精提取水位确保频率策略不会被本地 sessionCount 永久推迟。
- 本地生成只包含 high/confirmed fact。
- local KBLite fallback 只允许 personal/self；family persona 失败使用空知识上下文。
- Context Packet user/persona/digital-human identity 不匹配时拒绝提交生成。
- 纯 Swift model/static smoke 覆盖个人、家庭、错身份和置信度分支。

## Subproblems
- none

## Results
- R002

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T003: problems/P000/children/P003/tickets/T003.md
- Result R002: problems/P000/children/P003/results/R002.md
- Check C002: problems/P000/children/P003/checks/C002.md

## Follow-ups
- none
