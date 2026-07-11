# Implementation Plan Index

## Goal

按照最新 PRD 持续推进 DreamJourney_dev 到可真实测试、可真机验收、可持续迭代状态

## Architecture

- Lodestar owns project status and review.
- Recursive Closure owns task-level legal transitions.

## Task Index

| # | Status | Task | File | Recursive Ledger |
|---|---|---|---|---|
| 1 | done | PRD gap map and priority ledger | `docs/plans/task_01_prd-gap-map-and-priority-ledger.md` | `L20260618-000157-01` |
| 2 | done | P0 persona-scoped archive and echo context | `docs/plans/task_02_p0-persona-scoped-archive-and-echo-context.md` | `L20260618-000157-02` |
| 3 | done | P0 real-device and backend acceptance readiness | `docs/plans/task_03_p0-real-device-and-backend-acceptance-readiness.md` | `L20260618-000157-03` |
| 4 | done | P1 profile family and safety flows | `docs/plans/task_04_p1-profile-family-and-safety-flows.md` | `L20260618-000157-04` |
| 5 | done | Review and release QA | `docs/plans/task_05_review-and-release-qa.md` | `L20260618-000157-05` |
| 6 | done | P0 voice clone exclusive slot allocation | `docs/plans/task_06_p0-voice-clone-exclusive-slot-allocation.md` | `L20260710-115209` |
| 7 | done | P0 Echo digital-human stability | `docs/plans/task_07_p0-echo-digital-human-stability.md` | `L20260710-133057` |
| 8 | done | P0 digital-human session lease and concurrency control | `docs/plans/task_08_p0-digital-human-session-lease.md` | `L20260710-145321` |
| 9 | done | P0 auth session and ownership shadow mode | `docs/plans/task_09_p0-auth-session-ownership-shadow.md` | `L20260710-165434` |
| 10 | done | P0 cross-account authorization policy shadow | `docs/plans/task_10_p0-cross-account-authorization-policy-shadow.md` | `L20260710-193743` |
| 11 | done | P0 full-route ownership audit and principal binding | `docs/plans/task_11_p0-full-route-ownership-audit.md` | `L20260710-222422` |
| 12 | done | P0 unified knowledge pipeline | `docs/plans/task_12_p0-unified-knowledge-pipeline.md` | `L20260710-231102-12` |
| 13 | done | P1 knowledge tombstone and three-way merge | `docs/plans/task_13_p1-knowledge-tombstone-three-way-merge.md` | `L20260711-005948` |
| 14 | done | P0 knowledge evidence integrity and Context isolation | `docs/plans/task_14_p0-knowledge-evidence-and-context-isolation.md` | `L20260711-022449-15` |
| 15 | done | P1 knowledge mutation proposal and persona schema | `docs/plans/task_15_p1-knowledge-mutation-proposal-persona-schema.md` | `L20260711-030653-15` |
| 16 | done | P1 knowledge governance and source cascade | `docs/plans/task_16_p1-knowledge-governance-source-cascade.md` | `L20260711-040419` |
| 17 | done | P1 knowledge operation receipt and conflict recovery | `docs/plans/task_17_p1-knowledge-operation-payload-hash.md` | `L20260711-100251` |
| 18 | done | P1 knowledge change-feed stable pagination | `docs/plans/task_18_p1-knowledge-change-feed-pagination.md` | `L20260711-104956` |
| 19 | done | P1 canonical knowledge source identity and legacy audit | `docs/plans/task_19_p1-canonical-knowledge-source-identity.md` | `L20260711-113033` |
| 20 | done | P0 knowledge mutation/receipt privacy canonicalization | `docs/plans/task_20_p0-knowledge-mutation-privacy-canonicalization.md` | `L20260711-122802` |
| 21 | done | P0 Widget/App Group knowledge privacy lifecycle | `docs/plans/task_21_p0-widget-app-group-knowledge-privacy-lifecycle.md` | `L20260711-145625-21` |
| 22 | done | P0 family relationship authorization and knowledge-candidate isolation | `docs/plans/task_22_p0-family-knowledge-authorization-boundary.md` | `L20260711-153159` |
| 23 | done | P1 local knowledge storage and semantic cache isolation | `docs/plans/task_23_p1-knowledge-local-storage-semantic-cache-isolation.md` | `L20260711-174842` |
| 24 | done | P1 knowledge change retention and snapshot fallback | `docs/plans/task_24_p1-knowledge-change-retention-snapshot-fallback.md` | `L20260711-191536` |
| 25 | done | P1 Echo trace account isolation and logout purge | `docs/plans/task_25_p1-echo-trace-account-isolation.md` | `L20260711-200812` |
| 26 | create-solution-ticket | P0 knowledge operation receipt retention and minimization | `docs/plans/task_26_p0-knowledge-operation-receipt-minimization.md` | `L20260711-205750` |

## File Structure

- `task_plan.md`
- `findings.md`
- `progress.md`
- `docs/plans/impl_plan_index.md`
- `docs/plans/task_N_*.md`
- `.closure-lodestar/task-ledgers.json`
- `.complex-problems/`
