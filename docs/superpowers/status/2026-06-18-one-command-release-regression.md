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

## Optional Release-like Backends

Postgres release-like backend remains optional in this runner because the current machine has no Docker/Postgres runtime.

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

- The runner is a regression harness, not a claim that true-device or Postgres acceptance has passed.
- It intentionally keeps Postgres and deployed backend checks opt-in until the runtime exists.
- The runner writes a `report.md`, command logs, build log, and smoke evidence under `tmp/visual-qa/prd-stitch-ui/release-regression/<run-id>/`.
