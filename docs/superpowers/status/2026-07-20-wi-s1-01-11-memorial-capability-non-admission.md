# WI-S1-01-11 Memorial Capability Non-Admission G0 Slice

Date: 2026-07-20

## Scope Reached

Backend `main@0f52ac0` adds a default-off `MemorialCapabilityDecision` boundary
for a represented deceased Persona. It keeps every purpose independent:

- `voice_training`;
- `voice_synthesis_private`;
- `portrait_rendering`;
- `digital_human_private`;
- `publication_text`;
- `publication_voice`;
- `publication_digital_human`.

The context is server-resolved and includes Vault, represented Persona, subject
status, purpose and the captured authority epoch. It rejects a represented
Persona login principal and any non-deceased context, so it cannot be reused as
an in-life Owner Voice/DH grant.

Without explicit deceased intent evidence covering the exact purpose, the
proposed state is only `not_requested`. With asserted intent evidence but any
missing runtime, rights, policy, provider, labeling or M3 review prerequisite,
the proposed state is `rejected`. Even when every test assertion is true, the
only result is `external_m3_g2_g3_g4_required` with a future
`evidence_review` proposal; it is not a capability grant.

## Safety Boundary

No current living-self Voice Clone, family voice, Digital Human, Publication or
Provider runtime may be reused for a deceased Memorial purpose. Every result
reports:

- `capabilityAdmitted=False` and `capabilityDecisionWritten=False`;
- `providerEffectAllowed=False`;
- `voiceOrPortraitTrainingAllowed=False`;
- `digitalHumanSessionAllowed=False` and `publicationAllowed=False`;
- `fallbackToFamilyVoiceAllowed=False`;
- `defaultSystemVoiceMayBeDescribedAsDeceased=False`.

The module stores no capability decision, modifies no epoch, invokes no
Provider, and exposes only purpose-independent hashes and reason codes. It does
not claim synthetic booleans are the separately persisted evidence required by
M3, G2, G3 or G4.

## Verification And Deployment

Local checks passed:

    bash scripts/run-backend-owner-truth-memorial-capability-non-admission-gate.sh
    bash scripts/verify_backend.sh
    git diff --check

The full backend verification passed with 926 tests and all existing FastAPI,
Provider, knowledge, credential-response, backup and deployment checks.

`origin/main@0f52ac0` was deployed to
`/opt/services/dreamjourney/DreamJourneyBackend`. `/ready` reported database,
schema, auth and incident readiness. The container smoke asserted:

    missing intent evidence -> not_requested_no_intent_evidence
    all synthetic assertions -> external_m3_g2_g3_g4_required
    providerEffectAllowed=False
    digitalHumanSessionAllowed=False

## Next Sub-Slice

`WI-S1-01-11-G0-MEMORIAL_RIGHTS_CLAIM_CONFLICT_HOLD_NON_ADMISSION` should
model the compulsory fail-closed scope hold for a proven rights claim, court or
policy conflict. It must prevent the affected Voice, Portrait, Digital Human,
Publication or Vault-close capability from being treated as available, without
creating an actual claim, hold, policy decision, Provider cancellation or
authority-epoch write.
