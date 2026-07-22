# WI-S0-05-06 Data Rights Status G0

Date: 2026-07-23

## Scope Reached

The iOS client now maps the existing authenticated `/auth/delete` receipt to a
typed, value-minimized `AccountDataRightsStatusSnapshot`. The G0 scope is
strictly local: no new status endpoint, no public status screen, and no change
to the existing two-step deletion flow.

- Captures request ID/status/counts, access/deletion state, retention/restore
  policy, and the existing export policy boundary.
- Maps a compact `rights.status=completed` summary to
  `pendingExternalEvidence`, never to physical cleanup complete.
- Caches the snapshot only under a full AccountLease digest and validates the
  lease at request, commit, and UI read checkpoints.
- Removes the scoped receipt and a legacy unscoped key during account lifecycle
  teardown. Cache write failure never blocks the backend-authoritative
  access-first deletion transition.

## Verification

Passed locally:

    python3 -m py_compile Scripts/QA/product-v4/account-data-rights-status-owner-scope-check.py
    python3 Scripts/QA/product-v4/account-data-rights-status-owner-scope-check.py
    python3 Scripts/QA/product-v4/account-deletion-lifecycle-static-check.py
    Scripts/QA/product-v4/run-account-store-inventory-gate.sh
    swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift "$PWD"
    Scripts/QA/prd-stitch-ui/run-release-regression.sh --minimal
    xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphoneos ... build
    git diff --check

The workspace build used the local test identity override
`com.yxj.dreamjourney.app / 2BTR77V3R8` and succeeded. The first project-only
build was intentionally discarded because it bypassed CocoaPods and could not
resolve its dependencies.

## Remaining Gates

| Gate | Status | Remaining evidence |
| --- | --- | --- |
| G0 | Scoped complete | Typed mapping, owner-scoped cache, lifecycle cleanup, and static/runtime regression evidence. |
| G1 | Open | A product-facing data-rights status surface and accessibility/device flow. |
| G2 | Open | Authenticated status/read contract and deployed Postgres evidence. |
| G3/G4 | Open | Object/provider/backup deletion evidence and Privacy/Legal product approval. |

This receipt cannot certify external physical deletion. It is only a truthful
local bridge over the accepted access-revocation contract.
