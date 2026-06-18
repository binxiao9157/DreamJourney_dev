# Backend Contract Gap Matrix

Date: 2026-06-18

## Scope

This matrix pins the current contract between the iOS app and `DreamJourneyBackend`.

It is intentionally conservative: a feature is only marked backend-complete when the iOS client call, backend route, persistence behavior, and release gate evidence all exist.

## Contract Rows

| PRD / App capability | iOS client contract | Backend route status | Current release interpretation | Validation evidence |
| --- | --- | --- | --- | --- |
| Push device token registration | `/devices/push-token` | selected release backend accepted; deployed rerun `20260618-deployed-push-device-token-contract-rerun-205018` passed with Postgres persistence evidence | iOS captures APNs token through AppDelegate, registers it separately, persists returned `deviceTokenId`, and raw device tokens are not returned by API responses; APNs provider delivery and true-device notification arrival remain external gates | `echo-delayed-reply-push-contract-check.swift`, backend `EchoDelayedReplyAPITests`, backend `PostgresStoreTests`, `backend-postgres-persistence-check.py`, deployed acceptance run `20260618-deployed-push-device-token-contract-rerun-205018` |
| Echo delayed reply push | `/echo/delayed-replies` | selected release backend accepted for persisted delayed reply scheduling with `deviceTokenId`; APNs delivery needed | backend accepts and persists delayed reply scheduling requests in code and deployed Postgres evidence now returns `echoDelayedReplyDeviceTokenId` with `echoDelayedReplyPushProviderState=pending`; APNs delivery and true-device notification arrival remain required before remote push can be called complete | `echo-delayed-reply-push-contract-check.swift`, backend `EchoDelayedReplyAPITests`, `run-echo-delayed-reply-notification-smoke.sh`, `backend-postgres-persistence-check.py`, deployed acceptance run `20260618-deployed-push-device-token-contract-rerun-205018` |
| Echo delayed reply dispatch | `/echo/delayed-replies/dispatch-due` | local backend contract implemented; deployed run `20260618-deployed-echo-dispatch-contract-210536` blocked with HTTP 405, so selected release backend acceptance is still required after deploying this route | service-side due sweep moves scheduled replies to `readyForProvider` / `queued` and records `dispatchAttemptedAt` without claiming APNs provider delivery; APNs delivery and true-device notification arrival remain external gates | `echo-delayed-reply-dispatch-contract-check.swift`, backend `EchoDelayedReplyAPITests`, backend `PostgresStoreTests`, `backend-postgres-persistence-check.py`, blocked deployed run `20260618-deployed-echo-dispatch-contract-210536` |
| Profile update | `/profile` | selected release backend accepted | selected release backend accepts and persists nickname/gender/region/avatar metadata; run `20260618-selected-backend-latest-contracts-after-deploy-r2` is selected-environment evidence | `profile-settings-save-state-check.swift`, `profile-account-fields-check.swift`, backend `ProfileAPITests`, `release-like-backend-acceptance-check.swift` |
| Password change | `/auth/password` | selected release backend accepted; public UI still hidden | backend now hashes password credentials and requires old-password verification; iOS login password participation is implemented through `/auth/login`; selected-environment password acceptance passed with `passwordChangeStatus=changed`, `passwordOldLoginStatus=invalid password`, and `passwordNewLoginConfigured=true`; iOS password-change page and client contract remain hidden and not public release until security review, true-device acceptance, and explicit public-release promotion are complete | `login-password-contract-check.swift`, `profile-password-change-check.swift`, `release-like-backend-acceptance-check.swift`, backend `PasswordAPITests` |
| Archive ownership | `/archive/items` | selected release backend accepted for persona visibility fields | selected release backend accepts and returns `personaScope` / `digitalHumanId`; run `20260618-selected-backend-latest-contracts-after-deploy-r2` verified `archivePersonaScope=family` and `archiveDigitalHumanId=family_default` | `archive-ownership-visibility-check.swift`, backend `tests/test_core_services.py`, `release-like-backend-acceptance-check.swift` |
| Care snapshot states | `/care/snapshots/latest/{userId}` | selected release backend accepted | selected release backend accepted active / empty / stale / failed fixture evidence via `careActiveRiskLevel`, `careMissingStatus`, `careInvalidStatus`, and `careStaleWindowEnd`; rerun selected-environment backend acceptance after future backend changes | `care-snapshot-backend-state-fixtures-check.swift`, `profile-care-public-placeholder-check.swift`, `profile-care-snapshot-check.swift`, backend care snapshot tests, `release-like-backend-acceptance-check.swift` |

## Backend Routes Confirmed In Local Code

- `POST /auth/login`
- `POST /profile`
- `GET /profile/{user_id}`
- `POST /devices/push-token`
- `POST /echo/delayed-replies`
- `POST /echo/delayed-replies/dispatch-due`
- `GET /echo/delayed-replies/{user_id}`
- `POST /archive/items`
- `GET /archive/items/{user_id}`
- `POST /care/snapshots`
- `GET /care/snapshots/latest/{user_id}`
- `GET /care/snapshots/{user_id}`

## Backend Gaps To Close Before Full PRD Completion

- Keep `POST /devices/push-token` in release-like backend regression; latest deployed acceptance run `20260618-deployed-push-device-token-contract-rerun-205018` passed and verified persisted `echoDelayedReplyDeviceTokenId`.
- Deploy `POST /echo/delayed-replies/dispatch-due` to the selected backend environment and rerun release-like backend acceptance; latest deployed attempt `20260618-deployed-echo-dispatch-contract-210536` returned HTTP 405.
- Add APNs provider delivery and true-device notification arrival acceptance for remote push scheduling.
- Keep password change hidden until auth/security review, true-device acceptance, and explicit public-release promotion are complete.
- Rerun selected-environment backend acceptance after any future profile/password/archive/care backend contract change.

## Release Rule

`RELEASE_HANDOFF_MODE=1` can prove release readiness only for contracts already represented in this matrix and covered by release regression. Missing backend routes remain `backend-ready` or `local-only` until a backend implementation and deployed acceptance evidence are added.
