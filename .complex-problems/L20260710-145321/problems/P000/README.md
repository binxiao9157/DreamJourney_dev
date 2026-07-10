# P0 Digital-human session lease and concurrency control

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_08_p0-digital-human-session-lease.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 Digital-human session lease and concurrency control

## Context

The backend currently returns a fresh `/digital-human/sessions` contract for every request without persisting ownership, reuse, release, heartbeat, or expiry state. iOS closes the Tencent runtime locally, but the backend cannot distinguish a current device session from an abandoned or competing session. This makes quota failures reactive and leaves stale asynchronous session responses able to consume logical capacity.

## Scope

- Persist safe digital-human lease metadata in memory and Postgres without storing Tencent credentials.
- Reuse the same active lease for the same user/device/persona/scene.
- Replace a prior lease owned by the same user/device when switching persona or lifecycle context.
- Reject a competing device when configured capacity is exhausted, with `409` and `retryAfterSeconds`.
- Add heartbeat, explicit release, TTL expiry, and idempotent release contracts.
- Expose lease capability through `/config/runtime`.
- Let iOS parse the lease, heartbeat while the current runtime is active, and release on role switch, page exit, background grace expiry, provider terminal failure, or stale session response.
- Preserve the lease when the user only stops the current conversation.
- Add backend tests, Postgres store tests, iOS static guards, and non-device smoke coverage.

## Out Of Scope

- True-device Tencent quota release timing.
- Tencent provider-side session termination API beyond the existing SDK `close()` call.
- Full-duplex VAD or product UI changes.
- Deployment to the production server in this task unless explicitly requested.

## Steps

- [ ] Add failing backend API/store and iOS contract guards.
- [ ] Implement memory/Postgres lease persistence and atomic capacity arbitration.
- [ ] Upgrade `/digital-human/sessions` and `/config/runtime`; add heartbeat/release endpoints.
- [ ] Add iOS lease models, client methods, heartbeat scheduling, stale-response cleanup, and lifecycle release calls.
- [ ] Add a combined non-device lease smoke and release regression switch.
- [ ] Run backend verification, Postgres smoke, iOS checks/build, simulator smoke, and `git diff --check`.
- [ ] Close the recursive ledger and record the true-device residual risk.

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

## Recursive Ledger

- Ledger ID: pending initialization.
- Current next action: initialize ledger.


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
