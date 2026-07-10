# Findings

## Active Context

- Goal: 按照最新 PRD 持续推进 DreamJourney_dev 到可真实测试、可真机验收、可持续迭代状态
- Closure Lodestar mode: Lodestar outer protocol plus recursive task ledgers.

## Explore Progress

- Initialized project memory.

## Confirmed Requirements

- 按照最新 PRD 持续推进 DreamJourney_dev 到可真实测试、可真机验收、可持续迭代状态

## Constraints

- Keep Lodestar Markdown as project-level source of truth.
- Keep recursive `.complex-problems/` as task-level closure state.

## Available Skills

- Lodestar
- Closure Lodestar ledger engine
- closure-lodestar

## Technical Decisions

- Use `.closure-lodestar/task-ledgers.json` to map Lodestar task files to recursive ledger IDs.

## Resolved Issues

- The configured trial speaker pool is currently selected by deterministic hash. Different logical profiles can collide on the same provider `S_` speaker and retrain/overwrite one another.
- `/voice/synthesis` currently forwards the caller-provided `voiceProfileId` to the provider without first proving that the profile belongs to the requesting user and is ready, enabled, and quality-accepted.
- Current status documentation predates the 2026-07-02/03 role-routing and trial-slot rotation commits and must be refreshed before handoff.
- All three issues were closed by Task 6 and verified through ledger `L20260710-115209`.

## Task 6 Decisions

- Keep app-facing `voiceProfileId` stable and provider-agnostic; store the VolcEngine `S_` identifier separately as `providerSpeakerId`.
- Allocate configured pool slots exclusively and atomically. Never use hash modulo as the production allocator.
- A deleted slot is retired rather than automatically recycled, preventing a subsequent user from inheriting residual provider voice data.
- Existing profiles whose logical ID is already an `S_` provider ID remain readable through a legacy compatibility path.
- Synthesis must resolve and authorize a persisted profile before calling the provider; provider failures remain explicit and do not silently switch voices.

## Task 7 Issues

- Session and PCM work use request/context IDs, but capability, realtime-token, synthesis completion, and delayed microphone-resume callbacks do not share one lifecycle generation.
- `didEnterBackground` releases the Tencent runtime immediately; there is no cancellable grace period for brief app switching.
- Tencent quota exhaustion is included in the one-shot automatic recovery path even though the product requirement is an immediate ordinary-Echo fallback.
- Existing stop/session/audio-owner behavior is mostly correct and should be strengthened rather than replaced.

## Task 7 Resolution

- A single lifecycle coordinator now separates session generation from interaction generation. Role/page/background expiry invalidates session work; stop and barge-in invalidate only the current interaction.
- Every session/runtime/capability/voice synthesis/PCM/delayed-resume path touched by Phase 2 validates its captured token before changing current Echo state.
- Runtime ownership is bound to lifecycle generation, duplicate runtime instances are closed before replacement, and page exit always releases the provider regardless of DialogEngine delegate ownership.
- Background release uses an 8-second cancellable lease. Foreground cancellation preserves the provider view and never auto-starts the microphone; expiry releases the session.
- Quota failures are terminal for the current provider attempt and fall back to ordinary Echo without retrying or retaining the prior role's audio.
- PCM send failure clears the failed provider request while preserving the pending microphone-resume state.
- Non-device evidence passed; real Tencent audio, rendered lip movement, AVAudioSession contention, tap interruption, and microphone recovery still require a later true-device pass.

## Task 8 Resolution

- Backend digital-human sessions now use a persisted lease contract with same-context reuse, same-device context replacement, heartbeat renewal, explicit idempotent release, TTL recovery, and structured capacity conflicts.
- Postgres arbitration takes transaction-scoped advisory locks for the device and provider resource before capacity decisions, so multiple workers cannot concurrently allocate the same single-capacity asset.
- Lease persistence contains identifiers, lifecycle metadata, timestamps, and status only; Tencent appkey, accesstoken, and credential payloads remain ephemeral.
- iOS keeps one active lease with the Tencent runtime, schedules heartbeat while its session generation is current, and releases on role switch, page exit, background grace expiry, provider terminal failure, and stale successful responses.
- User stop invalidates only the current conversation and does not release the provider lease, preserving continuous Echo behavior.
- The simulator runtime smoke now performs create, heartbeat, and release, preventing QA runs from leaving capacity occupied until TTL.
- Final non-device evidence: `tmp/visual-qa/prd-stitch-ui/digital-human-session-lease-gate/20260710-session-lease-final/report.md`.
- Backend commit `e9b3104` is deployed and the Postgres session smoke passed; real Tencent quota release timing and true-device audio/render behavior remain explicit follow-up acceptance boundaries.

## Task 10 Resolution

- A dedicated `CrossAccountAuthorizationPolicy` now distinguishes owner, accepted family viewer, time-letter recipient, invitation recipient, system-only, and legacy ownership fallback decisions.
- Care snapshot reads, time-letter detail, and invitation acceptance bind the verified bearer principal even while global ownership remains `shadow`; forged viewers no longer receive sensitive content.
- Middleware exposes fixed-enum authorization policy/decision/reason headers, marks legal delegation separately, and hashes identifiers in application logs.
- `/config/runtime` reports `crossAccountPolicy.contractVersion=1` and `productionEnforceReady=false` so deployments cannot mistake this slice for complete production authorization.
- Final non-device evidence: `tmp/visual-qa/prd-stitch-ui/release-regression/20260710-cross-account-auth-final/report.md`.
- Deployed Postgres shadow evidence and the full-route audit were completed by Task 11; SMS identity proof and global enforce promotion remain explicit follow-ups.

## Task 11 Resolution

- A single `RouteOwnershipRegistry` now classifies all 54 FastAPI business routes as public, authenticated service, user session, owner body/path, delegated, or system-only; tests fail for omissions or duplicates.
- Owner-bound mismatches and user calls to system-only routes now return 403 even while the global mode remains `shadow`; unknown/unclassified behavior is not globally promoted to enforce.
- Delegated family, invitation, care, and time-letter recipient policies remain explicit and passed both local and deployed Postgres smoke.
- Large JSON bodies no longer bypass principal inspection, and the immutable route registry is compiled once per process rather than once per request.
- iOS mailbox refresh no longer triggers global time-letter dispatch; the enabled server timer owns due delivery.
- Backend `275a4c2` is deployed. Online evidence reports `routeCount=54`, `unclassifiedCount=0`, principal-bound owner/system denies, valid delegated access, production Postgres health, and an active time-letter timer.
