# WI-S1-01-06 Interview Orchestration Read G0

Date: 2026-07-30

## Completed scope

This slice adds a default-off, QA-only read bridge for the deterministic
Owner Truth interview orchestration policy.

- Backend commit: `DreamJourneyBackend` `main@76f0b4b`.
- iOS contract: strict typed decoder, QA-gated client, and AccountLease plus
  generation fencing in `OwnerTruthContracts.swift`.
- No product-facing UI, natural-language input, provider/model invocation,
  pacing write, Candidate/Source/MemoryVersion write, deployment, or
  true-device claim is included.

## Contract boundary

The request may contain only these five Boolean signals:

```text
topicIncomplete
needsClarification
userChangedTopic
isSensitive
acceptedBroadenRecommendation
```

The response is value-free: opaque policy decision fields and persisted
session counters/state only. It rejects topic text or identifiers,
transcript/prompt data, source/candidate/memory identifiers, authorization
claims, and unknown JSON envelope fields.

The policy result is advisory. It does not itself change the persisted
interview session.

## Verification

- Backend focused orchestration/API suites, route authentication/ownership
  suites, `scripts/verify_backend.sh` (1,552 tests and existing gates),
  FastAPI smoke, Python compilation, and `git diff --check`: passed.
- iOS `DreamJourneyTests/OwnerTruthContractsTests`: 82/82 passed on the iOS
  simulator.
- Generic unsigned simulator build: passed.

The currently unavailable isolated Postgres runner was not substituted with
mock evidence. This endpoint makes no G2/deployment claim.

## Next boundary

Select one unproven P0 gap under `WI-S1-01-06`; do not turn this read bridge
into automatic topic classification, a pacing write, a provider call, or a
public Echo control without a separately authorized slice and gate evidence.
