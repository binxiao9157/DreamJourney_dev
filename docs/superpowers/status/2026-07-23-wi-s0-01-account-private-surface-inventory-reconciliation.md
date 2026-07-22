# V4 Account Private-Surface Inventory Reconciliation

- Date: 2026-07-23
- Scope: reconciliation for the already implemented `WI-S0-01-07` / `WI-S0-01-08` account-owner boundaries.
- Status: internal source, lifecycle, and regression gates passed. This record does not change conservative Registry gate status or make a release claim.

## Problem

The account-store discovery gate identified two private-state candidates that were not
explicitly accounted for:

1. Profile data export used a shared temporary directory. A later account transition
   could not prove the export belonged to the captured account lease.
2. The Owner Truth KBLite compatibility cache contains private-cache mechanics, but it
   has no runtime construction site and is intentionally default-off QA-only. It must
   be a guarded exception rather than an invisible discovery omission.

The same gate also exposed two stale static expectations:

- simulator-only Owner Truth smoke report writers were not consistently behind the
  `UI_QA_SIMULATOR` compile boundary;
- the time-letter scheduler check still expected an older notification API shape.

## Implemented Boundary

### Owner-scoped personal-data exports

- `AccountDataExportTemporaryStore` derives a SHA-256 scope from every
  `AccountLease` identity field: subject, vault, session, generation, generation ID,
  and authority epoch.
- Personal-data JSON is written only beneath
  `DreamJourneyDataExports/<scopeDigest>/` with atomic write and complete file
  protection.
- The export contract owner must match the captured lease at request and commit.
- Share completion removes only the exact file in the matching lease scope.
- Account switch, logout, suspension, and deletion now clear the old lease scope via
  `LM-11-widget-and-temporary-exports`; stale legacy unscoped export files are also
  retired during that lifecycle cleanup and are never mounted as current data.

### Default-off Owner Truth compatibility cache

- The cache remains QA-only and has no current runtime instantiation.
- Its envelope remains bound to the full account lease and validates request, commit,
  and runtime checkpoints before preserving a projection.
- The inventory has an explicit exclusion backed by
  `owner-truth-kblite-compatibility-cache-boundary-check.py`. Any future runtime
  construction must first add a registered lifecycle adapter and a real inventory
  surface instead of relying on this exception.

### QA boundary repair

- Interview session-state and natural-input smoke report writers are compiled only for
  the simulator UI-QA target.
- The archive lease static check now verifies the current scoped capture and injected
  notification request port, rather than the superseded API form.

## Verification

Passed locally:

```text
python3 Scripts/QA/product-v4/account-data-export-owner-scope-check.py
python3 Scripts/QA/product-v4/owner-truth-kblite-compatibility-cache-boundary-check.py
bash Scripts/QA/product-v4/run-account-store-inventory-gate.sh
bash Scripts/QA/product-v4/run-account-lifecycle-module-registry-gate.sh
bash Scripts/QA/product-v4/run-message-notification-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh
RUN_ID=20260723-account-export-owner-scope-final bash Scripts/QA/prd-stitch-ui/run-iphoneos-generic-build.sh
RUN_ID=20260723-account-export-owner-scope-final RUN_STANDARD_BUILD=0 RUN_SIMULATOR_SMOKE=0 RUN_STAGE0_STRICT_READINESS_GATE=0 RUN_KNOWLEDGE_PRIVACY_MAINTENANCE_GATE=0 bash Scripts/QA/prd-stitch-ui/run-release-regression.sh
git diff --check
```

Evidence:

- iPhoneOS generic build: `tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260723-account-export-owner-scope-final/report.md`
- release regression: `tmp/visual-qa/prd-stitch-ui/release-regression/20260723-account-export-owner-scope-final/report.md`

## Deliberate Non-Claims

- No public UI or product route changed.
- No external provider, deployed backend, real device, or data migration was exercised.
- This does not mark any Registry `G0`/`G2`/`G3`/`G4` gate as passed; it only removes an
  internal private-surface discovery regression from the current source baseline.
