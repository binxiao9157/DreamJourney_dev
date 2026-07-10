# P0 voice clone exclusive slot allocation

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_06_p0-voice-clone-exclusive-slot-allocation.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 voice clone exclusive slot allocation

## Context

The current backend hashes each logical profile across the configured VolcEngine trial `S_` speaker pool. This can assign two people to the same provider speaker and overwrite a previously trained voice. The same contract also lets `/voice/synthesis` call the provider before proving that the requested profile is persisted and usable for the requesting user.

This task replaces that QA shortcut with a production-safe ownership boundary while preserving the current iOS role-routing contract.

## Scope

- Refresh current implementation and routing documentation to the latest repository versions.
- Add persistent voice-clone slot storage for both in-memory and Postgres stores.
- Allocate configured trial/console speakers exclusively and atomically.
- Separate logical `voiceProfileId` from provider `providerSpeakerId`.
- Keep existing `S_` profiles compatible during migration.
- Resolve, authorize, and validate the stored profile before synthesis.
- Retire provider slots after profile deletion; do not automatically recycle voice data.
- Update runtime capability fields, backend tests, iOS logical ID generation, and QA guards.

## Out Of Scope

- Purchasing or provisioning additional VolcEngine speaker slots.
- Tencent digital-human session lifecycle changes.
- True-device testing.
- Public UI redesign.

## Steps

- [ ] Initialize and link a recursive ledger.
- [ ] Add failing backend tests for exclusive allocation, capacity exhaustion, compatibility, and synthesis authorization.
- [ ] Implement store-level slot allocation and lifecycle transitions.
- [ ] Integrate logical/provider ID separation into training, refresh, quality acceptance, disable/delete, and synthesis.
- [ ] Update iOS-generated logical profile IDs and static QA guards.
- [ ] Refresh status/operations documentation.
- [ ] Run backend tests, QA checks, `git diff --check`, and iOS build.
- [ ] Complete Lodestar review and record remaining external risks.

## Success Criteria

- Two logical profiles cannot own the same configured provider speaker.
- A fourth active profile against a three-slot pool receives an explicit capacity error rather than overwriting another voice.
- `/voice/synthesis` rejects missing, disabled, deleted, unaccepted, or cross-user profiles.
- A valid logical profile resolves to its assigned provider speaker for training, status refresh, and synthesis.
- Existing persisted profiles with `voiceProfileId=S_...` remain synthesizable when otherwise usable.
- No provider speaker ID is required in iOS role/family binding.
- Backend verification and iOS non-device build pass.

## Recursive Ledger

- Ledger ID: pending initialization.
- Current next action: initialize ledger.


## Success Criteria

- Two logical profiles cannot own the same configured provider speaker.
- A fourth active profile against a three-slot pool receives an explicit capacity error rather than overwriting another voice.
- `/voice/synthesis` rejects missing, disabled, deleted, unaccepted, or cross-user profiles.
- A valid logical profile resolves to its assigned provider speaker for training, status refresh, and synthesis.
- Existing persisted profiles with `voiceProfileId=S_...` remain synthesizable when otherwise usable.
- No provider speaker ID is required in iOS role/family binding.
- Backend verification and iOS non-device build pass.
