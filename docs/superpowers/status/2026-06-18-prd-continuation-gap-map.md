# PRD Continuation Gap Map

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Baseline commit: `0f64248 feat: adapt PRD Stitch UI flows`

Project path: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`

## Source Of Truth

- Product: latest attached `《寻梦环游 产品PRD V1.0》(1).md`.
- Visual: current Stitch canvas first, Stitch `htmlCode` second.
- Auxiliary visual evidence: MCP screenshots and simulator screenshots only.
- Code baseline: current UIKit implementation after the PRD/Stitch UI adaptation commit.

## PRD Core Goal

First-stage MVP should make `记忆档案馆 -> 生成/沉淀数字人格素材 -> 回响语音交互 -> 等待回信/情绪反馈 -> 心境追踪/关怀` a real, repeatable loop.

The app should preserve future routes for family space, elder care, sunlight/silent/star mode, and digital inheritance without exposing incomplete or unsafe branches in the public surface.

## Current Implemented Capability

| PRD Area | Current State | Evidence |
| --- | --- | --- |
| App shell | Implemented as `记忆档案 / 回响 / 我的`; old public tabs are removed from the default shell. | `TabCoordinator`, `WarmTabBarController`, Group 2 review. |
| Login | Stitch-aligned light login while keeping existing callback login flow. | `LoginViewController`, final visual QA docs. |
| 回响 | Voice-first interaction, archive-context indicator, delayed reply state, and prompt injection from archive context. Text/image inputs stay hidden. | `EchoViewController`, `EchoViewModel`, `DialogEngineManager`, archive-to-echo smoke. |
| 记忆档案馆 | Text/photo creation, local persistence, local analysis states, detail page, timeline cards, hidden audio/time-letter/persona branches. | `MemoryArchive*`, Group 3 review. |
| 设置/我的 | Profile root, personal settings, legal center, logout, care dashboard fallback and backend parsing. | `ProfileViewController`, `ProfileSettingsViewController`, `ProfileLegalViewController`, Group 4 review. |
| 长辈关怀 | Care signal model parses aggregate backend data without raw chat transcript exposure, falls back safely when offline, and now has a tappable aggregate-results child dashboard. | `ProfileCareModels`, `ProfileElderCareDashboardViewController`, `DreamJourneyBackendClient.latestCareSnapshot`, `elder-care-dashboard-check.swift`. |
| Backend client | Local/dev backend base URL and optional token config; archive, KB, family, care endpoint wrappers; App-side backend smoke now verifies archive, care, and accepted family member refresh. | `DreamJourneyBackendClient`, `FamilyRepository.refreshFromBackend`, backend env smoke docs, `backend-family-acceptance-check.swift`. |
| Persona-scoped core loop | Archive storage, backend archive list payloads, sync payloads, and Echo archive context now resolve from the selected digital-human owner while preserving the default self assistant. | `DigitalHumanContextStore`, `MemoryArchiveRepository`, `persona-scoped-archive-context-check.swift`, archive-to-echo smoke. |
| Release gates | Incomplete/high-risk branches are hidden by default and guarded by feature flags or UIQA-only launch arguments. | `FeatureFlagService`, release feature matrix. |
| QA harness | Reusable archive-to-echo smoke, archive media entries smoke, family/persona release smoke, and static guards exist; large generated QA artifacts remain local-only. | `tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh`, `tmp/visual-qa/prd-stitch-ui/run-archive-media-entries-smoke.sh`, `tmp/visual-qa/prd-stitch-ui/run-profile-family-persona-release-smoke.sh`, submit inventory. |

## Key Remaining Gaps

| Priority | Gap | Why It Matters | Current Boundary |
| --- | --- | --- | --- |
| P0 | Real-device acceptance checklist for microphone/photo/voice SDK | PRD core input is voice and archive supports photo/audio. Simulator proves contract only; true acceptance requires device steps and privacy behavior. | Readiness doc added in `2026-06-18-device-backend-acceptance-readiness.md`; 真实验收待用户提供后端环境和真机. |
| P0 | Non-local backend verification contract | Archive/care/family/KB endpoints exist, but staging/prod base URL, token injection, persistence, and error recovery need a repeatable acceptance path. | Backend smoke script and static guards exist; App-side smoke now validates archive/care/family; `2026-06-18-device-backend-acceptance-readiness.md` defines runbook; real environment depends on key/server. |
| P1 | Family management/persona switching UI | PRD requires switching family members and self. Hidden route now writes `DigitalHumanContextStore`; public family management is still not ready. | `familyManagement`/`familySpace` are hidden; status doc: `2026-06-18-profile-family-persona-switcher.md`. |
| P1 | 星辰/阳光/静默 business state | PRD says mode name is not displayed on Echo, but star relatives enable psychological guidance and mood tracking. | Hidden per-family mode management persists `sunlight/star/silent`; Echo/Profile now apply mode boundaries without exposing internal mode names. Public lifecycle policy remains pending. |
| P1 | Account deletion flow | PRD lists account cancellation. Hidden destructive confirmation shell now exists without executing deletion. | `accountDeletion` hidden by default; status doc: `2026-06-18-profile-safety-flows.md`. |
| P1 | Doctor contact / intervention flow | PRD describes L3/L4 intervention. Hidden safety notice now builds a local `关怀升级草稿`; a draft-only backend candidate payload is guarded without dialing, uploading, or claiming medical support. | `careDoctorContact` hidden by default; real call/escalation service contract still pending. Status doc: `2026-06-18-profile-care-escalation-contract.md`; guard: `profile-care-escalation-backend-boundary-check.swift`. |
| P1 | Audio/time-letter/video archive release readiness | PRD supports photos, video, recordings, text, and time letters. Text/photo are public; audio/time-letter are hidden; video is not available. | Code contract added in `2026-06-18-archive-media-release-readiness.md`; audio/time-letter remain hidden until true-device permission/playback and product delivery rules are accepted. |
| P2 | Visual refinements after Stitch updates | Current UI aligns to the last canvas, but Stitch is still changing. | Must rerun final visual QA after updates. |
| P2 | Broader digital inheritance lifecycle | Silent/star transition, family confirmation, and inheritance policies are core innovation but not MVP-complete. | Needs product/security/legal decisions. |

## P0 / P1 / P2 Task Breakdown

### P0

1. **Persona-scoped archive and echo context**
   - Status: completed in `d3e5e4a feat: scope archive context by persona`.
   - Add stable selected-owner resolution to `DigitalHumanContextStore`.
   - Scope `MemoryArchiveRepository` storage, context snapshots, backend archive list/post payloads, and Echo prompt context to the selected digital-human owner.
   - Add a static guard proving repository no longer uses only the login user for archive storage/context.

2. **PRD core loop regression**
   - Status: green after persona scoping.
   - Keep `run-archive-to-echo-smoke.sh` green after persona scoping.
   - Ensure default self assistant still works without family setup.

3. **True-device acceptance package**
   - Status: readiness package added in `docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`; true-device execution still requires user device/signing.
   - Consolidate microphone/photo/audio and voice SDK manual acceptance steps.
   - Separate simulator proof from real-device acceptance.

4. **Backend environment acceptance package**
   - Status: readiness package added in `docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`; App-side archive/care/family smoke contract is guarded by `backend-family-acceptance-check.swift`; real backend execution still requires user-provided URL/token.
   - Document required base URL/token config and expected archive/care/family smoke outcomes.
   - Keep local fallback copy and auth-token behavior covered.

### P1

1. **Family/persona management behind flag**
   - Status: hidden persona switcher and release readiness smoke implemented in `docs/superpowers/status/2026-06-18-profile-family-persona-switcher.md`; public family management still gated.
   - Build a small release-gated persona switcher that uses existing `FamilyRepository` data and writes `DigitalHumanContextStore`.
   - Keep it hidden until product confirms public exposure.

2. **Mode-aware care visibility**
   - Status: helper added in `docs/superpowers/status/2026-06-18-profile-safety-flows.md`; hidden mode management added in `docs/superpowers/status/2026-06-18-digital-human-mode-management.md`; Echo/Profile lifecycle effects added in `docs/superpowers/status/2026-06-18-digital-human-mode-lifecycle.md`.
   - Show `心境追踪` only when selected persona/mode requires it, while preserving the current release fallback until mode switching exists.

3. **Account deletion confirmation**
   - Status: hidden destructive confirmation shell added; real deletion remains blocked pending compliance/product contract.
   - Replace placeholder with a destructive confirmation shell only after data deletion contract is defined.

4. **Doctor contact safety**
   - Status: hidden safety notice, local `关怀升级草稿`, and draft-only backend candidate payload boundary added; real contact/escalation remains blocked pending backend/product contract.
   - Replace the disabled draft-send action with a real contact contract only after backend/product/legal confirmation.

5. **Archive media expansion**
   - Status: release readiness contract and repeatable media entries smoke added in `docs/superpowers/status/2026-06-18-archive-media-release-readiness.md`.
   - Promote audio/time-letter/video only when each has real persistence, permissions, and QA.
   - Current boundary: text/photo public, audio/time-letter hidden behind `DJEnableArchiveHiddenBranches` or feature flags, video unavailable.

### P2

1. Refresh visual QA after each Stitch canvas/htmlCode update.
2. Continue compacting UI spacing and typography differences.
3. Prepare future family space, silent/star transition, and digital inheritance docs.

## Current Selected Target

Proceed with **P0 true-device and backend acceptance readiness**.

Reason:

- It protects the PRD core path from being called finished before real backend and true-device evidence exists.
- It consolidates the commands and artifacts needed when the user later provides backend URL/token or a physical device.
- It does not require exposing hidden family/account/developer branches.
- It keeps simulator proof separate from real-device acceptance, which is important for honest release readiness.

## Verification Commands For Next Target

```bash
swift tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/backend-family-acceptance-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

iOS build is required before committing the implementation slice.

## Stop Conditions

Ask the user only if the next step needs:

- a real backend base URL/token beyond local fallback,
- Apple signing/team/certificate changes,
- physical device operation,
- a product decision to publicly expose family management, account deletion, doctor contact, or star/silent mode transitions,
- destructive data migration or deletion.
