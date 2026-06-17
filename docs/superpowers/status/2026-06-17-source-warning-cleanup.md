# Source Warning Cleanup

Date: 2026-06-17

Scope:

- `DreamJourney/Sources/Common/UI/TGLoadingView.swift`
- `DreamJourney/Sources/Common/UI/TGToast.swift`
- `DreamJourney/Sources/Modules/Home/Views/HomeHeaderView.swift`
- `DreamJourney/Sources/Modules/Map/FootprintNotificationBanner.swift`
- `DreamJourney/Sources/Modules/Memory/MemoryDetailViewController.swift`
- `DreamJourney/Sources/Memoir/MemoirDetailViewController.swift`
- `DreamJourney/Sources/Memoir/MemoirFlowManager.swift`
- `DreamJourney/Sources/Services/ConversationMemoryManager.swift`

## Result

Current app business source warnings are cleared in the latest iOS Simulator Debug build.

- Deprecated `contentEdgeInsets` / `imageEdgeInsets` usage was moved away from the affected buttons.
- Deprecated `UIApplication.shared.windows` usage was replaced with scene-based key-window lookup.
- Unused `exactTimePatterns` and `hasAudio` locals were removed.
- Pods, AppIcon asset, AppIntents metadata, and libtool warnings remain outside this source-cleanup scope.

## Guard

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/source-warning-cleanup-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

The guard verifies that the affected app source files do not reintroduce:

- `contentEdgeInsets =`
- `imageEdgeInsets =`
- `UIApplication.shared.windows`
- `let exactTimePatterns =`
- `let hasAudio = memoir.audioFileName != nil`

## Verification

- Source warning cleanup guard passed.
- Submit slice inventory guard passed.
- Group 5 map/future route compatibility guard passed.
- Release QA package guard passed with latest smoke `20260617-backend-build-config`.
- `git diff --check` passed.
- `plutil -lint DreamJourney/Resources/Info.plist` passed.
- `plutil -lint DreamJourney.xcodeproj/project.pbxproj` passed.
- iOS Simulator Debug build passed:
  `tmp/visual-qa/prd-stitch-ui/source-warning-cleanup/20260617-current/build-source-warning-batch.log`.
- Latest build has `0` warning records under `DreamJourney/Sources`.

## Remaining Boundary

Remaining build warnings are outside app business source:

- Pods: third-party dependency warnings.
- Assets: AppIcon size/assignment warnings.
- AppIntents metadata: no AppIntents framework dependency.
- libtool: SpeechEngineToB bitdummy object has no symbols.
