# P000: Task 25：P1 Echo Trace 账号隔离与登出清理

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_25_p1-echo-trace-account-isolation.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 25：P1 Echo Trace 账号隔离与登出清理

## Success Criteria
- A 账号记录无法被 B 账号读取或导出。
- 切换 A -> B 后 A 数据被清理；登出后四类 store 均为空。
- 登出/切换后到达的 A 账号异步写入被拒绝，不会重建旧数据。
- 冷启动恢复登录态后只激活该账号；legacy 全局 key 被安全清除而非跨账号迁移。
- QA smoke 使用显式 owner，不破坏现有 Echo trace/evidence 导出。
- 相关 model/static checks、release regression、Simulator 和 generic iPhoneOS 构建通过。

## Subproblems
- none

## Results
- R000

## Latest Check
C000

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R000: problems/P000/results/R000.md
- Check C000: problems/P000/checks/C000.md

## Follow-ups
- none
