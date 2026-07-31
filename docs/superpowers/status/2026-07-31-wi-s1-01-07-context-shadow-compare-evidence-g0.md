# WI-S1-01-07: Same-Request Context Compare QA Evidence G0

Status: `VERIFIED_LOCAL / QA_ONLY / DEFAULT_OFF / NOT_DEPLOYED / NO_CUTOVER`

Related backend baseline: `DreamJourneyBackend main@9907365`

## Goal

Connect the existing value-minimized V1/V4 same-request Context comparison to
the existing Echo QA evidence path. The comparison must remain observational:
it cannot change public Context selection, answer generation, fallback,
authority, persistence, or product UI.

## Implemented Boundary

- Adds a dedicated `EchoOwnerTruthContextShadowCompareLease`; it is distinct
  from the public Context and existing Context-shadow leases.
- Starts a compare only when both Owner Truth QA gates are enabled, the active
  account lease is allowed, the selected identity is the current self-owner,
  and the query has a non-empty normalized fingerprint.
- Fences every compare callback by generation and runtime account lease. A
  superseded request or Context invalidation drops its late callback.
- Exports only a re-hashed request correlation, V1/V4 counts, state,
  fallback counts, authority/checkpoint presence, and typed-citation
  completeness through the existing QA panel and evidence bundle.
- Extends the existing QA export fixture with a strict value-free comparison
  payload. The fixture rejects raw query text from the exported bundle.

## Validation

- `python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-context-compare-check.py`: passed.
- `xcodebuild test ... -only-testing:DreamJourneyTests/AudioOwnerLeaseModelTests -only-testing:DreamJourneyTests/OwnerTruthContractsTests`: `142/142` passed on iPhone 17 Simulator.
- Generic unsigned iPhoneOS Debug build: passed.
- `git diff --check`: passed.
- `RUN_ID=20260731-0925-context-compare Scripts/QA/prd-stitch-ui/run-echo-qa-evidence-bundle-export-smoke.sh`: passed using local QA bundle ID `com.yxj.dreamjourney.app`. The exported bundle contains the compare readout schema, an `observed` disposition, a matching request correlation, and no raw fixture query. Local report and screenshot: `tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260731-0925-context-compare/report.md` and `01-echo-qa-evidence-bundle-export-smoke.png`.

The focused lifecycle tests cover self-owner and dual-gate admission,
superseded request rejection, and cancellation of a late callback.

## Explicit Non-Claims

- No deployed backend request, PostgreSQL smoke, Provider call, public UI, or
  true-device claim was made.
- The compare output does not prove semantic parity, retrieval quality, data
  migration readiness, or cutover readiness.
- The public `/context/build` contract and normal Echo request flow are
  unchanged.
