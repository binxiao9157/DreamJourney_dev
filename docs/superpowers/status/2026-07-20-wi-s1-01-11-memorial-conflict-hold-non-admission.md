# WI-S1-01-11 Memorial Rights Claim / Conflict Hold Non-Admission G0 Slice

Date: 2026-07-20

## Scope Reached

Backend `main@eedc8a5` adds a default-off assessment for the product rule that
a proven Memorial rights dispute must first create a scope-specific
`MemorialConflictHold`.

The server-resolved context keeps a Vault, represented Persona, one capability
scope and one trigger separate. Supported scopes are Voice training/synthesis,
Portrait, Digital Human, each Publication purpose, and Vault closure. Supported
triggers are a verified eligible-close-relative rights claim, court or regulator
order, source-rights dispute, policy change and an unknown trigger that fails
closed.

Missing verified trigger evidence or a specific scope returns
`verification_required`. With both assertions present, the only result is
`hold_required`: a future writer must atomically advance the authority epoch and
suspend the affected scope; it must stop new generation/playback before async
Provider cleanup. A represented/deceased Persona login principal remains a hard
denial.

## Safety Boundary

The G0 result is not an effective claim, hold, policy decision or cancellation.
It creates no table row, increments no epoch, suspends no capability, blocks no
live publication, stops no playback and sends no Provider cleanup request.
Every result reports those effects as false while exposing only reason codes,
a hashed scope and captured epoch.

This preserves the required ordering without falsely claiming production rights
or Provider enforcement: verified evidence, atomic hold/epoch/suspension,
access-minimal review, then separately authorized release or cleanup.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-memorial-conflict-hold-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The full backend verification passed with 931 tests and all existing FastAPI,
Provider, knowledge, credential-response, backup and deployment checks.

`origin/main@eedc8a5` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The container smoke asserted:

    missing evidence -> verification_required
    verified scope -> hold_required
    authorityEpochChanged=False
    providerCleanupExecuted=False

## Next Sub-Slice

`WI-S1-01-11-G0-MEMORIAL_FAMILY_CONTRIBUTION_GRANT_NON_ADMISSION` should
model the separate, scoped Family Contributor boundary. It must permit only a
future Source/Candidate contribution and the contributor's own withdrawal;
it must not turn a family relationship or a contribution into controller,
confirmed-memory, private-query, Voice, Portrait, Digital Human or Publication
authority.
