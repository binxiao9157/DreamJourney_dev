# Persona-Scoped Archive Context QA

Date: 2026-06-18

Scope:

- `DigitalHumanContextStore`
- `MemoryArchiveRepository`
- Echo archive context contract

## Goal

Make archive storage, backend archive calls, and Echo archive prompt context follow the selected digital-human/persona owner instead of only the logged-in user. This prepares the PRD family/self switching requirement without exposing family management publicly.

## Changes

- `DigitalHumanContext` now records `viewerUserId`, supplies `resolvedDisplayName`, normalizes stored context for the current logged-in viewer, and posts `djDigitalHumanContextDidChange` when changed.
- `MemoryArchiveRepository` now uses `DigitalHumanContextStore.shared.current.ownerId` as `currentArchiveOwnerId`.
- Archive local storage key now uses `currentArchiveOwnerId`.
- Archive backend fetch uses selected owner id.
- Archive backend sync payload includes:
  - `userId`: selected owner id, for existing endpoint compatibility.
  - `viewerUserId`: logged-in viewer id.
  - `ownerId`: selected archive owner id.

## Verification

RED:

```text
swift tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result before implementation: failed on missing `var viewerUserId: String?`.

GREEN:

```text
swift tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result: passed.

Release guard:

```text
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result: passed.

Submit inventory:

```text
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result: passed.

Build:

```text
tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context/20260618-current/build-debug.log
```

Result: `** BUILD SUCCEEDED **`.

Core smoke:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260618-001554/archive-to-echo-smoke-result.json
```

Result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

## Release Boundary

- No public family management route was exposed.
- Existing default archive creation remains text/photo only.
- Echo still does not display internal sunlight/star/silent mode names.

## Remaining Work

- P1 should add a release-gated persona/family switcher that writes `DigitalHumanContextStore.current`.
- Real backend authorization still needs staging/prod validation for `viewerUserId` and `ownerId`.
