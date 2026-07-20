# WI-S1-01-11 Persona Authority Command Contract G0 Slice

Date: 2026-07-20

## Scope Reached

The second G0 slice of `WI-S1-01-11` is deployed at backend
`main@fe702e0`. It adds a default-off, storage-independent preflight for a
future **Self Persona Authority** command.

The contract accepts only this versioned command shape:

- Owner/Vault context with `actorSubjectId == ownerSubjectId`.
- A server-resolved `PersonaId` context plus `commandId` and `expectedVersion`.
- A non-empty profile with the V1 allowlist only:
  `displayName`, `gender`, `birthDate`.

It fails closed for all of the following before a future writer can be called:

- Any unknown or extra command/profile field, including `voiceProfileId`,
  `providerAssetId`, `digitalHumanId`, `personaScope`, relationship and owner
  binding fields.
- A non-owner actor.
- A stale `expectedVersion`.
- A Memorial/deceased representation. It returns
  `deceasedPersonaRequiresControllerNotLoginPrincipal`; this slice does not
  model a deceased person as a login principal.

An accepted result deliberately means only
`accepted_for_future_persistence`. Every result proves:

- `personaCreated=false`
- `personaVersionWritten=false`
- `decisionReceiptWritten=false`
- `providerOrRuntimeMutated=false`

Public evidence contains only hashes, field names and versions. It does not
include a display name, date of birth, subject ID, vault ID, Persona ID or raw
payload value. Subsequent G0 work removed `personaId` from the client payload;
the current authoritative command shape uses only the server-resolved context.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-persona-authority-command-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The complete backend suite passed with 893 tests, followed by its existing
FastAPI, Provider, knowledge, backup and deployment-file checks.

`origin/main@fe702e0` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The production image intentionally does
not contain the test package, so the deployed smoke imported the application
module directly and verified:

    status=accepted_for_future_persistence
    rejected=invalid_command
    memorial=memorial_controller_required

That smoke also asserted no Persona/version/receipt/runtime mutation and no
raw profile values in the value-free summary.

## Deliberate Non-Goals

- No Persona aggregate, table, repository, route, UI, migration or public
  editing surface exists.
- No existing `profiles` row, family metadata, voice profile, provider state
  or digital-human state is promoted to Persona Authority.
- No PersonaVersion or DecisionReceipt is persisted. A future writer must
  re-run policy checks atomically under CAS.
- No MemorialVault, controller appointment, contribution grant, claim or
  conflict-hold policy is introduced.

## Next Sub-Slice

`WI-S1-01-11-G0-PERSONA_AUTHORITY_RECEIPT_CONTRACT` should define only the
immutable PersonaVersion/DecisionReceipt record contract and its value-free
receipt shape. It must remain storage-independent and default-off until the
G2 additive schema, migration and rights gates are explicitly satisfied.
