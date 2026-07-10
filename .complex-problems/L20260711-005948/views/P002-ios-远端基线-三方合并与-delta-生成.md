# P002: iOS 远端基线、三方合并与 Delta 生成

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
iOS 当前只保存 revision/fingerprint，收到远端快照后无法判断本地与远端各自相对哪个基线变化，因而不能可靠处理删除和同实体双改。需要按用户持久化 remote base，并用纯数据三方合并生成 v2 delta。

## Success Criteria
- 每用户 remote base 与 revision 独立持久化，用户切换和旧回调不能跨用户读取或写入。
- base/local/remote 按类型和实体 ID 三方合并：单侧变化不丢失，双方同改确定性 local-wins 并输出 QA conflict summary。
- local-only/旧无元数据实体始终留本机，不进入 upserts，也不受远端 tombstone 删除。
- 由 base/local 生成 upserts/tombstones；v2 成功后更新 base，旧后端可降级 v1。
- 纯模型/静态检查、模拟器或 generic build 通过，不改变公开 UI。

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
