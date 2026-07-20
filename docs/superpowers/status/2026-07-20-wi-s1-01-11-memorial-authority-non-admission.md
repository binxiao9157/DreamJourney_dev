# WI-S1-01-11 Memorial Authority Non-Admission G0 Slice

Date: 2026-07-20

## Scope Reached

Backend `main@77aa244` adds the default-off Memorial Persona admission
boundary required before a future `MemorialVault` authority writer can exist.

The model makes these current rules executable:

- the represented/deceased Persona is never a login principal;
- only an interactive Memorial Controller origin can reach future review;
- a Family Contributor may only submit Source or Candidate material, never
  write Persona authority;
- Assistant, Provider, runtime and unknown origins cannot write Memorial
  Persona authority;
- missing controller appointment, death/kinship verification or legal-policy
  readiness fails closed;
- an active RightsClaim or ConflictHold blocks a mutation;
- even fully asserted synthetic prerequisites return
  `external_g2_g4_required`, not an authority grant.

The output is value-free and always reports no authority admission, no record
write, no controller-appointment write, no PersonaVersion write and no
Provider/runtime mutation.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-memorial-authority-admission-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The complete backend suite passed with 909 tests. Existing FastAPI, Provider,
knowledge, credential-response, backup and deployment-file checks also passed.

`origin/main@77aa244` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The deployment-image smoke verified:

    all asserted prerequisites -> external_g2_g4_required
    Family origin -> origin_not_allowed
    represented login principal -> represented_login_principal_forbidden
    recordsWritten=False

## Deliberate Non-Goals

- No `MemorialVault`, `RepresentedPersona`, `MemorialControllerAppointment`,
  verification, ContributionGrant, RightsClaim or ConflictHold table exists.
- No current Family record, profile, Voice profile, Digital Human metadata or
  controller-like client state is upgraded into Memorial authority.
- No actual relationship/death-proof supplier, legal review, capability
  decision, Voice, portrait, Digital Human or Publication capability is
  enabled.
- This does not claim G2/G4 evidence is present merely because synthetic flags
  were supplied to the test model.

## Next Sub-Slice

`WI-S1-01-11-G0-MEMORIAL_CONTROLLER_APPOINTMENT_CONTRACT` should model the
future primary-controller bootstrap and transfer command: one active primary
controller per Vault, server-resolved represented Persona, `expectedVersion`,
required verified records, claim/hold blocking and immutable future receipt
planning. It remains default-off and must not create a schema, route or public
Memorial flow.
