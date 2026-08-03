# WI-S0-07-05 Provider Cost Preflight

## Scope

This record preserves the scoped provider cost/usage implementation deployed in
backend `main@ea5cc5d`. It is a preflight for `WI-S0-07-05`, not a closure of
that work item and not evidence for `WI-S0-07-08`.

## Implemented Boundary

- Value-free provider usage events cover the current voice synthesis, legacy
  TTS, map lookup, knowledge extraction, and archive image-analysis routes.
- Event identifiers are HMAC-derived; prompts, media, credentials, direct
  identities, request bodies, and provider responses are excluded.
- Cost provenance is explicit: `unknown`, `providerMetered`, or
  `approvedRateCard`.
- Unknown cost, missing commercial budget, or an unapproved circuit policy is
  reported as `notReady`; no budget or provider expansion is inferred.

## Verification

- Backend verification suite: 582 tests passed.
- Isolated deployed Postgres smoke passed against the deployed API.
- The deployed smoke confirmed two persisted events, one unknown-cost event,
  one known-cost event, and the expected `providerCostUnknown` readiness
  result.

## Remaining Gate

`G3` remains open for provider billing receipts, quota/quality evidence,
approved commercial budget, and an approved circuit-breaker policy. This
record must never be used to claim those decisions or to close `WI-S0-07-05`.
