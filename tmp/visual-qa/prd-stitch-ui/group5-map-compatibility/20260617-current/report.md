# Group 5 Map Compatibility QA Report

Date: 2026-06-17

Target:

- Keep map/footprint code build-compatible.
- Prevent old `足迹` routes from leaking into the current PRD 3-tab shell.
- Prevent old tab-index routing from pushing hidden memoir detail into `回响`.

Checked files:

- `DreamJourney/Sources/App/TabCoordinator.swift`
- `DreamJourney/Sources/AppDelegate.swift`
- `DreamJourney/Sources/TabBar/WarmTabBarController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- `DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift`
- `DreamJourney/Sources/Modules/Map/MemoryAnnotation.swift`
- `DreamJourney/Sources/Modules/Map/MemoryAnnotationView.swift`
- `DreamJourney/Sources/Memoir/MemoirFlowManager.swift`
- `DreamJourney/Resources/Info.plist`
- `DreamJourney.xcodeproj/project.pbxproj`

Finding:

- Initial guard failed because `MemoirFlowManager` still assumed `tabBar.viewControllers?[1]` was the old footprint navigation stack.
- Source was corrected to push memoir detail from the current navigation context.
- Guard now also verifies map privacy/config prerequisites: location permission copy, `AMapAPIKey` lookup, AMap privacy calls, and UIQA simulator isolation.
- Guard now also verifies that the legacy recording screen remains hidden from the public shell and does not bind an unused keyword value.
- Guard now also verifies that the memoir voice-training callback does not reintroduce an unused `self` capture warning.
- Guard now also verifies that the system TTS fallback does not create an unused synthesizer while it remains an explicit no-export placeholder.
- Guard now also verifies that `VoiceCloneService.trainVoice` keeps the request body immutable and does not reintroduce the unused mutable `body` warning.
- Guard now passes.

Command:

```bash
swift tmp/visual-qa/prd-stitch-ui/group5-map-compatibility-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected output:

```text
Group 5 map/future route compatibility checks passed
```

Verification:

- Group 1-5 guard scripts passed.
- Release feature matrix guard passed.
- `git diff --check` passed.
- `plutil -lint DreamJourney/Resources/Info.plist` passed.
- `plutil -lint DreamJourney.xcodeproj/project.pbxproj` passed.
- iOS Simulator Debug build passed:
  `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility/20260617-current/build-airecording-warning-triage.log`.
- Prior Memoir TTS warning triage build passed:
  `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility/20260617-current/build-memoirtts-warning-triage.log`.
- Prior voice clone warning triage build passed:
  `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility/20260617-current/build-voiceclone-warning-triage.log`.
- Core archive-to-echo smoke passed:
  `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-final-visual-package/archive-to-echo-smoke-result.json`.
- Smoke screenshot:
  `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-final-visual-package/01-archive-to-echo-completed.png`.
