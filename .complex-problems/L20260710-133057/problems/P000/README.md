# P0 Echo digital-human stability

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_07_p0-echo-digital-human-stability.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 Echo digital-human stability

## Context

Echo already has a Tencent runtime, provider request IDs, audio-owner logging, stop semantics, and simulator smoke coverage. The remaining instability comes from asynchronous work that is guarded by different local identifiers rather than one lifecycle generation, immediate background release without a grace period, and quota failures that still enter automatic recovery.

## Scope

- Add one Echo digital-human lifecycle generation token.
- Invalidate stale session, capability, voice token, synthesis, PCM, and delayed resume work after role/context changes, page exit, or background expiry.
- Preserve exactly one Tencent runtime and one active Echo audio owner.
- Keep the Tencent session when the user stops a conversation; release immediately only on page exit/provider terminal failure.
- Add a background release grace period that can be cancelled on foreground return.
- Keep tap-to-interrupt deterministic and generation guarded.
- Resume microphone capture only for the current generation after provider completion/interruption.
- Treat quota exhaustion as an immediate ordinary-Echo fallback without automatic reconnect or stale-role audio.
- Extend non-device static and simulator UIQA gates.

## Out Of Scope

- True-device audio/lip-sync acceptance.
- Full-duplex VAD barge-in.
- Product UI or Stitch visual changes.
- Backend API changes.

## Steps

- [ ] Initialize and link a recursive ledger.
- [ ] Add Phase 2 static checks and lifecycle coordinator assertions.
- [ ] Implement generation-token invalidation and callback guards.
- [ ] Implement background grace lease and foreground cancellation.
- [ ] Harden session/audio-owner, stop, interrupt, microphone-resume, PCM-tail, and quota fallback semantics.
- [ ] Extend lifecycle UIQA smoke and release regression wiring.
- [ ] Run relevant static checks, simulator smoke, combo gate, build, and `git diff --check`.
- [ ] Complete recursive and Lodestar review with residual true-device risk recorded.

## Success Criteria

- A callback created before a role/context switch cannot install a runtime, synthesize/play audio, send PCM, or reopen the microphone afterward.
- Echo owns at most one Tencent runtime and exposes one explicit audio owner at a time.
- User stop preserves the current Tencent session; page exit releases it.
- Backgrounding does not immediately consume/recreate sessions, but an expired grace lease closes the runtime.
- Returning before lease expiry keeps the provider view and does not auto-start the microphone.
- Quota exhaustion falls back immediately to ordinary Echo and does not retry automatically.
- Tap interruption clears provider work; only the current generation may restore capture.
- Non-device Phase 2 checks, simulator lifecycle smoke, digital-human/voice-clone combo gate, iOS build, and whitespace check pass.

## Recursive Ledger

- Ledger ID: pending initialization.
- Current next action: initialize ledger.


## Success Criteria

- A callback created before a role/context switch cannot install a runtime, synthesize/play audio, send PCM, or reopen the microphone afterward.
- Echo owns at most one Tencent runtime and exposes one explicit audio owner at a time.
- User stop preserves the current Tencent session; page exit releases it.
- Backgrounding does not immediately consume/recreate sessions, but an expired grace lease closes the runtime.
- Returning before lease expiry keeps the provider view and does not auto-start the microphone.
- Quota exhaustion falls back immediately to ordinary Echo and does not retry automatically.
- Tap interruption clears provider work; only the current generation may restore capture.
- Non-device Phase 2 checks, simulator lifecycle smoke, digital-human/voice-clone combo gate, iOS build, and whitespace check pass.
