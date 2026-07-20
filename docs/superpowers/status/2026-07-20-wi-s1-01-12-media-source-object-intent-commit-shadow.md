# WI-S1-01-12 G0 Media SourceObject Intent/Commit Contract Shadow

Date: 2026-07-20

## Completed Sub-slice

`WI-S1-01-12-G0-INTENT_COMMIT_CONTRACT_SHADOW`

This is the second G0 sub-slice in the private media-object lane. It models
the minimum future upload-intent and commit proof boundary using synthetic
metadata only. It is disabled by default and does not change the current
Archive mock-media path.

## Implemented Contract

Backend `main@07ebaed` adds:

- `app/services/owner_truth_media_source_object_commit_shadow.py`;
- `build_media_source_object_intent_commit_shadow(...)`, disabled before it
  inspects either envelope;
- a value-free result that can only say a future object would remain
  quarantined, would deduplicate, conflicts with a prior receipt, or is an
  orphan candidate;
- `scripts/run-backend-owner-truth-media-source-object-commit-shadow-gate.sh`.

When enabled only for synthetic QA, the contract requires all of the
following before it can return `would_commit_quarantined`:

- current intent and commit protocol versions;
- private, non-mock storage metadata and a normalized private object key;
- unexpired intent plus identical owner, vault, purpose, source-object and
  intent bindings;
- a size and SHA-256 match to the intent;
- a magic MIME compatible with the declared media kind;
- matching observed-HEAD metadata supplied by the caller.

The result distinguishes a matching retry (`would_deduplicate`) from a
changed retry (`duplicate_conflict`). A synthetic uploaded-but-uncommitted
object is only an `orphan_candidate`; it never triggers deletion.

## Explicit Non-Claims

This sub-slice does not issue upload URLs, receive bytes, call object-storage
HEAD, create a SourceObject or receipt row, persist an orphan, delete anything,
start a worker, invoke a processor, or write Candidate, Memory or Persona
state. It does not add an API route, object storage provider, schema migration,
scan integration, iOS upload client or public UI.

Current `mockObjectStorage`, `mock://`, local files, temporary Provider URLs
and metadata-only legacy media remain non-authoritative. No result from this
module grants access to media bytes or promotes an object to `verified`.

## Verification

Local verification:

```bash
python3 -m unittest tests.test_owner_truth_media_source_object_commit_shadow
bash scripts/run-backend-owner-truth-media-source-object-commit-shadow-gate.sh
bash scripts/verify_backend.sh
git diff --check
```

Results:

- 8 dedicated intent/commit tests passed;
- the dedicated gate passed 16 focused checks;
- the combined source/candidate run passed 21 checks;
- full backend verification passed: 868 tests plus FastAPI, Provider, async
  effect, knowledge and backup contract checks.

Deployment evidence:

- `origin/main@07ebaed` was deployed to
  `/opt/services/dreamjourney/DreamJourneyBackend`;
- the API image was rebuilt and restarted;
- `/ready` returned ready for database, schema, auth and incident components;
- an in-container import smoke verified the deployed helper returns
  `shadow_disabled` by default, including for malformed synthetic inputs.

## Gate Position

| Gate | Status | Meaning |
| --- | --- | --- |
| G0 | In progress | Boundary inventory and intent/commit shadow are complete; legacy non-promotion inventory is next. |
| G1 | Not started | No public media UI change is authorized. |
| G2 | Not started | No SourceObject schema, real object store, HEAD/delete/reconcile or restore evidence exists. |
| G3 | Not started | No private bucket, scan, retention, region or provider exit contract is enabled. |
| G4 | Not started | No device media permission or privacy/legal approval is claimed. |

## Next Sub-slice

`WI-S1-01-12-G0-LEGACY_MEDIA_NON_PROMOTION_INVENTORY` will inventory the
existing Archive media representations and prove that mock, local, temporary,
metadata-only and missing-file records cannot be classified as a future
verified SourceObject. It remains a read-only/default-off G0 boundary and does
not start real upload integration.
