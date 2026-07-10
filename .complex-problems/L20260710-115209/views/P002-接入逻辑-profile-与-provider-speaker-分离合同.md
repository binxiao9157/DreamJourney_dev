# P002: 接入逻辑 profile 与 provider speaker 分离合同

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
训练、状态查询和合成目前把客户端 `voiceProfileId` 直接当成火山 speaker ID；合成入口也没有验证 profile 所有权、状态和质量验收。

## Success Criteria
- pool 模式训练先分配 `providerSpeakerId`，API 和角色绑定继续使用逻辑 `voiceProfileId`。
- refresh 和 synthesis 内部解析 provider speaker。
- synthesis 只允许当前用户已持久化、ready、enabled、quality accepted 的 profile。
- disabled/deleted/failed/pending/cross-user profile 被拒绝。
- 旧 `voiceProfileId=S_...` profile 保持兼容。
- slot 状态随训练、refresh、disable/delete 更新，删除进入 retired。
- FastAPI 和 provider 单测覆盖上述合同。

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
