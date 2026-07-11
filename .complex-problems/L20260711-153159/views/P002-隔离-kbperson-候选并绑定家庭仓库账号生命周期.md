# P002: 隔离 KBPerson 候选并绑定家庭仓库账号生命周期

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
FamilyRepository 把 KBPerson 直接追加到成员列表，无 active owner/generation，启动 mock、迟到响应和全局 mode/voice overrides 可能跨账号残留或提升权限。

## Success Criteria
- KBPerson 只进入独立 candidate 集合，不进入 getAll/accepted member。
- FamilyRepository 绑定 active owner/generation，登录、切换、登出清理旧状态。
- refresh/invite 回调验证 owner 与 generation，迟到响应不合并。
- 后端 refresh 对当前 owner 使用权威替换，而不是保留已消失旧成员。
- mode/voice overrides 按 owner 分区；无 owner 不读写。
- 启动 mock 不进入公开仓库，UIQA fixture 显式标记。

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
