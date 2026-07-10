# Task Plan

## STATUS

- **Goal:** 按照最新 PRD 持续推进 DreamJourney_dev 到可真实测试、可真机验收、可持续迭代状态
- **Mode:** Execute
- **Phase:** Phase 8 knowledge conflict and deletion semantics complete
- **Task:** Task 13 closed; next slice not selected
- **Blockers:** none for local implementation; online Postgres V2 acceptance requires an explicit push/deploy step

## Key Decisions

- Closure Lodestar is active: Lodestar files are the project-level source of truth.
- Recursive Closure ledgers are task-level closure engines under `.complex-problems/`.
- Task 1 closed: PRD continuation gap map is recorded in `docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md`.
- Task 2 closed: persona-scoped archive storage/backend/context contract is implemented and guarded.
- Task 3 closed: real-device/backend acceptance readiness is documented and guarded; true backend/device execution still waits for user-provided environment.
- Task 4 closed: hidden family/persona switcher, profile safety shells, and care visibility gates are implemented and guarded.
- Task 5 closed: release QA handoff is documented and simulator/static QA passed.
- Post-review continuation: `长辈关怀` aggregate child dashboard, hidden `阳光 / 星辰 / 静默` mode management, Echo/Profile lifecycle effects, hidden profile care escalation draft, care escalation draft-only backend boundary smoke, archive media release readiness contract, archive media entries smoke harness, family/persona release readiness smoke, App-side backend family acceptance hardening, PRD coverage matrix, phase 0 backend alignment with the existing `DreamJourneyBackend`, release-like backend acceptance harness, one-command release regression, and final Stitch visual refresh are complete without true-device execution.
- Current target after this slice: release-like FastAPI/Postgres backend acceptance passed with run `20260618-deployed-postgres-acceptance-after-deploy`; `我的` remains the third public tab and carries settings/account/legal/care entries; release handoff mode now forces the release-like backend gate unless explicitly overridden; public MVP archive header polish is complete; hidden candidate release matrix is guarded and documented; Echo waiting reply default policy now enters waiting state after the third final user voice turn.
- Profile IA contract exists: `我的` remains the third public tab and carries settings/account/legal/care entries; `长辈关怀` is Profile/Care content, not a tab rename.
- Task 6 is complete: deterministic hash-based trial-slot selection was replaced with persistent exclusive assignment, legacy `S_` profiles remain readable, and app-facing `voiceProfileId` is separated from provider-facing speaker IDs.
- Account purge retires owned provider slots; deleted voice data is never silently recycled to another user.
- Task 7 is complete: Echo now has lifecycle/session and interaction generations, a cancellable background release lease, generation-bound runtime/audio ownership, deterministic tap interruption, guarded microphone recovery, stale PCM isolation, and immediate quota fallback. Ledger `L20260710-133057` is closed.
- Task 8 is complete and deployed: digital-human session leases now support safe persistence, reuse, heartbeat, release, TTL expiry, atomic capacity arbitration, iOS lifecycle cleanup, stale-response release, and non-device/deployed Postgres gates. Backend `e9b3104` is live and ledger `L20260710-145321` is closed.
- Task 9 is complete: opaque user access/refresh sessions, hash-only persistence, refresh rotation/replay rejection, logout revocation, legacy backend-token compatibility, ownership shadow diagnostics, iOS ThisDeviceOnly Keychain consumption, concurrent refresh coalescing, and the optional deployed smoke gate are implemented. Ledger `L20260710-165434` is closed.
- Task 10 is complete: policy decisions distinguish owner/family/time-letter recipient/invitation/system-only access; sensitive care/time-letter/invitation routes bind the verified bearer principal; runtime and QA gates keep production enforce explicitly disabled. Ledger `L20260710-193743` is closed.
- Task 10 deployment evidence is complete: backend `66db803` is live on Postgres; deployed auth rotation/replay/logout and cross-account delegated/forged-viewer smoke passed.
- Task 11 is complete and deployed: its original 54 business routes are explicitly classified, owner/system routes enforce verified principals while global mode remains shadow, delegated family/time-letter policies pass, iOS no longer triggers global dispatch, and backend `275a4c2` passed deployed Postgres gates. Task 12 adds two classified knowledge routes, bringing the current audit total to 56. Ledger `L20260710-222422` is closed.
- Task 12 is complete locally: KBLite user isolation, backend-first extraction, revision/idempotent mutation/change feed, Context Packet generation text, and query-scoped Echo RAG with local fallback are implemented and guarded. Backend deployment and true-device ChatRagText effect verification remain follow-up acceptance boundaries. Ledger `L20260710-231102-12` is closed.
- Task 12 backend `00df327` is deployed and its real Postgres knowledge smoke passed.
- Task 13 is complete locally: backend Mutation V2 supports entity upserts/tombstones and compatible change metadata; iOS persists a per-user remote base/pending payload and performs deterministic three-way merge with local-only protection; the cross-repository gate is `RUN_KNOWLEDGE_V2_SYNC_GATE=1`. Backend commits `3fc5b2d`/`816993b` and iOS commit `e63a5ed` are not yet pushed or deployed. Ledger `L20260711-005948` is closed.

## Scope

Phase 2, Phase 3, and Tasks 9-13 are closed locally. Production remains on global ownership `shadow`; public UI changes remain outside this slice. Before treating Task 13 as deployed, push both repositories, deploy the backend, and run the knowledge V2 combo gate against the public Postgres environment.

## Recovery

On resume, read this file, `findings.md`, `progress.md`, `docs/plans/impl_plan_index.md`, and `.closure-lodestar/task-ledgers.json`; then run:

```bash
python3 ~/.codex/skills/closure-lodestar/scripts/recover.py --workspace .
```
