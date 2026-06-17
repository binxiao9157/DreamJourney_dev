# Submit Slice Inventory Report

Date: 2026-06-17

Target:

- Classify every dirty file into a review/commit slice.
- Keep local generated QA artifacts out of source slices.
- Fail if a dirty file is not covered by the inventory.

Guard:

```bash
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Latest result:

```text
Submit slice inventory checks passed
- 1-project-scaffolding-release-gates: 8
- 2-shell-login-echo-prompt: 7
- 3-archive-core-creation: 11
- 4-profile-care-settings-legal: 3
- 5-source-warning-cleanup: 7
- 5-map-future-route-compatibility: 7
- 6-durable-docs: 12
- 6-optional-qa-evidence: 75
- local-only-generated-qa: 298
- local-only-stitch-cache: 4
```

Build evidence:

- `tmp/visual-qa/prd-stitch-ui/source-warning-cleanup/20260617-current/build-source-warning-batch.log`

Notes:

- `local-only-generated-qa` includes build logs, runtime logs, screenshots, cached HTML, app-path files, and temporary compiled check binaries.
- `6-optional-qa-evidence` includes reusable scripts, reports, smoke result JSON, and Stitch reference screenshots.
- Stage by slice; do not use `git add .` or broad `git add tmp/`.
