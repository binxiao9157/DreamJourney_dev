# P005: Receipt 历史转换与隐私维护兼容合同

Status: done
Parent: P002
Root: P000
Source Ticket: T003 (split)
Source Check: none
Package: problems/P000/children/P002/children/P005
Body: problems/P000/children/P002/children/P005/README.md
Ticket(s): T004

## Problem
需要一个不依赖数据库的安全转换层，把 legacy full receipt result 最小化为 P001 compact envelope，并让现有 privacy maintenance 正确认识 compact V2 receipt，避免部署后维护任务失效。

## Success Criteria
- 纯函数转换 legacy full result，保留原始 revision、mutation schema、兼容标记和 ID-only governance summary。
- 转换结果不含 graph、mutation upserts、实体正文或重复身份字段。
- 已是 compact envelope 时幂等返回，不二次变化。
- 异常 result 明确报错，不猜测生成 envelope。
- Privacy maintenance 对 compact V2 envelope 原样保留 result 和 payload hash，不要求 mutation；legacy full V2 行为不变。
- 单测覆盖四类 operation、正文清除、幂等、异常输入和 privacy compatibility。

## Subproblems
- none

## Results
- R002

## Latest Check
C003

## Bodies
- Problem: problems/P000/children/P002/children/P005/README.md
- Ticket T004: problems/P000/children/P002/children/P005/tickets/T004.md
- Result R002: problems/P000/children/P002/children/P005/results/R002.md
- Check C003: problems/P000/children/P002/children/P005/checks/C003.md

## Follow-ups
- none
