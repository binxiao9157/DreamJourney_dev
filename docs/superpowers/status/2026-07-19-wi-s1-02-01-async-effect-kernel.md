# WI-S1-02-01 Async Effect Kernel

Date: 2026-07-19

## Completed Scope

This slice adds typed client/server coordination contracts for future async
effects. It does not alter public UI, start a worker, schedule a timer, invoke
a provider, or migrate TimeLetter/Echo behavior.

- Backend exposes a disabled `asyncEffect` runtime descriptor.
- iOS decodes `AsyncEffectRuntimeCapability` and value-free
  `AsyncEffectReceiptSummary` records.
- The client model explicitly keeps local timers and notifications separate
  from server completion.
- Backend migration `0013_async_effects_kernel` provides the future durable
  outbox/job/inbox/receipt schema while all runtime flags remain false.

## Verification

G0 completed locally:

- `Scripts/QA/product-v4/run-async-effect-kernel-gate.sh`
- `Scripts/QA/product-v4/run-ios-test-foundation-gate.sh`
  - SwiftPM: 8 tests passed.
  - generic iPhoneOS `build-for-testing`: passed.
- Backend async-effect contract and repository tests passed.
- `scripts/verify_backend.sh` passed (620 backend tests).
- `git diff --check` passed in both repositories.

G1 is not applicable: no user-visible UI or simulator interaction changed.

G2 completed against the deployed backend:

- implementation commit `89e6656`, smoke-guard correction `0be58a6`;
- server migration head `0013` is ready;
- public `/ready` reported database/schema/auth/incident ready;
- `scripts/run-backend-async-effects-postgres-smoke.sh` passed from the
  deployed API container with concurrent idempotency, caller-UoW rollback,
  terminal-state guard, append-only receipts, and PII-column checks.

## Explicit Boundaries

The repository is only obtainable through an active backend UoW. It does not
commit on its own. Wiring an aggregate and its outbox into the same transaction
is `WI-S1-02-02`; worker claims, heartbeats, attempts, and scheduler execution
start in `WI-S1-02-03`.
