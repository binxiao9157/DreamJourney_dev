# Backend Contract Gap Matrix

Date: 2026-06-18

## Scope

This matrix pins the current contract between the iOS app and `DreamJourneyBackend`.

It is intentionally conservative: a feature is only marked backend-complete when the iOS client call, backend route, persistence behavior, and release gate evidence all exist.

## Contract Rows

| PRD / App capability | iOS client contract | Backend route status | Current release interpretation | Validation evidence |
| --- | --- | --- | --- | --- |
| Echo delayed reply push | `/echo/delayed-replies` | backend route missing | backend/API token/APNs needed before remote push can be called complete; local delayed reply store and local notification remain the current MVP proof | `echo-delayed-reply-push-contract-check.swift`, `run-echo-delayed-reply-notification-smoke.sh` |
| Profile update | `/profile` | backend route missing; current fallback uses `/auth/login` nickname upsert | backend needed or /auth/login fallback; name/gender/region persist locally, remote profile fields need a real profile endpoint before full backend completion | `profile-settings-save-state-check.swift`, `profile-account-fields-check.swift` |
| Password change | `/auth/password` | backend route missing | backend/security needed; iOS page and client contract are hidden and not public release | `profile-password-change-check.swift` |
| Archive ownership | `/archive/items` | backend route present; persona visibility fields require deployed contract parity | backend field migration needed until deployed backend always accepts, persists, rejects invalid, and returns `personaScope` / `digitalHumanId` | `archive-ownership-visibility-check.swift`, backend `tests/test_core_services.py` |
| Care snapshot states | `/care/snapshots/latest/{userId}` | backend route present | backend accepted, state variants needed; iOS now has loading/empty/stale/failed public states, backend still needs explicit fixtures for every state | `profile-care-public-placeholder-check.swift`, `profile-care-snapshot-check.swift`, backend care snapshot tests |

## Backend Routes Confirmed In Local Code

- `POST /auth/login`
- `POST /archive/items`
- `GET /archive/items/{user_id}`
- `POST /care/snapshots`
- `GET /care/snapshots/latest/{user_id}`
- `GET /care/snapshots/{user_id}`

## Backend Gaps To Close Before Full PRD Completion

- Add or explicitly reject `/echo/delayed-replies` remote push scheduling.
- Add `/profile` for nickname, gender, region, avatar metadata, and audit semantics, or document `/auth/login` as the permanent profile upsert endpoint.
- Add `/auth/password` only after auth/security design is explicit.
- Deploy archive `personaScope` / `digitalHumanId` validation and persistence parity to the selected release backend.
- Seed and verify care snapshot loading/empty/stale/failed semantics against backend fixtures or response metadata.

## Release Rule

`RELEASE_HANDOFF_MODE=1` can prove release readiness only for contracts already represented in this matrix and covered by release regression. Missing backend routes remain `backend-ready` or `local-only` until a backend implementation and deployed acceptance evidence are added.
