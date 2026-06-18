# Backend Contract Gap Matrix

Date: 2026-06-18

## Scope

This matrix pins the current contract between the iOS app and `DreamJourneyBackend`.

It is intentionally conservative: a feature is only marked backend-complete when the iOS client call, backend route, persistence behavior, and release gate evidence all exist.

## Contract Rows

| PRD / App capability | iOS client contract | Backend route status | Current release interpretation | Validation evidence |
| --- | --- | --- | --- | --- |
| Echo delayed reply push | `/echo/delayed-replies` | backend route present locally; deployment/APNs/device token needed | backend accepts and persists delayed reply scheduling requests in code; APNs delivery, deployed route parity, and true-device notification arrival remain required before remote push can be called complete | `echo-delayed-reply-push-contract-check.swift`, backend `EchoDelayedReplyAPITests`, `run-echo-delayed-reply-notification-smoke.sh` |
| Profile update | `/profile` | backend route present locally; selected-environment deployment parity needed | backend accepts and persists nickname/gender/region/avatar metadata in code; deployed backend acceptance is required before full remote profile completion | `profile-settings-save-state-check.swift`, `profile-account-fields-check.swift`, backend `ProfileAPITests` |
| Password change | `/auth/password` | backend route present locally; selected-environment deployment and auth login parity needed | backend now hashes password credentials and requires old-password verification in local code; iOS page and client contract remain hidden and not public release until deployed route, login password participation, security review, and true-device acceptance are complete | `profile-password-change-check.swift`, backend `PasswordAPITests` |
| Archive ownership | `/archive/items` | backend route present; persona visibility fields require deployed contract parity | backend field migration needed until deployed backend always accepts, persists, rejects invalid, and returns `personaScope` / `digitalHumanId` | `archive-ownership-visibility-check.swift`, backend `tests/test_core_services.py` |
| Care snapshot states | `/care/snapshots/latest/{userId}` | backend route present | backend accepted, release-like gate now requires active / empty / stale / failed fixture evidence via `careActiveRiskLevel`, `careMissingStatus`, `careInvalidStatus`, and `careStaleWindowEnd`; selected-environment rerun is still required after deployment changes | `care-snapshot-backend-state-fixtures-check.swift`, `profile-care-public-placeholder-check.swift`, `profile-care-snapshot-check.swift`, backend care snapshot tests |

## Backend Routes Confirmed In Local Code

- `POST /auth/login`
- `POST /profile`
- `GET /profile/{user_id}`
- `POST /echo/delayed-replies`
- `GET /echo/delayed-replies/{user_id}`
- `POST /archive/items`
- `GET /archive/items/{user_id}`
- `POST /care/snapshots`
- `GET /care/snapshots/latest/{user_id}`
- `GET /care/snapshots/{user_id}`

## Backend Gaps To Close Before Full PRD Completion

- Deploy `/echo/delayed-replies` and add APNs/device-token delivery acceptance for remote push scheduling.
- Deploy `/profile` and run selected-environment acceptance for nickname, gender, region, avatar metadata, and audit semantics.
- Deploy `/auth/password` and complete auth/login password parity, security review, and selected-environment acceptance before promoting password change out of hidden release gates.
- Deploy archive `personaScope` / `digitalHumanId` validation and persistence parity to the selected release backend.
- Rerun selected-environment backend acceptance after deploying the care snapshot active / empty / stale / failed fixture gate. The local runner now records `careActiveRiskLevel`, `careMissingStatus`, `careInvalidStatus`, and `careStaleWindowEnd`.

## Release Rule

`RELEASE_HANDOFF_MODE=1` can prove release readiness only for contracts already represented in this matrix and covered by release regression. Missing backend routes remain `backend-ready` or `local-only` until a backend implementation and deployed acceptance evidence are added.
