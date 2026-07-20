# WI-S1-01-11 Persona/Profile Legacy Boundary G0 Slice

Date: 2026-07-20

## Scope Reached

The first G0 slice of `WI-S1-01-11` is complete at backend `main@38ddb3d`.
It classifies legacy `profiles` only as migration input. It does not create a
Persona, update an existing profile, construct a MemorialVault, call a
Provider, or expose a UI/API route.

The default-off classifier enforces V4 migration catalog B15:

- Candidate-only Persona fields: `displayName`, `gender`, `birthDate`.
- Identity binding only: account/owner/phone/email identifiers.
- Excluded from Persona: avatar/embodiment, voice profile, provider speaker,
  digital-human and session metadata.
- Excluded from Persona: family relationship, invitation, grant and scope
  metadata.
- Any other profile field is quarantined, not silently copied.

The existing profile sanitizer was exercised directly: its current
`nickname/gender/region/avatarName` payload maps only nickname and gender to
candidate field names. Region remains unknown/quarantined; avatar remains an
embodiment asset, not Persona authority.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-persona-profile-legacy-boundary-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The full backend suite passed with 885 tests plus FastAPI, Provider,
knowledge, backup and deployment-file checks.

`origin/main@38ddb3d` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. The API became healthy with
database/schema/auth/incident ready. An in-container smoke verified:

    status=classified
    candidatePersonaFields=[birthDate, displayName, gender]
    personaCreated=false
    legacyProfileMigrated=false

The smoke also verified profile values and arbitrary unknown key names do not
appear in the value-free summary.

## Deliberate Non-Goals

- No `Persona/Profile` schema, table, repository, migration or public editing
  route exists yet.
- No legacy profile is promoted to a Persona.
- `region`, avatar, voice, digital-human and family metadata are not claimed
  to be deleted or migrated; they remain in their existing domains pending
  independent contracts.
- No MemorialVault, controller appointment, contribution grant, capability
  decision, rights claim or conflict hold was added.

## Next Sub-Slice

`WI-S1-01-11-G0-PERSONA_AUTHORITY_COMMAND_CONTRACT` should define a typed,
versioned self-Persona command boundary. It must consume only allowlisted
fields and an active Owner/Vault context; it must keep Memorial Persona,
family, provider, voice and digital-human runtime state out of the command.
