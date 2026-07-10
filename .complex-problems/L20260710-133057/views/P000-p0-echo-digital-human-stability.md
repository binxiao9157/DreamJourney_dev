# P000: P0 Echo digital-human stability

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_07_p0-echo-digital-human-stability.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 Echo digital-human stability

## Success Criteria
- A callback created before a role/context switch cannot install a runtime, synthesize/play audio, send PCM, or reopen the microphone afterward.
- Echo owns at most one Tencent runtime and exposes one explicit audio owner at a time.
- User stop preserves the current Tencent session; page exit releases it.
- Backgrounding does not immediately consume/recreate sessions, but an expired grace lease closes the runtime.
- Returning before lease expiry keeps the provider view and does not auto-start the microphone.
- Quota exhaustion falls back immediately to ordinary Echo and does not retry automatically.
- Tap interruption clears provider work; only the current generation may restore capture.
- Non-device Phase 2 checks, simulator lifecycle smoke, digital-human/voice-clone combo gate, iOS build, and whitespace check pass.

## Subproblems
- P001: 建立统一 lifecycle generation 与异步隔离
- P002: 实现后台 session 宽限 lease
- P003: 收敛 session audio owner 打断恢复与配额 fallback

## Results
- R004

## Latest Check
C005

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R004: problems/P000/results/R004.md
- Check C005: problems/P000/checks/C005.md

## Follow-ups
- none
