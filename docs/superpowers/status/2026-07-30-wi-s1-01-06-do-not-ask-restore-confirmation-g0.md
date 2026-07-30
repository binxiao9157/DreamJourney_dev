# WI-S1-01-06 Do-Not-Ask Reopen Confirmation G0/G1

## Scope

This local-only closure adds one QA-only, value-free orchestration signal:
`userReopenedDoNotAskTopic`.

Backend implementation baseline: `DreamJourneyBackend` `main@ef4527a`.

When an existing interview session has the persisted `doNotAsk` boundary and
the signal is `true`, the read-only orchestration response returns:

- `action=clarify`
- `reasonCode=doNotAskRestoreConfirmationRequired`
- `nextSessionState=paused`
- `maxFollowupCount=0`

The read does not restore the session, remove the boundary, create a Candidate,
or write a MemoryVersion. The existing explicit restore command remains the
only state-changing recovery path.

## Compatibility Boundary

The original five boolean signals remain required. The new signal is optional
for older callers and defaults to `false` when omitted. Unknown fields and
non-boolean values still fail closed with
`ownerTruthInterviewOrchestrationInvalid`.

## Validation

- Backend focused suites: 21 tests passed, including legacy five-field input,
  persisted `doNotAsk` state, and no automatic restoration.
- Backend full gate: `./scripts/verify_backend.sh` passed, including 1,558
  unit tests and all configured contract/smoke gates.
- iOS `DreamJourneyTests/OwnerTruthContractsTests`: 85 passed.
- iOS default generic simulator Debug build passed:
  `tmp/visual-qa/product-v4/DerivedDataOwnerTruthDoNotAskRestoreDefault`.
- `git diff --check` is required before the paired commits.

## Limits

This is not natural-language topic detection, a public UI flow, PostgreSQL
evidence, deployment evidence, provider behavior, or true-device evidence.
It carries no topic text, session identifier, source content, candidate data,
memory data, or provider data in the client signal.
