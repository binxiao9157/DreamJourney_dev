# WI-S1-01-11 Memorial Authority Composite G0 Gate

Date: 2026-07-20

## Scope Reached

Backend `main@b13b2b9` composes the completed default-off G0 boundaries for
Memorial authority. The composite gate verifies that a represented or deceased
Persona is never a login principal and that no current path creates a
Memorial Persona/Profile record, Controller appointment, ContributionGrant,
high-risk capability, Publication or Provider effect.

The composed boundary proves the following future-only rules:

- Controller bootstrap and transfer require server-resolved context and a
  future versioned/CAS write; no G0 request changes `authorityEpoch`.
- A controller that is unreachable, deceased, revoked or in failed account
  recovery returns `controller_review_required`. Before a new appointment,
  only rights-request, necessary-preservation and minimum-operation scope can
  be reviewed; Publication and Provider effects remain denied.
- Voice, Portrait, Digital Human and Publication capability purposes are
  independent. Missing evidence remains `not_requested`, incomplete evidence
  is rejected, and even complete synthetic assertions require later external
  G2/G3/G4 evidence rather than granting a capability.
- A verified rights claim or conflict requires a future atomic scope hold and
  epoch suspension. G0 neither mutates authority nor sends Provider cleanup.
- A Family Contributor may only submit Source/Candidate material or withdraw
  that contributor's own material in a future implementation. Relationship
  status never grants private query, Controller, confirmed-memory, Voice,
  Digital Human or Publication authority.

## Safety Boundary

This is a composition of value-free assessments, not a Memorial implementation.
No user data, schema, legacy migration, Persona/Profile persistence, media
processing, runtime state or public UI changed. G1 remains unavailable because
there is no authorized public Persona/Profile editing path. G2 requires a
versioned Memorial store and migration evidence. G4 requires product,
privacy and rights approval for any real Memorial capability.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-memorial-authority-composite-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The targeted composite gate passed 35 tests. The full backend verification
passed 939 tests, including the existing FastAPI, Provider, knowledge,
credential-response, backup and deployment checks.

`origin/main@b13b2b9` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The deployed composite smoke returned:

    controller review -> controller_review_required
    high-risk capability -> external_m3_g2_g3_g4_required
    verified conflict -> hold_required
    Family Digital Human request -> operation_not_allowed

## Next Boundary

`WI-S1-02-11` remains planned rather than executable: it depends on verified
media SourceObject and the async effect kernel items `WI-S1-02-01/02/03/04/07/09`.
Those dependencies still retain their conservative Registry `STOP` state.
The next implementation task must therefore be selected from a dependency-safe
G0 boundary instead of treating this composite evidence as permission to build
real media processing.
