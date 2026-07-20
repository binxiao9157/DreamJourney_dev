# WI-S1-02-10 G0 Legacy Timer / Callback Inventory

Date: 2026-07-20

## Completed Sub-slice

`WI-S1-02-10-G0-LEGACY_TIMER_CALLBACK_INVENTORY`

This is an inventory-only closure. It does not cut over, disable, retire, or
start any scheduling surface, worker, host timer, local notification, Provider
query, or callback path.

## Inventory Evidence

### Backend

Backend `main` adds the value-free source inventory and gate:

- `docs/backend/legacy-timer-callback-inventory-v1.json`
- `app/async_effects/legacy_timer_callback_inventory.py`
- `scripts/check_legacy_timer_callback_inventory.py`
- `scripts/run-backend-legacy-timer-callback-inventory-gate.sh`

The inventory covers API startup/shutdown, direct TimeLetter API and CLI
dispatch, the documented-but-not-repository-managed TimeLetter host timer,
default-disabled async scheduler, digital-human heartbeat route, disabled
Provider callback/query boundary, and the three checked-in operations timers.

The backend gate reports 10 entries, 11 source references, 3 legacy direct
effect surfaces, 4 host-unverified surfaces, and 1 external Provider boundary.
`HOST_UNVERIFIED_G2_REQUIRED` deliberately remains explicit for every host
timer state that static source cannot prove.

### iOS

iOS adds the paired static inventory and gate:

- `Scripts/QA/product-v4/legacy-timer-callback-inventory-v1.json`
- `Scripts/QA/product-v4/legacy-timer-callback-inventory-check.py`
- `Scripts/QA/product-v4/run-legacy-timer-callback-inventory-gate.sh`

It separates product/runtime surfaces from pure presentation/playback timers:

| Group | Surfaces |
| --- | --- |
| Product or runtime | Echo delayed-reply local notification, TimeLetter local notification, voice-clone poll, digital-human heartbeat, dialog silence timeout |
| Pure UI/playback | Digital-human audio meter, memoir progress, archive recording duration, footprint banner dismiss |

The guard source-scans all `Timer.scheduledTimer` uses under
`DreamJourney/Sources` so a newly introduced timer cannot remain unclassified.

## Discovered Follow-up

`TimeLetterReminderScheduler` correctly scopes its scheduling callback with an
`AccountLeaseRuntime` validation, but it has no dedicated pending-notification
teardown registered in `AccountLifecycleRuntimeRegistry`. This must not be
silently treated as equivalent to `EchoDelayedReplyNotificationScheduler`,
which already has explicit account-lifecycle cleanup.

The next sub-slice is therefore:

`WI-S1-02-10-G0-TIME_LETTER_NOTIFICATION_LIFECYCLE_GUARD`

It may add lifecycle-safe cancellation for TimeLetter notification requests,
but it must preserve the sealed TimeLetter data contract and must not modify
server delivery, host timers, worker state, or public UI.

## Verification

```bash
Scripts/QA/product-v4/run-legacy-timer-callback-inventory-gate.sh
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
git diff --check
```

The iOS inventory gate passed with 9 entries, 6 actual `Timer` source files,
5 product/runtime surfaces, 4 pure UI/playback exclusions, and the TimeLetter
lifecycle gap explicitly retained.

## Gate Position

| Gate | Status | Meaning |
| --- | --- | --- |
| G0 | Partial | Source inventory and static guard are present; the TimeLetter notification lifecycle gap remains open. |
| G1 | Not run | No simulator behavior was changed in this inventory-only slice. |
| G2 | Open | Deployed process/timer, single-scheduler, drain, zero-use, and old-binary evidence are not yet collected. |
| G3 | Open | Provider callback/query applicability and authorization remain external. |

The complete work item remains in progress. This document is not retirement,
cutover, or production scheduler evidence.
