# WI-S1-01-10 Owner Cohort Cutover G0 Admission Boundary

Date: 2026-07-20

## Scope Reached

`WI-S1-01-10` now has its complete currently executable G0 boundary. It does
not perform an Owner cohort cutover. It defines and verifies the condition
that legacy parity can never self-authorize a Vault `authorityEpoch` change or
legacy-writer retirement.

Backend `main@864e5d9` adds:

1. `OwnerTruthCutoverAdmissionShadow`, a default-off, value-free model.
2. A hidden legacy parity summary field, `cutoverAdmission`.
3. A repeatable `run-backend-owner-truth-cutover-admission-shadow-gate.sh`.

The helper has no API, database, effect, worker, Provider, network or UI
dependency. It only returns `shadow_disabled`, `context_mismatch`,
`invalid_envelope`, or `external_go_required`.

## Proven Invariants

- The disabled path does not inspect a context or parity report.
- A legacy parity report, including a tampered report that claims `cutoverAllowed`,
  cannot authorize a cutover.
- The model always reports `authorityEpochChanged=false`,
  `legacyWriterRetired=false`, and `cutoverAllowed=false`.
- Vault or epoch mismatch fails closed before any external go evaluation.
- Every enabled result requires a separate production go record, independent
  epoch-CAS command and independent legacy-writer retirement command.
- The existing hidden parity response can expose only value-free hashes and
  reason codes; no archive or memory body is added.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-cutover-admission-shadow-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The full backend suite passed with 880 tests plus FastAPI, Provider,
knowledge, backup and deployment-file checks.

`origin/main@864e5d9` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. The API container restarted,
`/ready` returned `ready` for database/schema/auth/incident, and the deployed
container smoke verified:

    status=external_go_required
    cutoverAllowed=false
    authorityEpochChanged=false
    legacyWriterRetired=false

## Remaining Gates

| Gate | Status | Required evidence |
| --- | --- | --- |
| G0 | Scoped complete | Admission shadow and hidden parity observability. |
| G1 | Open | Controlled client/cohort behavior and legacy compatibility read proof. |
| G2 | Open | Production-shape parity, checkpoint, CAS, observation window and rollback proof. |
| G4 | Open | Product, Privacy, Data Rights and identity approval for a real cohort. |

## Automatic Plan Transition

Real text-core cutover remains blocked until its independent G1/G2/G4 records
exist. The next executable owner-truth item is `WI-S1-01-11`, beginning with a
G0 Persona/Profile legacy-boundary inventory. It must keep Persona authority
separate from family, provider, voice and digital-human runtime metadata.
