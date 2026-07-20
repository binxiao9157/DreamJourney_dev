# WI-S1-01-11 Memorial Family ContributionGrant Non-Admission G0 Slice

Date: 2026-07-20

## Scope Reached

Backend `main@41047af` adds a default-off boundary for a future scoped
`FamilyContributionGrant`. It explicitly separates a Family Contributor from a
Memorial Controller, private-query reader, Publisher and high-risk capability
holder.

The only future operation categories considered by the contract are:

- `submit_source`;
- `submit_candidate`;
- `withdraw_own_contribution`.

Each requires an asserted active scoped grant and verified contributor identity;
withdrawal additionally requires the contribution to be the contributor's own.
Even then, the result is only `external_g2_g4_required`, not a write.

All other operations are rejected before claims are considered, including
confirmed-memory writes, private query, query-access grants, Publication,
Voice, Portrait, Digital Human and controller appointment.

## Safety Boundary

No current Family relationship or synthetic grant creates a Source, Candidate,
grant, confirmed memory, query right, controller authority, Publication or
high-risk capability. The value-free result reports all write and authority
flags as false and contains no raw Vault, represented-Persona or contributor
identifier.

This preserves the product rule that family material retains contributor and
perspective lineage while a later G2 implementation supplies scoped grant
persistence, version/CAS, source/candidate writes and withdrawal propagation.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-memorial-family-contribution-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The full backend verification passed with 937 tests and all existing FastAPI,
Provider, knowledge, credential-response, backup and deployment checks.

`origin/main@41047af` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The container smoke asserted:

    Source contribution -> external_g2_g4_required
    Digital Human operation -> operation_not_allowed
    privateQueryAllowed=False

## Next Sub-Slice

`WI-S1-01-11-G0-MEMORIAL_AUTHORITY_COMPOSITE_GATE` should verify the G0
boundaries together: no represented-Persona login, controller transfer is only
a future plan, controller failure blocks Publication/Provider effects, high-risk
capabilities remain `NO_GO`, verified disputes only require future holds, and
Family Contributors cannot gain authority from their relationship.
