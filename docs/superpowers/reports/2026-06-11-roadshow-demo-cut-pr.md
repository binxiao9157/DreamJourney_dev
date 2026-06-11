# PR: Roadshow Demo Cut Closure

## Summary

- Add `RoadshowDemoSeed` and wire App startup to seed deterministic roadshow demo data.
- Add launch/env controls for roadshow seed, reset, and offline demo mode.
- Make roadshow offline mode actively select `MockDialogEngine` and mock allow safety guard, avoiding live guard/dialog network dependencies during demo fallback.
- Add Roadshow seed verification and update Phase 2 verification to cover the new demo contract.
- Add Roadshow runbook covering device smoke, seed data, 12-step demo script, fallback matrix, and product boundary wording.

## Product Scope

- Demo seed covers family members, TimeMailbox, MemoryArchive, mock photo analysis, KBLite graph, CareDashboard transcript, demo steps, and boundary notices.
- Roadshow mainline is documented as: time mailbox, memory archive, voice companion/mock dialog, care dashboard, family sharing, and offline fallback replay.
- Boundary language explicitly states this is not resurrection, not a real reply from a deceased person, not medical diagnosis, and only uses authorized/sanitized memory signals.

## Verification

```bash
bash Scripts/verify_phase2.sh
```

Latest verified result:

- `SafetyMonitor verification: 10/10 passed`
- `TimeMailbox verification passed`
- `MemoryArchive verification passed`
- `CareDashboard verification passed`
- `KBLite 验收结果: 32/32 通过`
- `DreamJourney.xcodeproj/project.pbxproj: OK`
- iPhoneOS Debug build: `** BUILD SUCCEEDED **`
- `RoadshowDemoSeed verification passed`
- `MockDialogEngine verification passed`
- `SafetyGuard verification: 14/14 passed`
- `PrivacyScope verification passed`
- `MemoryPrivacyIntegration verification passed`
- `RemoteSafetyGuard verification passed`
- `MockDialogEngine simulator typecheck` passed
- `git diff --check` and `git diff --cached --check` passed

## Known Limitations

- This is a roadshow package/runbook closure, not a completed physical-device smoke. Real-device screenshots, logs, and 6-minute timed rehearsal are still the next gate.
- Full Simulator app build remains blocked by the `SpeechEngineToB` simulator slice; iPhoneOS Debug build is the current build gate.
- Product boundary wording is covered by seed/docs/scripts and should still be checked visually in the actual route before external demo.
