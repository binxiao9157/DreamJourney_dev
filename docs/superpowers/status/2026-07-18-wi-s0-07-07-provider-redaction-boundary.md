# WI-S0-07-07 Provider Diagnostics Redaction Boundary

Date: 2026-07-18

## Status

- Work Item: `WI-S0-07-07`
- Authority lock: `OPERATIONS_EVIDENCE`
- Execution owner: `codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- Result: `INTERNAL_READY / BACKEND_DEPLOYED / G0_G1_G2_SCOPED_VERIFIED / IOS_LOCAL_COMMITTED / G3_G4_EXTERNAL_OPEN`
- Scope: provider dry-run responses, provider failure diagnostics, iOS Echo diagnostics, and QA evidence exports.

## Delivered Boundary

### Backend

- Added `app/observability/redaction.py` with a strict metadata-only provider dry-run contract.
- Provider dry-run responses now expose only machine-safe provider/capability state, configuration state, fixed transport metadata, and bounded numeric summaries.
- Dry-run routes do not return upstream request bodies, prompts, transcript text, image/base64 input, media input, provider response bodies, direct identifiers, or credentials.
- Provider failures use stable codes, retry/configuration state, and the redaction policy version instead of raw exception or upstream response text.
- Voice-clone public and persisted profile paths retire legacy provider-message fields and retain only safe provider status/error-code metadata plus hashed request/log references where needed.
- Added local and deployed smoke coverage using unique canary values across KB extraction, image analysis, TTS, and map lookup dry-run routes.

### iOS

- Added `PrivacySafeDiagnostics` for Echo, KBLite, provider, digital-human, and PCM-drive runtime diagnostics.
- Runtime logs now use allowlisted event names, state codes, counts, and truncated correlation hashes rather than raw turn IDs, archive IDs, user content, request bodies, provider messages, or response payloads.
- Added `EchoDiagnosticExportRedactor` so Echo traces, runtime diagnostics, evidence packages, and QA bundles carry `redactionPolicyVersion=iosDiagnostics-v1` and hashes/safe codes only.
- Updated trace/evidence/UIQA scripts and the PCM-drive true-device contract checker to validate the redacted schema without reintroducing raw values into test output.
- Added `Scripts/QA/product-v4/provider-redaction-boundary-check.py` to reject disallowed sensitive Swift `print(...)` interpolation in the governed source surfaces.

## Verification

Backend local:

```text
./scripts/verify_backend.sh
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python scripts/backend-provider-redaction-smoke.py
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python scripts/backend-knowledge-evidence-smoke.py
git diff --check
```

- Passed: 575 backend tests, FastAPI smoke, credential response boundary smoke, voice-clone smoke, knowledge evidence smoke, provider redaction smoke, receipt/backup checks, Python compilation, and diff check.
- Provider redaction smoke result: `policyVersion=providerDryRun-v2`, `surfaces=4`, `status=passed`.

iOS local:

```text
python3 Scripts/QA/product-v4/provider-redaction-boundary-check.py
swift Scripts/QA/prd-stitch-ui/true-device-tencent-backend-pcm-drive-smoke-check.swift .
bash -n Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -sdk iphonesimulator -configuration Debug -derivedDataPath tmp/v4-redaction-build CODE_SIGNING_ALLOWED=NO build
SIMULATOR_NAME='iPhone 17 Pro' Scripts/QA/prd-stitch-ui/run-echo-trace-export-uiqa-smoke.sh
SIMULATOR_NAME='iPhone 17 Pro' Scripts/QA/prd-stitch-ui/run-echo-qa-evidence-bundle-export-smoke.sh
git diff --check
```

- Passed: source redaction guard (`targets=7`, `printBlocks=67`), PCM-drive contract checker, shell syntax, Debug simulator build, both simulator export smokes, and diff check.
- Export smoke artifacts contain no injected raw canary values:
  - `tmp/visual-qa/prd-stitch-ui/echo-trace-export-smoke/20260718-220248/`
  - `tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260718-220311/`

## Deployment Evidence

Backend was pushed to `origin/main` and deployed to the production API container. The final deployed revision is `2a98527` (the redaction implementation starts at `63d47df`; subsequent commits only harden the deployed smoke to use the enforced user-principal and hidden-feature contracts).

Server verification:

```text
python scripts/migrate_db.py --verify --build-id 2a98527
status=ready
appliedHead=0009

scripts/run-backend-provider-redaction-deployed-smoke.sh
policyVersion=providerDryRun-v2
providerDryRunReports=2
safePolicyDenials=2
safeProviderErrors=0
surfaces=4
userRouteAuthentication=opaqueAccessToken
status=passed
```

- The smoke issues a short-lived opaque user session directly through the deployed Postgres session contract, invokes the public API through the production URL, then removes the isolated smoke user/session rows.
- `/kb/extract` and `/maps/district` return redaction reports. `/archive/image-analysis` and `/tts` remain intentionally unavailable under the default public ReleasePolicy and return verified safe `403` denial contracts instead of executing a hidden provider capability.
- All four responses were checked for fixed input canaries, the temporary user ID, and the opaque access token. None were present.

## Non-Goals And Open Boundaries

1. This item does not claim that every historic log, external provider console, load balancer, device syslog, or third-party retention system is redacted or retained under the same policy.
2. This item does not alter user-facing Echo UI or provider behavior; it constrains diagnostic and export surfaces only.
3. Provider credential rotation remains covered by the accepted risk exception and is not re-opened by this work item.
4. Cost evidence, production retention controls, and external Operations/Privacy approval remain separate work items and must not be inferred from this local boundary.
