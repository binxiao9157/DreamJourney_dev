# WI-S1-01-11 Persona Persistence Admission G0 Slice

Date: 2026-07-20

## Scope Reached

Backend `main@dc18a40` adds a default-off, pure admission shadow after the
Self Persona command preflight and future PersonaVersion/DecisionReceipt plan.

An admitted future record plan still cannot create a schema, write a
repository, persist a PersonaVersion or persist a DecisionReceipt. The shadow
always returns one of:

- `shadow_disabled` when the G0 observer is off;
- `invalid_envelope` for an invalid receipt-plan or claims envelope;
- `receipt_not_admitted` when the earlier command/receipt plan was not
  admitted;
- `external_g2_g4_required` for an otherwise admissible future plan.

The last result is intentionally **not** a go signal. It lists the separate
requirements that a later production writer must prove:

- additive versioned schema/migration;
- Vault/Persona scoped transactional version CAS;
- transactional terminal DecisionReceipt uniqueness;
- product/privacy rights evidence and release approval.

Synthetic boolean claims for those four prerequisites are deliberately
non-authoritative. Even when all claims are asserted, the result remains
`external_g2_g4_required` and contains
`shadowClaimsCannotAuthorizePersonaPersistence`.

## Safety Boundary

This slice has no Persona table, migration, repository, route, feature flag,
Provider call, worker effect or public iOS UI. It cannot alter a Profile,
Persona, Family relationship, Memorial representation, Voice, Digital Human or
runtime state. The only output is a value-free summary with reason codes and
hashes already produced by the prior pure receipt plan.

## Verification And Deployment

Local verification passed:

    bash scripts/run-backend-owner-truth-persona-persistence-admission-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The complete backend suite passed with 904 tests. Existing FastAPI, Provider,
knowledge, credential-response, backup and deployment-file checks also passed.

`origin/main@dc18a40` was fast-forwarded and deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The deployment-image smoke asserted an
otherwise admitted future receipt plan plus all four synthetic claims and
returned:

    status=external_g2_g4_required
    recordsWritten=False
    schemaChanged=False

## Deliberate Non-Goals

- This is not a G2 Persona aggregate or persistence implementation.
- It does not claim that the synthetic claims are real production evidence.
- It does not unblock public Profile editing or any existing legacy profile
  writer.
- It does not implement Memorial controller appointments, kinship/death
  verification, contribution grants, rights claims or conflict holds.

## Next Sub-Slice

`WI-S1-01-11-G0-MEMORIAL_AUTHORITY_NON_ADMISSION_BOUNDARY` should encode the
current fail-closed rule: a represented/deceased Persona cannot be treated as
a login principal and cannot reach a future Persona writer without a separate
controller, verification and rights contract. It remains a pure deny contract;
it must not introduce a Memorial aggregate or a public flow.
