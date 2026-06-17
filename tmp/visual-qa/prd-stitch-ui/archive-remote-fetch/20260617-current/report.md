# Archive Remote Fetch Integration Guard

Date: 2026-06-17

Scope:

```text
DreamJourney/Sources/App/FeatureFlagService.swift
DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift
DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift
DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift
```

## Result

Archive remote fetch is implemented as a hidden integration path.

- `DJFeature.archiveRemoteFetch` exists and is disabled by default.
- `MemoryArchiveItem(remoteJSON:)` parses backend archive JSON, including snake-case `time_letter` kind values.
- `MemoryArchiveRepository.refreshFromBackend` calls the backend archive list API, parses remote items, merges by id, preserves local file paths when useful, and persists the merged local store.
- `MemoryArchiveViewController` only calls remote refresh when `archiveRemoteFetch` is enabled.

This does not make backend archive fetch a public release behavior. It provides a guarded path for future integration verification when a real backend environment is available.

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-remote-fetch-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swiftc DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift tmp/visual-qa/prd-stitch-ui/archive-remote-json-behavior-check.swift -o /tmp/archive-remote-json-behavior-check && /tmp/archive-remote-json-behavior-check
swift tmp/visual-qa/prd-stitch-ui/group3-archive-core-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result: passed.
