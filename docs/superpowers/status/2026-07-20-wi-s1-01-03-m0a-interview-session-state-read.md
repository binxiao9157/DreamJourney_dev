# WI-S1-01-03 M0-A Interview Session State Read

## Scope

This evidence records an additive, QA-only read boundary for the existing
private `ConversationThread` / `InterviewSession` state. It is a preparation
step for the M0-A natural-input UI slice, not a public Echo feature.

The backend endpoint is:

```text
GET /v2/vaults/{vault_id}/interview-sessions/{session_id}/state
```

It is default-off, omitted from OpenAPI, requires the existing Owner Truth QA
header plus an authenticated owner session, and returns `Cache-Control: no-store`.
The response exposes only state, boundary, version/fence counters, fatigue and
pending-review presence. It excludes conversation content, identifiers not
needed by the caller, Sources, Candidates, DecisionReceipts, MemoryVersions,
provider output and digital-human state.

## Backend Evidence

- Feature commit: `DreamJourneyBackend@dffb6c3`
- Route-smoke alignment: `DreamJourneyBackend@f7c7dab`
- Local verification: targeted endpoint tests, full backend unittest suite
  (`996` tests), `scripts/verify_backend.sh` and `git diff --check` passed.
- Production-like Postgres deployment: `main@f7c7dab`.
- Deployment verification: `/ready`, schema `0034` verification,
  `backend-owner-truth-conversation-postgres-smoke.py` and the 96-route
  authentication smoke all passed.

No server credential or `.env` value was read, changed or committed. The
server QA flag remains default-off.

## Boundary Status

- G0: value-minimized, owner-only read contract verified.
- G2: deployed and verified against isolated Postgres smoke and the deployed
  route-authentication contract.
- G1: scoped QA-only iOS consumer verified. The client captures the current
  `AccountLease`, rejects stale account callbacks, parses the typed envelope,
  and is reachable only through the DEBUG/UI-QA launch scenario
  `DJRunOwnerTruthInterviewSessionStateSmoke`.
- Public Echo UI, user-visible interview UI, MemoryVersion creation, provider
  generation and runtime digital-human integration remain untouched.

## iOS QA Consumer Evidence

- iOS contract and lease-bound use case: `OwnerTruthInterviewSessionState` /
  `OwnerTruthInterviewSessionStateUseCase`.
- Transport: `DreamJourneyBackendClient.fetchOwnerTruthInterviewSessionState`;
  it sends the existing owner-truth QA header only when the QA feature gate is
  explicitly enabled.
- Simulator contract tests: `OwnerTruthContractsTests` ran 44 tests with zero
  failures, including typed decode, stale callback discard, and gate-disabled
  fail-closed coverage.
- Simulator UIQA smoke: `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-session-state-smoke.sh`
  passed on 2026-07-20. Its result is `active / open / normal`, with no pending
  review batch and `stateRendered=true`.
- Screenshot: `tmp/visual-qa/product-v4/owner-truth-interview-session-state-smoke/20260720-230850/01-owner-truth-interview-session-state.png`.

The QA view explicitly states that it neither renders conversation content nor
creates memories, candidates, or review receipts. It is not linked from the
public Echo, archive, or profile UI.

## Next Increment

Select the next M0-A product-surface boundary from the approved execution
plan. Any natural-input UI work must preserve the existing full-screen Echo
visual structure and keep the state-read diagnostic QA-only.
