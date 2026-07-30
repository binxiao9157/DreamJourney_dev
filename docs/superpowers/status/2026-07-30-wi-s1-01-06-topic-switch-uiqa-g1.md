# WI-S1-01-06 Topic Switch UIQA G1

Date: 2026-07-30

## Completed scope

This sub-slice connects the existing default-off topic-switch lifecycle
contract to an actual QA-only control on the natural-input surface.

- The control is compiled only for the Debug/UIQA presentation and has no
  public navigation entry.
- It sends the existing value-free `pauseForTopicSwitch` intent; it does not
  send topic text, a topic identifier, classifier result or a replacement
  session identifier.
- The existing typed use case pauses the current thread/session first. Only
  after a valid pause receipt does it issue the existing separate start command
  for a replacement session.

## Simulator smoke

```bash
SIMULATOR_UDID=605B899B-77F1-4AA1-8642-15803FE5B647 \
  /Users/yxj/Documents/Codex/Video/DreamJourney_dev/Scripts/QA/prd-stitch-ui/run-owner-truth-interview-topic-switch-smoke.sh
```

The in-memory strict-contract fixture verifies:

1. The QA-only topic-switch button is visible and enabled for an active,
   open session.
2. Pressing the actual button returns an old-session receipt of
   `paused/open`.
3. Exactly one replacement session is created.
4. The replacement has distinct thread and session IDs, is `active/open`, and
   contains no message payload.

Passed result:

- Result: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-topic-switch-smoke/20260730-103406/owner-truth-interview-topic-switch-uiqa-result.json`
- Screenshot: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-topic-switch-smoke/20260730-103406/01-owner-truth-interview-topic-switch.png`

Also passed:

- `bash -n` for the smoke script;
- `DreamJourneyTests/OwnerTruthContractsTests` on the simulator;
- unsigned generic iOS Simulator build;
- `git diff --check`.

## Gate limit

This is G1 local simulator evidence. It does not prove backend persistence,
PostgreSQL behavior, automatic topic classification, provider behavior,
deployment, public-release exposure or true-device behavior.
