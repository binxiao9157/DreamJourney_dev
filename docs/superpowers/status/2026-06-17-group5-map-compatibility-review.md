# Group 5 Map / Future Route Compatibility Review

Date: 2026-06-17

Scope:

- `DreamJourney/Sources/App/TabCoordinator.swift`
- `DreamJourney/Sources/AppDelegate.swift`
- `DreamJourney/Sources/TabBar/WarmTabBarController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- `DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift`
- `DreamJourney/Sources/Modules/Map/MemoryAnnotation.swift`
- `DreamJourney/Sources/Modules/Map/MemoryAnnotationView.swift`
- `DreamJourney/Sources/Memoir/MemoirFlowManager.swift`
- `DreamJourney/Resources/Info.plist`

## Result

Group 5 is now release-compatible for the current Stitch/PRD shell.

- The public app shell remains `记忆档案 / 回响 / 我的`.
- `MapFootprintViewController` stays compiled for future reuse, but it is not a public tab.
- The only current archive-side route to map remains behind `timeLetters` / explicit UIQA hidden branches.
- The UIQA simulator path avoids loading the live AMap SDK.
- Map privacy copy, `AMapAPIKey` lookup, and AMap privacy initialization remain present for future route recovery.
- `AIRecordingViewController` stays compiled for legacy/future voice reuse, but it is not a public tab.
- `AIRecordingViewController.onDialogEnded` no longer binds an unused keyword value while keeping the keyword-end toast copy.
- The legacy memoir completion banner no longer assumes tab index `1` is the old footprint map.
- The legacy memoir completion copy no longer says content was saved to `足迹`.
- `MemoirFlowManager.prepareVoiceClone` no longer captures an unused `self` in the voice-training callback.
- `MemoirTTSService.synthesizeWithSystemTTS` no longer creates an unused synthesizer while still returning the explicit no-export fallback.
- `VoiceCloneService.trainVoice` now keeps its request body immutable, so the source no longer emits the unused mutable `body` warning.

## Change

`MemoirFlowManager.showMemoirReadyBanner` now opens memoir details from the current navigation context instead of pushing into `tabBar.viewControllers?[1]`. This avoids corrupting the new PRD shell, where tab index `1` is `回响`.

## Guard

Run:

```bash
swift Scripts/QA/prd-stitch-ui/group5-map-compatibility-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

The guard verifies:

- default feature flags keep `timeLetters`, `archiveAudioUpload`, `personaSettings`, and `familyManagement` hidden;
- `TabCoordinator` still builds only archive, echo, and profile tabs;
- `WarmTabBarView.defaultItems` does not expose old labels;
- archive map/time-letter routes are guarded;
- map files are target-included and simulator-safe;
- map privacy/config prerequisites stay present without loading AMap in UIQA simulator;
- legacy recording remains hidden from the public shell and does not bind an unused keyword value.
- legacy memoir banner code does not route through the old map tab assumption.
- voice-training callback code does not reintroduce the unused `self` capture warning.
- system TTS fallback does not create an unused synthesizer while it remains a no-export placeholder.
- voice clone request construction does not reintroduce the unused mutable `body` warning.

## Verification

- Group 1-5 guard scripts passed.
- `release-feature-matrix-check.swift` passed.
- `git diff --check` passed.
- `plutil -lint DreamJourney/Resources/Info.plist` passed.
- `plutil -lint DreamJourney.xcodeproj/project.pbxproj` passed.
- iOS Simulator Debug build passed:
  `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility/20260617-current/build-airecording-warning-triage.log`.
- Prior Memoir TTS warning triage build passed:
  `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility/20260617-current/build-memoirtts-warning-triage.log`.
- Prior voice clone warning triage build passed:
  `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility/20260617-current/build-voiceclone-warning-triage.log`.
- Core archive-to-echo smoke passed with `completed=true` and `containsArchiveContext=true`:
  `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-final-visual-package/archive-to-echo-smoke-result.json`.
- Smoke screenshot:
  `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-final-visual-package/01-archive-to-echo-completed.png`.

## Remaining Boundary

This does not make map/footprint a public PRD feature. If product later brings map back, it needs a new Stitch target screen, updated tab/route decision, and fresh visual QA. Until then, it should stay a future route only.
