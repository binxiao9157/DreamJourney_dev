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

## 2026-07-23 Refresh

The original checker carried its backend route and migration baseline as
hard-coded test literals. That became stale after the formal interview routes
and migration `0038` were added, so the gate correctly failed instead of
silently treating the old source snapshot as current.

The manifest now owns the explicit value-free backend freeze baseline:

- `routeAuditExpectedCount=106`
- `migrationManifestCount=38`
- `migrationHead=0038_owner_truth_interview_do_not_ask_restore_receipts.json`
- SHA-256 of that migration manifest

The generator compares the live source baseline to this manifest before it
emits a report. A route, migration count, migration head, or migration manifest
hash drift now fails the C00 gate until the freeze is deliberately refreshed.
The iOS runtime surface also hashes only committed, value-free configuration
anchors: `Info.plist`, Backend/Voice SDK example xcconfig files, and the
tracked Tencent XCFramework metadata. Local `*.local.xcconfig`,
`LocalConfig.plist`, credential values, and the currently user-modified Xcode
project file remain outside this source-only report.

The matching backend route-authentication baseline was committed as
`main@9e98766`, deployed, and verified against the production Postgres
environment. `/ready` returned `status=ready` through both the host-local and
public endpoint, while the deployed route smoke reported `routeCount=106` and
the expected user, machine, and public authorization decisions. This confirms
the source-freeze baseline is current; it does not convert the remaining G2,
G3, or G4 evidence into completed gates.

## 2026-08-08 Refresh

The source-only manifest was deliberately refreshed after committed backend
work added migrations through `0083` and extended the registered route
inventory to `173`. The new checked-in static baseline is:

- `routeAuditExpectedCount=173`
- `migrationManifestCount=83`
- `migrationHead=0083_publication_lifecycle_external_cleanup.json`
- SHA-256 `712129a04d73633f4ff9f1ecdc3a3e7fb6ecad2503916e3c1c6b4a07c323cd12`

This refresh followed the backend route registry/authentication verification
and full local backend verification. It keeps C00 honest about the current
checked-in source baseline; it does not execute a migration, claim deployed
schema parity, or close G2/G3/G4.

## Next Boundary

`WI-MIG-01-02 / C01` may be planned only around a real isolated backup and
restore path. This C00 evidence does not authorize a migration, data backfill,
or production cutover.
