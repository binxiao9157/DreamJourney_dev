# WI-S1-01-06 Interview Pacing UIQA G1

Date: 2026-07-30

## Completed scope

This sub-slice closes the QA-only pacing state boundary for the existing
private interview session contract. It is default-off and is not reachable
from public Echo or Archive navigation.

- Backend commit `3ea898a` adds an exact QA-header-only pacing command:
  `POST /v2/vaults/{vault_id}/interview-sessions/{session_id}/pacing`.
- The request accepts only `commandId`, `threadId`,
  `expectedSessionVersion`, and one of `deepeningCompleted` or
  `summaryCompleted`.
- The domain allows `summaryCompleted` only after at least two completed
  deepening turns. A summary resets the deepening count so the next turn can
  deepen again.
- The iOS typed client and use case keep the existing QA gate,
  `AccountLease`, and generation fence. The natural-input QA surface exposes
  the two actions only under `UI_QA_SIMULATOR`.

No interview text, topic, source, candidate, memory, provider value, or public
UI is added by this sub-slice.

## Asserted state transition

The simulator fixture drives this exact sequence:

```text
deepeningCompleted x4 -> summaryCompleted -> deepeningCompleted
```

It verifies five total deepening completions, one summary completion, an
observed reset after the summary, a final deepening count of one, and an active
open session receipt.

## Verification

Backend:

- focused pacing, auth, route-ownership, runtime-capability, and state suites;
- full `./scripts/verify_backend.sh` passed, including FastAPI smoke and
  `git diff --check`.

iOS:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney \\
  -configuration Debug \\
  -destination 'platform=iOS Simulator,id=605B899B-77F1-4AA1-8642-15803FE5B647' \\
  -derivedDataPath tmp/visual-qa/product-v4/DerivedDataOwnerTruthInterviewPacingTests \\
  CODE_SIGNING_ALLOWED=NO \\
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' \\
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests test

SIMULATOR_UDID=605B899B-77F1-4AA1-8642-15803FE5B647 \\
  /Users/yxj/Documents/Codex/Video/DreamJourney_dev/Scripts/QA/prd-stitch-ui/run-owner-truth-interview-pacing-smoke.sh
```

Both passed locally. The XCTest target reports `85 tests, 0 failures`.

Artifacts:

- Result: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-pacing-smoke/20260730-110419/owner-truth-interview-pacing-uiqa-result.json`
- Screenshot: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-pacing-smoke/20260730-110419/01-owner-truth-interview-pacing.png`

## Gate limit

This is local G0/G1 evidence only. The backend commit is not pushed or
deployed. It does not establish PostgreSQL persistence, provider behavior,
public-release exposure, or true-device behavior.
