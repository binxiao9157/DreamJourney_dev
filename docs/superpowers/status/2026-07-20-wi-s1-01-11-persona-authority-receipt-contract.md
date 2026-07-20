# WI-S1-01-11 Persona Authority Receipt Contract G0 Slice

Date: 2026-07-20

## Scope Reached

The third G0 slice of `WI-S1-01-11` is deployed at backend `main@33ab0ae`.
It adds a deterministic, storage-independent plan for the immutable records a
future Self Persona Authority writer will need after command preflight.

For an admitted command the plan computes, but does not persist:

- A `PersonaVersion` plan with a UUID, version number,
  `expectedPriorVersion`, profile/payload/command hashes, scope hash,
  authority epoch and policy/content schema versions.
- A terminal `PersonaDecisionReceipt` plan with a UUID, matching
  PersonaVersion reference, command/actor/scope hashes, before/after state,
  expected/after version, policy version and authority epoch.

The next version must be exactly `expectedVersion + 1`. The Version and
Receipt must reference each other, target the same Persona, use the same
command hash and carry the same authority epoch. A stale or rejected command
generates neither record. Replaying the same admitted command/context produces
the same future UUIDs.

This remains a future-persistence plan only:

- `recordsWritten=false`
- `personaCreated=false`
- `personaVersionWritten=false`
- `decisionReceiptWritten=false`

The public summary contains only hashes, versions and schema/status metadata;
it excludes Persona/vault/subject identifiers and profile values.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-persona-authority-command-gate.sh
    bash scripts/run-backend-owner-truth-persona-authority-receipt-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The complete backend suite passed with 897 tests, followed by existing FastAPI,
Provider, knowledge, backup and deployment-file checks.

`origin/main@33ab0ae` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The deployment-image smoke confirmed:

    status=planned_for_future_persistence
    version=3
    epoch=7
    recordsWritten=False

It also verified that the value-free summary excludes the synthetic display
name and birth date.

## Deliberate Non-Goals

- No Persona aggregate, database table, repository, migration, API route or
  public iOS editing flow exists.
- No Version or DecisionReceipt is committed, and no legacy `profiles` data is
  migrated.
- No family, assistant, Provider, digital-human, voice or runtime state is
  admitted as Persona data.
- No MemorialVault, controller, grant, claim, conflict-hold or delete/correct
  behavior is introduced.

## Next Sub-Slice

`WI-S1-01-11-G0-PERSONA_AUTHORITY_ORIGIN_ADMISSION` should add a typed command
origin matrix. Only an interactive Self Owner origin may reach the command
preflight; family, assistant, Provider, runtime and unknown origins must fail
before payload parsing. It remains default-off and non-persistent.
