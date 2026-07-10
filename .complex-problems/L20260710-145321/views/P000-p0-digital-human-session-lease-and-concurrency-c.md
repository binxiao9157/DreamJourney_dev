# P000: P0 Digital-human session lease and concurrency control

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_08_p0-digital-human-session-lease.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 Digital-human session lease and concurrency control

## Success Criteria
- Repeating the same device/context request returns the same active session with `reused=true`.
- A role/context switch on the same device releases the previous logical lease and creates a new one.
- A second device above configured capacity receives a structured conflict and retry delay.
- Heartbeat extends only an active lease owned by the same user/device.
- Release is idempotent; TTL expiry frees capacity after an app crash or network loss.
- Stale iOS session responses are released rather than silently discarded.
- User stop does not release the session; page/context/background/provider terminal paths do.
- No Tencent credential is persisted in the lease store or returned by diagnostics.
- All non-device checks and builds pass.

## Subproblems
- P001: 后端数字人 Lease 持久化与并发仲裁
- P002: 完成 Session Lease API、iOS 消费与组合验收

## Results
- R001

## Latest Check
C003

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R001: problems/P000/results/R001.md
- Check C001: problems/P000/checks/C001.md
- Check C003: problems/P000/checks/C003.md

## Follow-ups
- P002: 完成 Session Lease API、iOS 消费与组合验收
