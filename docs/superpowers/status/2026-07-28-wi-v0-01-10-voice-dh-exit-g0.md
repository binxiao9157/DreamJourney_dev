# WI-V0-01-10 G0: Voice/Digital Human Rights Exit Boundary

Date: 2026-07-28
Work Item: `WI-V0-01-10`

## Scope

Backend commit `0043e4a` adds the default-off
`voice_dh_exit_shadow` contract. It establishes the minimum exit DAG for a
future Voice/Digital Human rights implementation without changing a public
route, calling Volcengine or Tencent, or claiming that a legacy tombstone is a
provider deletion receipt.

- The opaque command supports purpose revoke, pause, disable, profile delete,
  and account purge planning.
- Each action declares the cleanup layers it must cover: profile, sample,
  generated audio, local cache, Digital Human session, provider asset, and
  backup retention.
- Exit is access-first: new effects must be denied and runtime cleanup is
  required before any physical-cleanup completion can be stated.
- Owner/vault/actor/authority epoch/runtime generation are fenced. Stale
  commands and conflicting stable-command replays fail closed.
- G0 reports provider exit as `unknown`; it never persists a cleanup receipt,
  performs local cleanup, dispatches a provider call, or exposes release UI.

Existing `/voice/profiles/.../disable` and delete routes retain their current
legacy local-state behavior. This work deliberately does not re-label those
routes as Provider deletion, and it does not modify existing account deletion
receipts.

## Verification

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python \
  scripts/run-backend-voice-dh-exit-g0-gate.sh
PYTHON_BIN=/tmp/dreamjourney-backend-test-venv/bin/python \
  scripts/verify_backend.sh
git diff --check
```

Result: 6 new exit-contract tests passed. Full backend verification passed with
1220 tests plus existing contract and FastAPI smoke gates.

As an ordering check for `WI-V0-01-09`, the existing iOS static gate also
passed:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
python3 Scripts/QA/product-v4/product-v4-ios-audio-owner-lease-check.py
```

That confirms the previously implemented G0 AudioSession ownership boundary;
it does not close real Provider or device gates.

## Open Gates

- `G1`: iOS does not consume an exit receipt or present an access-revoked /
  clearing / partial / unsupported state model.
- `G2`: no durable exit command, outbox, GeneratedAudio/object/cache records,
  session cleanup reconciler, or receipt ledger exists for this DAG.
- `G3`: no Volcengine/Tencent delete or query receipt, backup-retention mapping,
  region/cost evidence, or provider capability confirmation exists.
- `G4`: no user-facing revoke/delete disclosure or real-device validation.

Therefore this is `INTERNAL_READY / scoped G0` only. It is not pushed or
deployed, does not change production behavior, and cannot be reported as
Provider cleanup completion.
