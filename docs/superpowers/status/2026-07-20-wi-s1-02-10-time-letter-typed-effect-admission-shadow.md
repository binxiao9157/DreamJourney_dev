# WI-S1-02-10 G0 TimeLetter Typed Effect Admission Shadow

Date: 2026-07-20

## Completed Sub-slice

`WI-S1-02-10-G0-TIME_LETTER_TYPED_EFFECT_ADMISSION_SHADOW`

This adds a default-off, non-authoritative preview for the already hidden V4
TimeLetter delivery contract. It answers only whether a sealed V4 envelope
would be eligible for the typed effect lane. It does not admit an effect or
change the current legacy delivery authority.

## Implemented Boundary

Backend `main@f90c7c7` adds:

- `build_time_letter_delivery_admission_shadow(...)` in
  `app/services/time_letter_delivery_effects.py`;
- `shadow_disabled`, `legacy_envelope_ignored`, `not_due`, `would_admit`, and
  `invalid_v4_envelope` outcomes;
- deterministic hashes of prospective effect stable keys for a due V4 letter;
- value-free summaries with `shadowOnly=true`,
  `effectAdmissionPerformed=false`, and
  `legacyDirectDispatchUnchanged=true`;
- a dedicated G0 gate:
  `scripts/run-backend-time-letter-typed-effect-admission-shadow-gate.sh`.

The helper is default-off and returns before parsing an item when disabled. An
enabled legacy envelope is ignored before typed-plan parsing. A malformed V4
envelope fails closed without exposing title, body, owner, vault, recipient
name, or raw contract-error content.

It is deliberately not connected to `app/main.py`,
`scripts/dispatch_due_time_letters.py`, a scheduler, a worker, the effect
kernel, the consumer receipt repository, mailbox persistence, or the atomic
delivery service. The legacy API/CLI dispatcher remains the only delivery
authority for existing TimeLetters.

## Verification

Local G0:

```bash
bash scripts/run-backend-time-letter-typed-effect-admission-shadow-gate.sh
bash scripts/verify_backend.sh
git diff --check
```

Results:

- targeted contract gate: 15 tests passed;
- full backend verification: 852 unit tests passed, FastAPI `/health`,
  `/live`, `/ready`, existing async-effect gates, knowledge smokes and backup
  contract smoke passed;
- a pre-existing worker-loss observation test had a fixed past timestamp. Its
  fixture now uses a relative current timestamp, preserving the production
  rule that expired evidence is rejected without changing runtime code.

Deployment G2 evidence:

- server repository: `/opt/services/dreamjourney/DreamJourneyBackend@f90c7c7`;
- `sudo docker compose up -d --build api` rebuilt and recreated only `api`;
- API container became healthy and local `/ready` reported database, schema,
  auth and incident components as `ready`;
- container smoke imported the new helper and confirmed the default disabled
  result with no effect admission.

## Gate Position

| Gate | Status | Meaning |
| --- | --- | --- |
| G0 | Scoped complete | The default-off typed admission preview is deterministic, value-free and side-effect free. |
| G1 | Not applicable | No public iOS/UI or API surface changed. |
| G2 | Open | Deployment health is recorded, but host process inventory, single-scheduler proof, drain/zero-use, old-client and restore/replay evidence are still absent. |
| G3 | Open | No Provider callback/query or Provider-effect path was enabled. |

## Explicit Non-Claims

This slice does not claim scheduler/worker admission, outbox persistence,
mailbox delivery, APNs delivery, cohort cutover, retirement, route removal,
timer disablement, production zero-use, or Provider completion.

## Next Routing

`WI-S1-02-10` has no further safe G0 implementation slice. Its remaining G2
and G3 evidence requires Operations/runtime and Provider evidence. The
orchestrator must mark those gates external/open and select the next unblocked
work item rather than enabling a worker or changing the legacy dispatcher.
