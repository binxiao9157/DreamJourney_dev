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

- [x] Initialize and link a recursive ledger.
- [x] Add Phase 2 static checks and lifecycle coordinator assertions.
- [x] Implement generation-token invalidation and callback guards.
- [x] Implement background grace lease and foreground cancellation.
- [x] Harden session/audio-owner, stop, interrupt, microphone-resume, PCM-tail, and quota fallback semantics.
- [x] Extend lifecycle UIQA smoke and release regression wiring.
- [x] Run relevant static checks, simulator smoke, combo gate, build, and `git diff --check`.
- [x] Complete recursive and Lodestar review with residual true-device risk recorded.

## Success Criteria

- A callback created before a role/context switch cannot install a runtime, synthesize/play audio, send PCM, or reopen the microphone afterward.
- Echo owns at most one Tencent runtime and exposes one explicit audio owner at a time.
- User stop preserves the current Tencent session; page exit releases it.
- Backgrounding does not immediately consume/recreate sessions, but an expired grace lease closes the runtime.
- Returning before lease expiry keeps the provider view and does not auto-start the microphone.
- Quota exhaustion falls back immediately to ordinary Echo and does not retry automatically.
- Tap interruption clears provider work; only the current generation may restore capture.
- Non-device Phase 2 checks, simulator lifecycle smoke, digital-human/voice-clone combo gate, iOS build, and whitespace check pass.

## Implementation Result

- Echo 现使用统一 lifecycle coordinator，分别管理 session generation、interaction generation 与后台 release lease。
- 角色切换、页面退出和后台宽限到期会使旧 session 回调失效；停止和点击打断只使旧交互回调失效，不销毁当前腾讯 session。
- runtime 与 lifecycle generation 显式绑定；新 runtime 绑定前关闭旧 runtime，只有当前 generation 可以占用腾讯 audio owner、发送 PCM 或恢复麦克风。
- App 进入后台后使用 8 秒可取消宽限期；前台及时返回保留 provider view 且不自动开麦，超时才释放 session。
- 腾讯配额错误不再自动重连，直接回落普通 Echo；PCM chunk/final 失败仍保留当前轮的麦克风恢复意图。
- 页面退出无条件释放 runtime，不再依赖 DialogEngine delegate 是否仍指向 Echo。
- 未调整公开产品布局，未修改后端 API。

## Verification Evidence

- Lifecycle UIQA: `tmp/visual-qa/prd-stitch-ui/echo-digital-human-lifecycle-smoke/20260710-phase2-background-lease-final/`
- Runtime stub: `tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260710-phase2-local-bundle-final/`
- Release regression: `tmp/visual-qa/prd-stitch-ui/release-regression/20260710-phase2-stability-final/report.md`
- Tencent non-device combo gate: `tmp/visual-qa/prd-stitch-ui/tencent-digital-human-phase2-non-device-gate/20260710-phase2-stability-final-gate/report.md`
- 真机真实声音、口型、AudioSession、点击打断与麦克风恢复按本任务边界未执行，仍是后续验收门。

## Recursive Ledger

- Ledger ID: `L20260710-133057`.
- Root problem: `P000` / done.
- Current next action: `none`.
- Validation: passed; 5/5 problems done, 5/5 tickets done, 0 blocked.
