# Group 6 Release QA Package Report

Date: 2026-06-17

Target:

- Make the final QA evidence package repeatable.
- Protect commit hygiene before this large UI/PRD adaptation branch is split for review.

Added guard:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

The guard checks:

- required status docs;
- Group 1-5 reports and successful build logs;
- release feature matrix and hidden-branch policy;
- source-of-truth policy for Stitch canvas/htmlCode;
- latest archive-to-echo smoke result and screenshot;
- Generated DerivedData ignore rule.

Latest smoke evidence at creation time:

- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-133201/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-133201/01-archive-to-echo-completed.png`

Build evidence:

- `tmp/visual-qa/prd-stitch-ui/group6-release-qa-package/20260617-current/build-final.log`

Expected result:

```text
Release QA package checks passed with latest smoke 20260617-133201
```
