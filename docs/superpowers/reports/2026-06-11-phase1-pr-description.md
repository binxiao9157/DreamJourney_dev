# PR: Integrate Phase 1 MVP Foundation

## Summary

- Add Phase 1 safety foundation with `SafetyMonitor`, crisis intervention UI, and crisis-session memory/memoir blocking.
- Add `Stage1MemoryFacade` and route first-batch memory consumers through a shared stage-1 entry point.
- Add TimeMailbox, MemoryArchive, and CareDashboard MVP modules with local repositories, UI flows, privacy boundaries, and verification scripts.
- Add one-command Phase 1 verification and Phase 2 kickoff plan.

## Product Scope

- TimeMailbox stores sealed letters locally and does not write letter bodies into global memory by default.
- MemoryArchive defaults private materials to local-only storage; photo analysis requires explicit user selection.
- CareDashboard uses脱敏统计信号, shows `数据不足` for empty data, and filters synthetic mailbox/archive prefixes.
- Crisis sessions discard current transcript and cannot produce memoirs.

## Verification

```bash
bash Scripts/verify_phase1.sh
```

Latest verified result:

- `SafetyMonitor verification: 10/10 passed`
- `TimeMailbox verification passed`
- `MemoryArchive verification passed`
- `CareDashboard verification passed`
- `KBLite 验收结果: 32/32 通过`
- `git diff --check` and `git diff --cached --check` passed
- `DreamJourney.xcodeproj/project.pbxproj: OK`
- `** BUILD SUCCEEDED **`

## Known Limitations

- Simulator build remains blocked by `SpeechEngineToB` missing simulator slice; this PR uses iPhoneOS Debug build as the gate.
- Local safety guard blocks UI/TTS/memory chains, but SDK/server-side pre-LLM safety guard is still a Phase 2 task.
- Apple free speech path is a factory seam only; full implementation is planned for Phase 2.
- Family sync, APNs, backend accounts, voice clone authorization, and persona speaker binding are out of this PR.
