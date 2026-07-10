# P003: 收敛 session audio owner 打断恢复与配额 fallback

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T004

## Problem
已有停止与 audio owner 逻辑分散，延迟恢复缺少统一代际保护；配额错误仍会自动重试，存在旧角色声音或错误麦克风恢复风险。

## Success Criteria
- 同一 generation 最多绑定一个 runtime/session，并保持单一显式 audio owner。
- 用户停止/点击打断不销毁 session；页面退出或终止失败才释放。
- provider 完成和点击打断仅能为当前 generation 恢复麦克风。
- 中断后旧 PCM chunk/final 不再发送。
- 配额错误立即回普通 Echo，不自动恢复，不沿用上一角色声音。
- 扩展的静态、UIQA、组合 gate、构建和 diff check 通过。

## Subproblems
- none

## Results
- R003

## Latest Check
C004

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T004: problems/P000/children/P003/tickets/T004.md
- Result R003: problems/P000/children/P003/results/R003.md
- Check C004: problems/P000/children/P003/checks/C004.md

## Follow-ups
- none
