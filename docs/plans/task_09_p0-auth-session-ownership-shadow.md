# P0 Auth Session and Ownership Shadow Mode

## Context

The deployed backend currently authenticates the whole app with one shared `BACKEND_API_TOKEN` and trusts caller-provided `userId` values. This is sufficient for a controlled MVP backend smoke, but it is not a production multi-user authorization boundary for archive, family, time-letter, voice-clone, or digital-human data.

## Scope

- Issue opaque access and refresh tokens after successful `/auth/login`.
- Persist only token hashes and safe session metadata in memory/Postgres.
- Rotate refresh tokens, revoke sessions on logout, and reject expired/revoked access tokens.
- Keep the existing backend API token as a legacy/admin compatibility path.
- Resolve a user principal in middleware and observe claimed user IDs in `shadow` mode.
- Return safe ownership decision headers for QA without exposing tokens or raw identifiers.
- Add iOS Keychain storage, user bearer headers, refresh client support, one retry after access-token `401`, and logout cleanup.
- Expose the auth-session/ownership capability through `/config/runtime`.
- Add backend tests, iOS static checks, simulator smoke, and a release-regression switch.

## Out Of Scope

- SMS verification or public registration policy.
- Enforcing ownership mismatches in production during this task.
- Full family-recipient authorization rules for every cross-account route.
- Removing `BACKEND_API_TOKEN` from deployed legacy clients.
- True-device or APNs validation.

## Steps

- [x] Add failing backend and iOS contract guards.
- [x] Implement safe auth-session storage and API contracts.
- [x] Add principal resolution and ownership shadow observations.
- [x] Add iOS Keychain persistence, headers, refresh retry, and logout cleanup.
- [x] Add combined non-device smoke/release gate.
- [x] Run backend verification, iOS generic build, local HTTP smoke, and diff checks.
- [x] Close the recursive ledger and record enforcement follow-up boundaries.

## Success Criteria

- Login returns access/refresh tokens with explicit expiries and no raw token is persisted.
- Refresh rotates both tokens; a consumed refresh token cannot be reused.
- Logout revokes the session; revoked and expired access tokens fail.
- Legacy backend-token-only requests remain compatible.
- A valid user bearer resolves the expected principal.
- Ownership mismatch is observable in shadow mode but does not block the request.
- iOS stores tokens in Keychain rather than UserDefaults and sends the user bearer separately from the backend token.
- iOS retries one failed request after a successful refresh without recursive refresh loops.
- All non-device tests and builds pass.

## Recursive Ledger

- Ledger ID: `L20260710-165434`.
- Status: closed (`4/4` problems and `4/4` checks successful).
- Current next action: none.

## Verification Evidence

- Backend: `./scripts/verify_backend.sh` passed 156 tests plus FastAPI smoke.
- Local HTTP: `tmp/visual-qa/prd-stitch-ui/backend-auth-session-shadow-smoke/report.json`.
- iOS: `auth-session-ownership-shadow-check.swift`, release QA package, and generic iPhoneOS Debug build passed.
- Deferred: deployed Postgres smoke, true-device Keychain/weak-network acceptance, SMS verification, and ownership enforce promotion.
