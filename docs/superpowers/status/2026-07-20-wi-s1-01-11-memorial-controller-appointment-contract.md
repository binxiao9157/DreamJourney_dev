# WI-S1-01-11 Memorial Controller Appointment Contract G0 Slice

Date: 2026-07-20

## Scope Reached

Backend `main@db17c59` adds a default-off, pure planning contract for a future
`MemorialControllerAppointment` aggregate. It models the product rule that a
Memorial Vault has at most one active primary controller without treating a
deceased represented Persona, a Family role, or a client payload as authority.

The only accepted client command fields are:

```json
{
  "commandId": "opaque-command-id",
  "expectedVersion": 0,
  "operation": "bootstrap | transfer"
}
```

`vaultId`, represented Persona, current controller and next controller are all
server-resolved typed context. Client-supplied equivalents are rejected.

The pure plan covers two future operations:

- `bootstrap` requires no existing active primary controller, version `0`, and
  the actor to equal the server-resolved next controller;
- `transfer` requires the actor to be the server-resolved current primary
  controller, a different server-resolved successor and a matching
  `expectedVersion`.

Both paths require asserted identity, death/kinship and legal-policy evidence
and fail closed for an active RightsClaim or ConflictHold. A represented/deceased
Persona login principal, Family Contributor, Assistant, Provider, runtime and
unknown command origin are denied before a plan can exist.

An otherwise valid result is only `planned_for_future_persistence`. It binds
future appointment and DecisionReceipt IDs to the complete server-resolved
context, advances only a future appointment version, and records transfer
requirements for atomic prior-grant revocation, session/grant revocation and
high-risk capability re-evaluation. It intentionally does **not** advance the
Vault authority epoch: the product specification reserves epoch increments for
claims, holds and policy-relevant authority changes rather than ordinary
controller transfer by inference.

## Safety Boundary

This is not a writer. It creates no route, schema, repository, Vault,
appointment, grant, session, PersonaVersion, DecisionReceipt, Provider effect
or public iOS flow. Every output reports:

- `recordsWritten=False`;
- `controllerAppointmentWritten=False`;
- `personaVersionWritten=False`;
- `providerOrRuntimeMutated=False`;
- `authorityEpochChanged=False`.

Synthetic claim flags are test inputs only and cannot authorize real
persistence. A production writer remains gated on G2 versioned storage/CAS and
G4 rights, legal and policy evidence.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-memorial-controller-appointment-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The complete backend suite passed with 915 tests, including existing FastAPI,
Provider, knowledge, credential-response, backup and deployment checks.

`origin/main@db17c59` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The container smoke verified:

    bootstrap -> planned_for_future_persistence
    transfer -> planned_for_future_persistence
    Family Contributor origin -> origin_not_allowed
    recordsWritten=False

## Next Sub-Slice

`WI-S1-01-11-G0-MEMORIAL_CONTROLLER_REVIEW_NON_ADMISSION` should encode the
explicit `controller_review` boundary for a lost, deceased, revoked or
unrecoverable primary controller. Before a newly verified appointment becomes
effective, only rights requests, necessary preservation and minimum operations
may be considered; new Publication and all Provider effects must remain denied.
It must remain default-off and pure until the G2/G4 prerequisites exist.
