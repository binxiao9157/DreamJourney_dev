# WI-S1-01-06 Interview Orchestration UIQA G1

Date: 2026-07-30

## Completed scope

This sub-slice adds a default-off simulator UIQA harness for the existing
QA-only interview-orchestration read contract.

- It is reached only through `DJRunOwnerTruthInterviewOrchestrationSmoke`
  together with `DJEnableOwnerTruthCandidateReviewQA`.
- The QA page has no product navigation entry and is compiled only in the
  simulator UIQA branch.
- Its in-memory client supplies a strict, value-free fixture. It does not
  call the backend, a provider, or a persistent store.

## Asserted boundary

The smoke sends the exact existing `userChangedTopic` signal and verifies:

- advisory action `pause`;
- reason `topicChanged`;
- next-session recommendation `paused`;
- persisted session remains `active` and `open`.

The page contains generic policy labels and counters only. It does not render
topic text or identifiers, transcript/prompt data, source/candidate/memory
identifiers, authorization claims, or provider data. It cannot write pacing,
Candidate, Source, DecisionReceipt, MemoryVersion, or runtime effects.

## Verification

```bash
SIMULATOR_UDID=605B899B-77F1-4AA1-8642-15803FE5B647 \
  /Users/yxj/Documents/Codex/Video/DreamJourney_dev/Scripts/QA/prd-stitch-ui/run-owner-truth-interview-orchestration-smoke.sh
```

Passed local result:

- `completed=true`, `qaGateEnabled=true`, `stateRendered=true`;
- `action=pause`, `reasonCode=topicChanged`, `nextSessionState=paused`;
- `persistedLifecycle=active`, `persistedBoundary=open`.

Artifacts:

- Result: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-orchestration-smoke/20260730-102157/owner-truth-interview-orchestration-uiqa-result.json`
- Screenshot: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-orchestration-smoke/20260730-102157/01-owner-truth-interview-orchestration.png`

Also passed:

- `bash -n` for the smoke script;
- `DreamJourneyTests/OwnerTruthContractsTests` on the simulator;
- unsigned generic iOS Simulator build;
- `git diff --check`.

## Gate limit

This is G1 local simulator evidence only. It does not prove backend delivery,
PostgreSQL persistence, provider behavior, deployment, public-release
exposure, or true-device behavior.
