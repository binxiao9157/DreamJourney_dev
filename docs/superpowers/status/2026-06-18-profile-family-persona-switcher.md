# Profile Family Persona Switcher

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Scope

This slice turns the hidden `家人管理` route into a minimal persona switcher without exposing family space in the default public surface.

## What Changed

- `FamilyCircleViewController` now lists:
  - `AI 助手` as the self assistant option.
  - `FamilyRepository.shared.getAll()` members as family persona options.
- Selecting `AI 助手` writes `DigitalHumanContext.defaultContext(userId:)`.
- Selecting a family member writes `DigitalHumanContextStore.shared.current` with:
  - `viewerUserId`
  - selected member `ownerId`
  - member display name
  - relation
  - `.star` mode
  - `isSelfAssistant = false`
- `ProfileViewController` observes `.djDigitalHumanContextDidChange`.
- The Profile persona card keeps the current Stitch copy for default self state:
  - `外面世界很美好`
  - `今天又是阳光灿烂的一天`
- When a non-self persona is selected, the card reflects the selected family digital-human context.

## Release Boundary

This is still hidden by default.

Default public flags remain:

```text
careDashboard
profileSettings
legalCenter
```

The family/persona route requires:

- `DJFeature.familyManagement` or `DJEnableProfileHiddenBranches` to show the row.
- `DJFeature.familySpace` to push the hidden persona switcher.

If `familySpace` is not enabled, `家人管理` continues to show the safe unavailable alert.

The family/persona release boundary is now centralized in `ProfileFamilyPersonaReleaseReadiness`:

- default release: `家人管理` row is hidden
- `familyManagement` only: safe row may appear, but the persona switcher still does not open
- `familySpace` or `DJEnableProfileHiddenBranches`: hidden persona switcher may open for QA
- unavailable copy stays `家人管理暂未开放`

## What Is Not Done

- Public family management release.
- Family invitations, access control, member deletion, or family permission audit.
- Full star/sunlight/silent mode management.
- Real backend family member sync acceptance on a non-local server.

## Verification

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-release-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-profile-family-persona-release-smoke.sh
swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Build:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
