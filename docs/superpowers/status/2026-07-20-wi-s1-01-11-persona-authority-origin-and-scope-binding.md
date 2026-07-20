# WI-S1-01-11 Persona Authority Origin And Scope Binding G0 Slices

Date: 2026-07-20

## Scope Reached

Two follow-on G0 slices are deployed at backend `main@0c45af0`.

### Command Origin Admission

Only `owner_interactive` is allowed to reach the Self Persona command parser.
The following origins fail closed **before payload parsing**, even when the
actor string equals the owner string:

- `family`
- `assistant`
- `provider`
- `runtime`
- `unknown`

Rejected origins cannot generate a future PersonaVersion or DecisionReceipt
plan. This is an explicit G0 guard against family, AI, Provider or runtime
state impersonating the Owner's Persona authority.

### Server-Resolved Persona Scope Binding

The client payload no longer contains `personaId`. Its only fields are:

- `commandId`
- `expectedVersion`
- `profile` with `displayName`, `gender`, `birthDate` only

`resolvedPersonaId` is a typed server-side context input alongside Vault,
Owner, actor, authority epoch and current version. A payload that includes a
client-supplied `personaId` is rejected as an extra field. The future
PersonaVersion/DecisionReceipt plan uses the server-resolved Persona ID and is
bound to its Vault scope hash; the same client payload under a different
server-resolved Vault/Persona context produces a different plan.

This corrects an earlier G0 preflight shape before any API or persistence was
introduced. No existing data was ever written by that preflight.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-persona-authority-command-gate.sh
    bash scripts/run-backend-owner-truth-persona-authority-receipt-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The complete backend suite passed with 900 tests, followed by existing
FastAPI, Provider, knowledge, backup and deployment-file checks.

`origin/main@0c45af0` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`; `/ready` reported database,
schema, auth and incident readiness. The deployment-image smoke confirmed:

    accepted=planned_for_future_persistence
    spoof=invalid_command

The accepted plan referenced the context's server-resolved Persona ID. Adding
another `personaId` to the exact same client payload produced
`invalid_command` and no future record plan.

## Deliberate Non-Goals

- No Persona aggregate, database table, repository, migration, route, feature
  flag or public iOS UI exists.
- `resolvedPersonaId` is a pure typed input in this G0 slice; a later G2
  repository must prove its `(vault_id, persona_id)` binding transactionally.
- No Memorial controller, delegated Family contribution, claim/hold, delete or
  correction rule is added.
- No Provider, voice, digital-human or runtime state can write Persona data.

## Next Sub-Slice

`WI-S1-01-11-G0-PERSONA_PERSISTENCE_ADMISSION` should define a default-off
admission guard proving that the pure plan cannot become a repository write
without the later G2 additive schema, CAS, DecisionReceipt uniqueness and
rights evidence. It should not create a table or a public editing route.
