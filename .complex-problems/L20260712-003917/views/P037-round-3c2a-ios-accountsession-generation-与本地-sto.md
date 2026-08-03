# P037: Round 3C2A iOS AccountSession、Generation 与本地 Store 迁移

Status: done
Parent: P032
Root: P000
Source Ticket: T031 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P032/children/P037
Body: problems/P000/children/P003/children/P022/children/P032/children/P037/README.md
Ticket(s): T032

## Problem
当前本地用户、Keychain session、refresh waiter、Archive callback 和多类私有 store 没有统一 account generation；A 的晚到请求/refresh 可能覆盖 B，global key/目录可跨账号命中，TimeLetter draft 还可能提前同步。需要冻结一个可实现、可测试的 AccountSession/Lease/Store rollout 合同，同时保持现有 UIKit/Stitch UI。

## Success Criteria
- 定义 `AccountSessionActor` 和不可变 `AccountLease` 字段、CAS 与生命周期。
- 冷启动、登录、refresh、logout、switch、delete、前后台和 session revoke 顺序 fail closed。
- request/task/timer/callback 在发送、retry、解析、store commit 前校验 generation/session/epoch。
- 覆盖至少 12 类私有 store/runtime/cache 的 owner-scoped envelope、迁移、quarantine、清理和重建策略。
- TimeLetter/Archive 等 draft 在显式提交前保持设备本地，不生成后端 authority。
- 明确先建 XCTest target，再按域迁移 store/use case；视觉和导航不变。
- 至少 12 个账号竞态/升级/清理故障场景。
- 增加静态门禁并同步 Evidence Matrix。

## Subproblems
- none

## Results
- R028

## Latest Check
C028

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P032/children/P037/README.md
- Ticket T032: problems/P000/children/P003/children/P022/children/P032/children/P037/tickets/T032.md
- Result R028: problems/P000/children/P003/children/P022/children/P032/children/P037/results/R028.md
- Check C028: problems/P000/children/P003/children/P022/children/P032/children/P037/checks/C028.md

## Follow-ups
- none
