# Task Plan

## STATUS

- **Goal:** 按照最新 PRD 持续推进 DreamJourney_dev 到可真实测试、可真机验收、可持续迭代状态
- **Mode:** Execute
- **Phase:** Implementation
- **Task:** continue non-device PRD function development; latest slice is deployed Postgres backend acceptance
- **Blockers:** true-device signing/operation still required for final acceptance; newest Stitch Echo variants still need explicit selection before replacing the current public Echo surface

## Key Decisions

- Closure Lodestar is active: Lodestar files are the project-level source of truth.
- Recursive Closure ledgers are task-level closure engines under `.complex-problems/`.
- Task 1 closed: PRD continuation gap map is recorded in `docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md`.
- Task 2 closed: persona-scoped archive storage/backend/context contract is implemented and guarded.
- Task 3 closed: real-device/backend acceptance readiness is documented and guarded; true backend/device execution still waits for user-provided environment.
- Task 4 closed: hidden family/persona switcher, profile safety shells, and care visibility gates are implemented and guarded.
- Task 5 closed: release QA handoff is documented and simulator/static QA passed.
- Post-review continuation: `长辈关怀` aggregate child dashboard, hidden `阳光 / 星辰 / 静默` mode management, Echo/Profile lifecycle effects, hidden profile care escalation draft, care escalation draft-only backend boundary smoke, archive media release readiness contract, archive media entries smoke harness, family/persona release readiness smoke, App-side backend family acceptance hardening, PRD coverage matrix, phase 0 backend alignment with the existing `DreamJourneyBackend`, release-like backend acceptance harness, one-command release regression, and final Stitch visual refresh are complete without true-device execution.
- Current target after this slice: release-like FastAPI/Postgres backend acceptance passed with run `20260618-deployed-postgres-acceptance-after-deploy`; `我的` remains the third public tab and carries settings/account/legal/care entries, while newest Stitch Echo variants remain candidates until explicitly selected.
- Profile IA contract exists: `我的` remains the third public tab and carries settings/account/legal/care entries; `长辈关怀` is Profile/Care content, not a tab rename.

## Scope

To be refined in docs/plans/task_N.md files.

## Recovery

On resume, read this file, `findings.md`, `progress.md`, `docs/plans/impl_plan_index.md`, and `.closure-lodestar/task-ledgers.json`; then run:

```bash
python3 ~/.codex/skills/closure-lodestar/scripts/recover.py --workspace .
```
