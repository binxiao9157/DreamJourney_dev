# P001: 建立统一 lifecycle generation 与异步隔离

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
Echo 的 session、runtime capability、voice capability、realtime config、synthesis、PCM 和延迟恢复分别使用局部 guard，角色切换或页面生命周期变化后仍可能有旧回调生效。

## Success Criteria
- 生命周期协调器可以签发、推进并校验带 context 的 generation token。
- 角色切换和页面退出会失效旧 generation。
- session/capability/realtime/synthesis/PCM/resume 异步路径执行前校验当前 token。
- 旧 token 的回调不会安装 runtime、改变 audio owner、发送音频或打开麦克风。
- 纯状态与静态检查通过。

## Subproblems
- P004: 补生命周期协调器纯状态回归

## Results
- R000

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P001/README.md
- Ticket T001: problems/P000/children/P001/tickets/T001.md
- Result R000: problems/P000/children/P001/results/R000.md
- Check C000: problems/P000/children/P001/checks/C000.md
- Check C002: problems/P000/children/P001/checks/C002.md

## Follow-ups
- P004: 补生命周期协调器纯状态回归
