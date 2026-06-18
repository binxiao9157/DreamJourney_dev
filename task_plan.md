# Task Plan

## STATUS

- **Goal:** 按照最新 PRD 持续推进 DreamJourney_dev 到可真实测试、可真机验收、可持续迭代状态
- **Mode:** Execute
- **Phase:** Implementation
- **Task:** continue non-device PRD function development; latest slice is final Stitch visual refresh
- **Blockers:** Docker/Postgres or deployed backend URL/token, plus true-device signing/operation for final acceptance

## Key Decisions

- Closure Lodestar is active: Lodestar files are the project-level source of truth.
- Recursive Closure ledgers are task-level closure engines under `.complex-problems/`.
- Task 1 closed: PRD continuation gap map is recorded in `docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md`.
- Task 2 closed: persona-scoped archive storage/backend/context contract is implemented and guarded.
- Task 3 closed: real-device/backend acceptance readiness is documented and guarded; true backend/device execution still waits for user-provided environment.
- Task 4 closed: hidden family/persona switcher, profile safety shells, and care visibility gates are implemented and guarded.
- Task 5 closed: release QA handoff is documented and simulator/static QA passed.
- Post-review continuation: `长辈关怀` aggregate child dashboard, hidden `阳光 / 星辰 / 静默` mode management, Echo/Profile lifecycle effects, hidden profile care escalation draft, care escalation draft-only backend boundary smoke, archive media release readiness contract, archive media entries smoke harness, family/persona release readiness smoke, App-side backend family acceptance hardening, PRD coverage matrix, phase 0 backend alignment with the existing `DreamJourneyBackend`, release-like backend acceptance harness, one-command release regression, and final Stitch visual refresh are complete without true-device execution.
- Current target after this slice: confirm product/design direction for the newest Stitch Echo variants and `长辈关怀`/`我的` information architecture; otherwise run release-like FastAPI/Postgres acceptance when Docker/Postgres or a deployed backend URL/token is available.

## Scope

To be refined in docs/plans/task_N.md files.

## Recovery

On resume, read this file, `findings.md`, `progress.md`, `docs/plans/impl_plan_index.md`, and `.closure-lodestar/task-ledgers.json`; then run:

```bash
python3 ~/.codex/skills/closure-lodestar/scripts/recover.py --workspace .
```
