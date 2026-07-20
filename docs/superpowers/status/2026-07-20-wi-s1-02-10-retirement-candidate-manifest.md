# WI-S1-02-10 G0 Legacy Timer / Callback Retirement Candidate Manifest

Date: 2026-07-20

## Completed Sub-slice

`WI-S1-02-10-G0-RETIREMENT_CANDIDATE_MANIFEST`

This closure adds a cross-repository, value-free candidate manifest. It is a
planning and static-validation artifact only. It does not observe a host,
authorize a cutover, start a worker, disable a timer, remove a route, revoke a
credential, invoke a Provider, or change public UI.

## Canonical Artifact

- `docs/superpowers/status/2026-07-20-wi-s1-02-10-retirement-candidate-manifest-v1.json`
- `Scripts/QA/product-v4/retirement-candidate-manifest-check.py`
- `Scripts/QA/product-v4/run-retirement-candidate-manifest-gate.sh`

The manifest is intentionally stored once in the iOS V4 status directory and
references, rather than duplicates, these checked-in inventories:

- iOS: `Scripts/QA/product-v4/legacy-timer-callback-inventory-v1.json`
- Backend: `DreamJourneyBackend/docs/backend/legacy-timer-callback-inventory-v1.json`

The checker fails if either source inventory adds, removes, or changes a
surface without an aligned manifest row. It also rejects absolute paths,
payload/secret-shaped fields, fixed observation durations, a removal commit or
deploy id, any self-authorized retirement decision, and any claim that G0 has
observed zero use.

## Current Candidate Classification

| Classification | Count | Current position |
| --- | ---: | --- |
| `CANDIDATE_BLOCKED` | 6 | Future candidates only: Echo local reply notification, TimeLetter local notification, voice-clone poll, and backend TimeLetter API/CLI/documented host dispatch. All remain `discovered / not_authorized`. |
| `RETAIN_CURRENT_RUNTIME_NOT_CANDIDATE` | 3 | Digital-human heartbeat and dialog timeout remain required runtime fences until a separately approved successor exists. |
| `EXCLUDED_PURE_UI_OR_PLAYBACK` | 4 | Audio meter, memoir progress, recording duration, and banner dismiss do not own a business effect and are not part of this retirement lane. |
| Other non-candidates | 6 | API lifecycle, typed scheduler foundation, disabled Provider boundary, and Operations maintenance timers remain outside a business-effect retirement decision. |

Every row records the required surface, owner, version status, stable-key
policy, shadow-parity position, drain checkpoint, zero-use source, revoke
boundary, approvers, evidence IDs, dependency scan, removal placeholders and
recovery boundary. Runtime use, in-flight work, old-binary use and
restore/replay results are explicitly `unknown` or `not-applicable` where G0
cannot establish them.

## Non-negotiable G0 Boundary

The manifest uses only `discovered` state. It cannot enter `draining`,
`zero_use_observed`, or `candidate_approved` in this slice.

Any runtime hit, new old-client, non-terminal or unknown in-flight effect,
restore/replay failure, or invalidated approval must reopen a future candidate.
Source search is recorded only as a dependency scan; it is never zero-use,
single-scheduler, host-process, Provider, or old-binary evidence.

No fixed production observation duration is copied from release-policy work.
The relevant zero-use window must be set later from G2 runtime data and
Operations approval, separately for every surface.

## Verification

```bash
bash Scripts/QA/product-v4/run-retirement-candidate-manifest-gate.sh
git diff --check
```

The combined G0 gate runs the existing TimeLetter notification lifecycle
guard, the backend source inventory gate, the new cross-repository manifest
checker, and the derived-handoff checker. It has no host, deployment, Provider
or device side effects.

## Gate Position

| Gate | Status | Meaning |
| --- | --- | --- |
| G0 | Partial | Inventory, TimeLetter notification lifecycle guard and the conservative retirement manifest are present. Cutover-fence behavior still needs a deterministic model check. |
| G1 | Not run | This slice has no public UI or simulator interaction. |
| G2 | Not started | Host/process inventory, single-scheduler proof, drain, zero-use, old binary and restore evidence remain required. |
| G3 | Not started | Provider callback/query applicability and credential-owner proof remain external. |

## Next Sub-slice

`WI-S1-02-10-G0-CUTOVER_FENCE_MODEL`

The next G0-only slice may define and verify a deterministic cutover model for
one legacy effect surface at a time: old direct effect and successor worker may
never both be active; unknown in-flight work must fail closed; any old-client
or runtime hit reopens the candidate. It must not enable a worker, change a
route, alter a host timer, or perform a real dispatch.
