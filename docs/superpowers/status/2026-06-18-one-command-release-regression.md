# One-command Release Regression

Date: 2026-06-18

## Status

This slice adds the one-command release regression entry for the current PRD/UI MVP candidate.

Primary command:

```bash
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

The default run covers:

- backend unit/FastAPI smoke through the sibling `DreamJourneyBackend` repo;
- Python QA script compilation;
- static release/PRD/UI guard scripts;
- `git diff --check` for iOS and backend worktrees;
- standard iOS Debug simulator build;
- Archive -> Echo simulator smoke.
- Echo delayed reply persistence/local-notification smoke.

## P0 Profile Care Regression Gate

Use this when validating the public MVP `我的 -> 心境追踪 / 长辈关怀` loop after UI, backend, or release packaging changes:

```bash
RUN_P0_PROFILE_CARE_REGRESSION=1 \
RUN_ID=20260619-p0-profile-care \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

`RUN_P0_PROFILE_CARE_REGRESSION=1` forces both lower-level switches:

- `RUN_PROFILE_CARE_STATE_SMOKE=1`
- `RUN_PROFILE_CARE_BACKEND_STATE_SMOKE=1`

The gate covers local empty / stale / failed UIQA plus deployed backend active / empty / stale / failed-retry UIQA. The deployed backend smoke also verifies that failed-state `重新同步` returns from loading to `关怀信号加载失败` and keeps the retry entry visible when the backend still fails.

## Release Handoff Mode

Use this when backend credentials are available and the build is being prepared for broader handoff:

```bash
RELEASE_HANDOFF_MODE=1 \
BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn \
BACKEND_API_TOKEN='<server token from private access doc>' \
RUN_ID=20260618-release-handoff \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

This forces release-like FastAPI/Postgres acceptance to run as part of the one-command package and cannot be disabled by RUN_RELEASE_LIKE_BACKEND=0. For local dry runs without a backend, keep `RELEASE_HANDOFF_MODE=0`.

Release handoff mode must include these gates:

- PRD decision guard: `prd-full-feature-closure-decisions-check.swift`
- Echo notification guard: `echo-delayed-reply-notification-check.swift` and `echo-delayed-reply-push-contract-check.swift`
- Profile account fields guard: `profile-account-fields-check.swift`
- Archive ownership guard: `archive-ownership-visibility-check.swift`
- Care placeholder guard: `profile-care-public-placeholder-check.swift`
- Release-like backend acceptance: `run-release-like-backend-acceptance.sh`

For public MVP care handoff, add `RUN_P0_PROFILE_CARE_REGRESSION=1` to the release handoff command so care state local UIQA and deployed backend failure-retry UIQA run in the same package.

## Optional Release-like Backends

Postgres release-like backend remains optional in the default runner because not every machine has backend credentials or Docker/Postgres runtime.

Enable it only when the environment is available:

```bash
RUN_RELEASE_LIKE_BACKEND=1 \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

For an already deployed backend:

```bash
RUN_BACKEND_ENV_SMOKE=1 \
BACKEND_BASE_URL=https://example.com/dreamjourney-api \
BACKEND_API_TOKEN='<server token>' \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

## Notes

- The runner is a regression harness, not a claim that true-device acceptance has passed.
- It intentionally keeps Postgres and deployed backend checks opt-in for default local runs, but `RELEASE_HANDOFF_MODE=1` makes release-like backend acceptance mandatory.
- The runner writes a `report.md`, command logs, build log, and smoke evidence under `tmp/visual-qa/prd-stitch-ui/release-regression/<run-id>/`.
