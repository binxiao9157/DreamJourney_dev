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
