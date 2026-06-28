# Group 3 Archive Core And Creation Branches Review

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Scope:

- `DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationSheetViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchivePhotoEntryViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift`
- `DreamJourney/Resources/Info.plist`

## Review Result

Status: ready for staged review. No blocking issue found in this group during source review.

## What This Group Provides

- Keeps public archive creation to text and photo by default.
- Keeps audio, time-letter, persona settings, and video archive paths hidden or unavailable unless explicitly enabled.
- Adds independent text, photo, and audio creation sheets.
- Keeps photo-library and microphone privacy declarations covered by the Group 3 source guard.
- Persists archive items locally through `MemoryArchiveRepository`.
- Keeps optional backend sync explicit through `syncToBackend`.
- Adds a gated remote archive fetch/merge path through `archiveRemoteFetch`; the default app remains local-first.
- Allows debug/UIQA or flagged local analysis from archive detail.
- Excludes pending/failed archive items from echo prompt context until they are manual or analyzed.
- Provides archive context prompt material under `【记忆档案馆素材线索】`.

## Public / Hidden Boundary

Public by default:

- `封存新记忆` sheet: `添加文字描述`, `选择照片`
- Feature grid: photo card; secondary tiles disappear when hidden features are disabled.
- Detail pages and local persistence.

Hidden or not public by default:

- `语音档案`
- `录入时间信件`
- `人格设定`
- remote archive fetch (`archiveRemoteFetch`)
- video archive input
- local analysis outside debug/UIQA or `archiveLocalAnalysis`

## Guard Scripts

```text
Scripts/QA/prd-stitch-ui/group3-archive-core-check.swift
Scripts/QA/prd-stitch-ui/release-like-hidden-entries-check.swift
Scripts/QA/prd-stitch-ui/archive-local-analysis-flow-check.swift
Scripts/QA/prd-stitch-ui/archive-backend-sync-gate-check.swift
Scripts/QA/prd-stitch-ui/archive-remote-fetch-check.swift
Scripts/QA/prd-stitch-ui/archive-remote-json-behavior-check.swift
Scripts/QA/prd-stitch-ui/archive-analysis-to-echo-prompt-harness-check.swift
Scripts/QA/prd-stitch-ui/archive-context-snapshot-check.swift
Scripts/QA/prd-stitch-ui/archive-context-debug-summary-check.swift
Scripts/QA/prd-stitch-ui/archive-to-echo-smoke-script-check.swift
```

## QA Evidence

Latest QA report:

```text
tmp/visual-qa/prd-stitch-ui/group3-archive-core/20260617-current/report.md
```

Latest core-loop smoke after Group 3 review:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-125207/
```

Result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

Passed:

- Group 3 archive core guard.
- Archive photo-library and microphone privacy guard.
- Release hidden-entry guard.
- Local analysis flow guard.
- Backend sync gate guard.
- Archive remote fetch gate guard.
- Archive remote JSON behavior executable check.
- Archive analysis to echo prompt harness guard.
- Archive model executable check.
- Archive context snapshot executable check.
- Archive debug summary executable check.
- iOS Debug simulator build.
- Archive-to-echo smoke script.

## Remaining Notes

- Real photo-library behavior still needs device-level verification.
- Real backend archive sync/fetch still needs an API environment; this pass only adds the hidden local parse/merge client path.
- Audio recorder remains intentionally hidden from the public release matrix unless `archiveAudioUpload` is explicitly enabled.
