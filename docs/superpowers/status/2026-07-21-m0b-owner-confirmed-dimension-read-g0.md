# M0-B Owner-confirmed MemoryVersion Dimension Read Evidence

Date: 2026-07-21

## Scope

Backend `main@9869fa2` adds a read-only M0-B adapter:
`OwnerTruthKnowledgeDimensionReadService`.

It reads the existing Owner Truth `MemoryProjection` and produces only
value-free dimension coverage. This extends the earlier synthetic M0-B
recommendation foundation without creating a public recommendation surface.

## Admission Contract

Only an existing projection entry is eligible when all of these conditions hold:

- the projection is ready and owner/vault scoped;
- `memoryKind=knowledge` and `sensitivity=standard`;
- perspective and status are not inferred;
- `content.knowledgeDimensionEvidence` exactly uses
  `owner-truth-knowledge-dimension-evidence-v1`;
- the evidence contains a supported `dimension`, non-empty `coveredFacets`,
  `classificationConfirmedByOwner=true`, and `isAiInferenceOnly=false`.

The response contains opaque identifiers, dimension names, facets, counts and
reason codes only. It never returns memory text, claim text, KBLite facts,
provider output or an inferred classification.

Legacy MemoryVersions without the explicit annotation, malformed annotations,
ineligible lifecycle state and unavailable projections are excluded fail-closed.
They do not silently increase coverage.

## Explicit Non-goals

- No API, database migration, worker, outbox, Provider call or new write path.
- No Source, Candidate, DecisionReceipt, MemoryVersion or Projection mutation.
- No iOS/public Echo UI change, recommendation text, completion percentage or
  user-visible score.
- No automatic extraction of knowledge dimensions from memory content.

## Verification

Local backend validation on `main@9869fa2`:

```text
PYTHONPATH=. .venv/bin/python -m unittest \
  tests.test_owner_truth_knowledge_dimension_read \
  tests.test_owner_truth_knowledge_recommendations
17 tests passed

bash scripts/run-backend-owner-truth-knowledge-recommendation-gate.sh
passed

PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
1029 tests passed

git diff --check
passed
```

Deployment verification:

- Server repository advanced to `main@9869fa2`.
- `docker compose up -d --build api` completed successfully.
- `/ready` returned `200` with database, schema, auth and incident components
  ready.
- The production API container ran
  `scripts/run-backend-owner-truth-knowledge-recommendation-gate.sh` and passed
  its dependency-free deployed-policy smoke.

## Gate Status

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 | Passed for this adapter | unit, negative fixtures, static gate and full backend verification |
| G2 | Deployed code and health smoke passed | deployed image contains the adapter; no production annotation population is claimed |
| G1 | Open | no UI surface exists |
| G3 | Not applicable | no Provider is called |
| G4 | Open | no public product decision or release surface is implied |

This is an additive M0-B sidecar, not a new Registry completion. The active
Work Item remains `WI-S1-01-03`; the Registry keeps its conservative planning
state. Do not treat the count of handoff evidence records as an overall V4
completion percentage.

## Next Boundary

Before real M0-B coverage can exist, a separate owner-confirmed classification
proposal and review ingress must be designed and verified. It must preserve the
same Owner Truth lifecycle and stay default-off until its relevant Gates are
closed.
