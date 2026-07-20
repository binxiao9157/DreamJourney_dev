# WI-S1-01-03 M0-A Natural-Input Backend Command

## Completed backend boundary

The existing private Owner Truth conversation service now has a narrow,
default-off QA command contract for `naturalInput` interview sessions:

```text
POST /v2/vaults/{vault_id}/interview-sessions
POST /v2/vaults/{vault_id}/interview-sessions/{session_id}/messages
```

The routes require an authenticated active Vault owner, the existing Owner
Truth QA header and a server-side QA flag. They are omitted from OpenAPI and
return `Cache-Control: no-store`. A command receipt contains ids, state,
boundary, versions and message metadata; it never returns message text,
Sources, Candidates, DecisionReceipts, MemoryVersions, provider output or
digital-human state.

The backend preserves command idempotency and optimistic thread/session
versioning. It writes only private conversation/session records. It does not
start extraction, candidate review, memory activation, providers, KBLite or
public Echo behavior.

## Evidence

- Backend feature: `DreamJourneyBackend@d6dc3b9`.
- Route-smoke consistency fix: `DreamJourneyBackend@bf83ace`.
- Local verification: `tests/test_owner_truth_interview_input_api.py`, route
  authentication and runtime-capability targets passed; full
  `scripts/verify_backend.sh` passed with `999` tests.
- Deployment: production-like backend `main@bf83ace`, rebuilt API container,
  `/ready` returned `status=ready`.
- G2: deployed disposable-Postgres conversation smoke passed; deployed
  route-authentication smoke passed with `routeCount=98`.

No credential or server `.env` value was read, changed or committed. The
feature remains default-off and is not linked from public UI.

## Next increment

Implement an iOS typed QA-only natural-input client using this contract. The
client must bind every request to the current `AccountLease`, discard stale
responses, preserve the current full-screen Echo visual structure, and stay
outside the public Echo navigation until its product gate is complete.
