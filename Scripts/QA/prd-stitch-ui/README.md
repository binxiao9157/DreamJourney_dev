# PRD Stitch UI QA Scripts

This directory stores durable QA and smoke scripts for the PRD/Stitch UI adaptation work.

Conventions:

- Keep reusable `.swift`, `.sh`, and `.py` QA scripts in `Scripts/QA/prd-stitch-ui/`.
- Keep generated reports, build logs, DerivedData, screenshots, and smoke outputs under `tmp/visual-qa/prd-stitch-ui/`.
- `tmp/` is ignored and may be cleaned at any time; do not place durable scripts there.
- Historical evidence already tracked under `tmp/visual-qa/prd-stitch-ui/` is kept for traceability, but new evidence should be treated as generated output unless it is intentionally promoted into `docs/superpowers/status/`.

Common commands:

```bash
Scripts/QA/prd-stitch-ui/run-release-regression.sh
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/digital-human-runtime-abstraction-check.swift "$PWD"
swift Scripts/QA/prd-stitch-ui/tencent-digital-human-audio-owner-stop-semantics-check.swift "$PWD"
```
