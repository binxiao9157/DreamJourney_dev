# P000: P0 Auth Session and Ownership Shadow Mode

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_09_p0-auth-session-ownership-shadow.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 Auth Session and Ownership Shadow Mode

## Success Criteria
- Login returns access/refresh tokens with explicit expiries and no raw token is persisted.
- Refresh rotates both tokens; a consumed refresh token cannot be reused.
- Logout revokes the session; revoked and expired access tokens fail.
- Legacy backend-token-only requests remain compatible.
- A valid user bearer resolves the expected principal.
- Ownership mismatch is observable in shadow mode but does not block the request.
- iOS stores tokens in Keychain rather than UserDefaults and sends the user bearer separately from the backend token.
- iOS retries one failed request after a successful refresh without recursive refresh loops.
- All non-device tests and builds pass.

## Subproblems
- P001: 后端 opaque auth session 合同
- P002: Principal 解析与 ownership shadow
- P003: iOS Keychain 消费与非真机 gate

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R003: problems/P000/results/R003.md
- Check C003: problems/P000/checks/C003.md

## Follow-ups
- none
