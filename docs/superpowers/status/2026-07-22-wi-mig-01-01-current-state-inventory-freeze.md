# WI-MIG-01-01 C00 Current-State Inventory Freeze

Date: 2026-07-22

## Scope

This closes only the source-inventory portion of C00. It is a read-only,
value-free freeze of checked-in iOS and backend evidence. It does not migrate
data, alter schema or deployment configuration, inspect `.env` values, call a
Provider, or assert a production cutover.

## Implemented

- `Scripts/QA/product-v4/current-state-inventory-v1.json` owns one source
  surface for each of the 13 V4 packages and covers the `W/I/P/Q/O/V` planes.
- `Scripts/QA/product-v4/current-state-inventory-freeze.py` validates source
  anchors, hashes only source files, records repository revisions and dirty
  state, and emits a value-free report.
- `Scripts/QA/product-v4/product-v4-current-state-inventory-check.py` proves
  deterministic output, package/plane coverage, marker-drift failure, and the
  absence of credential-value fields or absolute local paths.
- `Scripts/QA/product-v4/run-current-state-inventory-freeze-gate.sh` is now
  called by the existing release regression and saves its report beneath the
  release run output.

## Verification

Passed locally:

```bash
python3 Scripts/QA/product-v4/product-v4-current-state-inventory-check.py
RUN_ID=20260722-c00-release-gate \
  OUTPUT_ROOT=/tmp/dreamjourney-c00-release-gate \
  BACKEND_ROOT=/Users/yxj/Documents/Codex/Video/DreamJourneyBackend \
  Scripts/QA/product-v4/run-current-state-inventory-freeze-gate.sh
BACKEND_ROOT=/Users/yxj/Documents/Codex/Video/DreamJourneyBackend \
  swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .
RUN_ID=20260722-c00-release-regression \
  RUN_STANDARD_BUILD=0 RUN_SIMULATOR_SMOKE=0 \
  RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 \
  RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE=0 \
  bash Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

The release report is at:

`tmp/visual-qa/prd-stitch-ui/release-regression/20260722-c00-release-regression/report.md`

## Gate Boundary

| Gate | Status | Meaning |
| --- | --- | --- |
| G0 | Verified | 13 package surfaces and all required planes have a unique owner, status, source evidence hash, and no `UNKNOWN` source surface. |
| G2 | Open | Operations must still validate deployed client distribution, host timers, backup and isolated restore. |
| G3 | Open | Object storage and Provider execution/exit evidence are not inferred from source. |
| G4 | Open | Privacy, legal, product, and production go/no-go decisions remain separate. |

## Next Boundary

`WI-MIG-01-02 / C01` may be planned only around a real isolated backup and
restore path. This C00 evidence does not authorize a migration, data backfill,
or production cutover.
