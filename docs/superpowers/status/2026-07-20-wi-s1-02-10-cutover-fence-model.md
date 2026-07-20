# WI-S1-02-10 G0 Legacy Effect Cutover Fence Model

Date: 2026-07-20

## Completed Sub-slice

`WI-S1-02-10-G0-CUTOVER_FENCE_MODEL`

This is a deterministic, side-effect-free model for future per-surface
retirement cutovers. It does not enable a worker, change a route, modify a
host timer, make a direct dispatch, observe production, call a Provider, or
approve a candidate.

## Implemented Gate

- `Scripts/QA/product-v4/legacy-effect-cutover-fence-model-smoke.py`
- `Scripts/QA/product-v4/run-legacy-effect-cutover-fence-model-gate.sh`

The model accepts only synthetic booleans for legacy/successor state and
evidence. It proves these outcomes:

| Condition | Required decision |
| --- | --- |
| Legacy and successor are both active, or both see the same stable key | Reopen: duplicate Authority. |
| Legacy callback arrives after successor admission | Reopen: stale legacy callback. |
| Any in-flight work is unknown | Reopen: unknown must not be retried or retired. |
| An old client is observed | Reopen: zero-use window resets. |
| Restart has no durable restore/replay proof | Hold. |
| Zero-use is not observed, successor is inactive, or legacy remains active | Hold. |
| Technical conditions are present but Operations approval is absent | Await external approval. |
| All modeled conditions are present | Ready only for a separate authorization; no removal action exists. |

The model intentionally has no `retired`, `remove`, `delete`, or `revoke`
decision. C11 removal remains a separate, externally authorized activity after
G2/G3 evidence.

## Verification

```bash
bash Scripts/QA/product-v4/run-legacy-effect-cutover-fence-model-gate.sh
git diff --check
```

The gate includes the candidate manifest checker, both existing source
inventories and the TimeLetter local-notification lifecycle guard. It runs no
host, Provider, worker, route or notification operation.

## Gate Position

| Gate | Status | Meaning |
| --- | --- | --- |
| G0 | Partial | Inventory, lifecycle teardown, retirement candidate manifest and fail-closed cutover model are complete. A default-off TimeLetter typed-effect admission shadow is the next concrete effect slice. |
| G1 | Not run | No public UI or simulator interaction changed. |
| G2 | Not started | Production host/process inventory, single scheduler, drain, zero-use, old binary and restore evidence remain required. |
| G3 | Not started | Provider callback/query and credential-owner evidence remain external. |

## Next Sub-slice

`WI-S1-02-10-G0-TIME_LETTER_TYPED_EFFECT_ADMISSION_SHADOW`

This next slice may add a default-off typed admission contract for the already
hidden TimeLetter atomic-delivery service. It must use the existing stable-key
and receipt boundary, keep the legacy direct route/CLI authoritative, avoid
starting a scheduler or worker, and provide only synthetic shadow evidence.
