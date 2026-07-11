# P002: 实现 generation 绑定的 App Group 发布与账号生命周期

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
当前 `KBLiteManager.save()` 和 `switchUser()` 可并发覆盖同一共享文件，登出/切换没有 active owner 撤销、文件删除和 timeline reload，旧用户延迟保存可能重新暴露内容。

## Success Criteria
- 独立 snapshot store 维护 active owner digest 与 active generation。
- publish 只接受当前 owner/generation，并使用原子写入和首次解锁后文件保护。
- switch/login 在发布新快照前使旧快照失效；logout 先撤销 owner 再删除文件。
- publish、clear 和失败清理都触发指定 Widget kind reload。
- `KBLiteManager` 移除旧无条件导出并接入 store；旧 generation 发布有模型/静态证据证明被拒绝。

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
