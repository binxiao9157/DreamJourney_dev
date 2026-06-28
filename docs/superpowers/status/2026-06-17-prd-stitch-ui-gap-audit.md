# PRD / Stitch UI Adaptation Gap Audit

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Project path: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`

## Source Snapshot

- Stitch project: `projects/2650033127117292960`
- Stitch update time: `2026-06-16T15:15:17.747640Z`
- Stitch design system: `Zen Sanctuary`, light mode, primary `#ff8c00`, background `#fff9f0`.
- Stitch visible screens currently returned by MCP:
  - `登录入口 - 往日与回响`
  - `时空对话 - 悬浮导航版`
  - `记忆档案 - 悬浮导航版`
  - `长辈关怀 - 子女看板 (子页面逻辑)`
- Visual authority remains: current Stitch canvas first, `htmlCode` second, MCP screenshots only auxiliary.

## Current Classification

| Module | Status | Evidence | Remaining Work |
| --- | --- | --- | --- |
| Design system | Done | `DJDesignTokens`, `DJComponentFactory`, Stitch palette mapped to UIKit tokens | Final visual pass should confirm typography/spacing against current Stitch canvas and `htmlCode`. |
| App shell / tab bar | Done | `TabCoordinator` composes `记忆档案 / 回响 / 我的`; `WarmTabBarController` has injectable 3-tab items and suppresses the residual system `UITabBar` | Keep screenshots proving tab labels, active states, and single-layer bottom navigation after every major UI update. |
| Login | Done | `LoginViewController` has light Stitch-aligned form and keeps login callback behavior | Capture one final current login screenshot before branch closure. |
| Echo / 回响 | Done for MVP | Voice-first `EchoViewController`; archive prompt context injected through `DialogEngineManager`; one-key smoke validates `containsArchiveContext=true` | Real voice SDK/device path still needs release-level verification; text/image echo inputs remain hidden. |
| Archive / 记忆档案 | Done for core loop | `MemoryArchiveItem`, repository, creation sheet, photo/text entry, detail page, local analysis, archive-to-echo prompt context; Group 3 guard passed; local FastAPI backend fetch renders `Backend Contract Photo` in UIQA; remote fetch failure now shows local fallback status | Richer media metadata, device photo-library behavior, production backend auth/Postgres verification, and final visual comparison still need convergence. |
| Archive create branches | Partly done, partly hidden | Text/photo paths are available; audio/time-letter screens compile and are reachable only with explicit QA hidden-branch enablement; hidden-entry guard passed | `archiveAudioUpload`, `timeLetters`, video input, and persona settings should remain hidden unless explicitly released. |
| Profile / 我的 | Partly done, release-gated | Profile card, care dashboard with safe `待同步` fallback, profile settings, legal center, logout, care backend aggregate parsing, QA-only Stitch hidden actions, and Group 4 guard exist; local FastAPI care data renders `需关注 / Call today.` in UIQA; fallback caption has a stable QA identifier | Family-management, account deletion, and doctor contact flows are hidden by default; production care auth and real family-viewer contracts still need release verification. |
| Backend client | Partly done, locally verified | `DreamJourneyBackendClient` covers `/archive`, `/kb`, `/family`, `/care`; archive remote JSON parsing and gated fetch/merge exist; `DreamJourneyBackendBaseURL` and `DreamJourneyBackendAPIToken` resolve from build settings; memory-store FastAPI contract and token contract scripts pass; archive/profile show basic local fallback copy when backend is unavailable | Real CI/staging secret injection verification, Postgres/Docker persistence, and non-local backend environment verification remain. |
| Old routes / map | Hidden/future route | Old top-level shell removed; simulator map SDK fallback exists; Group 5 guard confirms map is not a public tab and old memoir banner no longer assumes tab index `1` is footprint | If product brings map back, define a new Stitch screen and route explicitly instead of reviving the old shell. |
| QA harness | Done for core loop | `Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh` builds, seeds, analyzes, triggers echo, saves result/log/screenshot | Keep `tmp/` artifacts out of release commits unless intentionally archived. |
| Release feature matrix | Done | `docs/superpowers/status/2026-06-17-release-feature-matrix.md`; `Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift` | Re-run after feature flag, tab, archive creation, echo input, or profile-row changes. |
| Project hygiene | Needs convergence | New archive source files are in `project.pbxproj`; build has passed in recent checks | Dirty tree is large; split review/commit by module and decide which `tmp/` QA artifacts are kept. |

## Temporarily Hidden / Not Public

- `DJFeature.echoTextInput`
- `DJFeature.echoImageInput`
- `DJFeature.timeLetters`
- `DJFeature.personaSettings`
- `DJFeature.archiveAudioUpload`
- `DJFeature.archiveRemoteFetch`
- `DJFeature.archiveLocalAnalysis` outside debug/UIQA
- `DJFeature.familySpace`
- Video archive input
- Family-management, account deletion, and doctor contact flows by default. These can be exposed for internal visual QA with `DJEnableProfileHiddenBranches`.

These should stay behind `FeatureFlagService`, debug/UIQA compile flags, or unavailable alerts until PRD release scope explicitly includes them.

## Open PRD / UI Gaps

1. Final visual QA against current Stitch canvas and `htmlCode` for login, archive, echo, and profile/care.
2. Production backend verification for secret injection, Postgres/Docker persistence, and non-local archive/care/KB/family environment.
3. Device-level verification for microphone, photo library, audio recording, and voice SDK behavior.
4. Remaining profile release flows: family management, account deletion, and doctor contact require real product contracts before public exposure.
5. Commit hygiene: separate source changes from generated QA artifacts and group commits by module.

## Visual QA Evidence

Fresh simulator screenshots were captured for the current code state under:

```text
tmp/visual-qa/prd-stitch-ui/final-visual-qa/20260617-current/
```

Report:

```text
tmp/visual-qa/prd-stitch-ui/final-visual-qa/20260617-current/report.md
```

Current finding: login, echo, and archive pass MVP-level visual invariants; profile/care still needs convergence because several visible settings actions are placeholders or gated. Archive also needs a release-like pass without UIQA-only entries exposed.

Final Stitch visual QA against the current canvas and downloaded `htmlCode` was captured under:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-profile-inset-fix/
```

Finding: login and echo align directly; archive/profile align in default release mode once intentional hidden-feature differences are excluded. Internal QA launch arguments restore the full Stitch archive/profile branch structure for visual comparison. The prior non-release Profile full-list bottom issue is now covered by explicit scroll insets; `08-profile-stitch-qa-hidden-branches-scrolled-bottom.png` shows `注销账户` can scroll fully above the floating tabbar.

Release-like hidden-entry pass was captured under:

```text
tmp/visual-qa/prd-stitch-ui/release-like-visual-qa/20260617-hidden-entries/
```

Finding: without `DJEnableArchiveHiddenBranches`, archive creation exposes only text and photo branches. `语音档案`, `人格设定`, audio creation, and time-letter creation are not exposed by default.

Profile release-gating pass was captured under:

```text
tmp/visual-qa/prd-stitch-ui/profile-release-gating/20260617-current/
```

Finding: without `DJEnableProfileHiddenBranches`, the `我的` settings card exposes `个人资料设置`, `法律法规`, and `退出登录`; unfinished `家人管理`, `注销账户`, and `立即通话` actions remain available only through feature flags or the explicit UIQA hidden-branch argument.

Profile legal center pass was captured under:

```text
tmp/visual-qa/prd-stitch-ui/profile-legal-center/20260617-current/
```

Finding: `法律法规` now opens a real release-visible content page covering AI assistance boundaries, mental-health support limits, privacy/data handling, digital-human ethics, and emergency guidance.

Profile settings pass was captured under:

```text
tmp/visual-qa/prd-stitch-ui/profile-settings/20260617-current/
```

Finding: `个人资料设置` now opens a real release-visible page with avatar display, nickname editing, masked phone display, and save confirmation. Password changes remain hidden.

Profile compact Stitch alignment pass was captured under:

```text
tmp/visual-qa/prd-stitch-ui/profile-compact-stitch/20260617-current/
```

Finding: the Profile root now centralizes Stitch-sensitive layout constants and tightens the persona header, care card, signal wave, and settings rows. Default release mode still hides `立即通话`, `家人管理`, and `注销账户`; internal `DJEnableProfileHiddenBranches` restores the full Stitch branch structure for visual comparison.

Archive compact Stitch alignment pass was captured under:

```text
tmp/visual-qa/prd-stitch-ui/archive-compact-stitch/20260617-current/
```

Finding: the Archive root and creation Sheet now centralize Stitch-sensitive spacing, bento grid, CTA, timeline, and option-row density constants. Default release mode still exposes only text/photo creation; internal `DJEnableArchiveHiddenBranches` remains the only way to restore audio, time-letter, and persona branches for visual comparison.

Archive timeline/detail Stitch alignment pass was captured under:

```text
tmp/visual-qa/prd-stitch-ui/archive-timeline-detail-stitch/20260617-current/
```

Finding: real archive items now use Stitch-style timeline cards instead of the older compact row, and the detail page centralizes Stitch-sensitive spacing. The seeded photo no-image placeholder was adjusted to a lighter release-friendly state; default release mode still exposes only text/photo creation.

Archive analysis-state Stitch alignment pass was captured under:

```text
tmp/visual-qa/prd-stitch-ui/archive-analysis-state-stitch/20260617-current/
```

Finding: the detail `分析线索` card now has explicit pending/generated states, a warm summary panel, and dedicated tag/person insight sections. The latest archive-to-echo smoke under `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-204851/` still reports `completed=true` and `containsArchiveContext=true`.

Release-state overview QA was captured under:

```text
tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current/
```

Finding: with only `DJSeedPendingArchiveAnalysis` and no hidden-branch launch arguments, the public matrix is coherent: `记忆档案 / 回响 / 我的` are visible; archive exposes text/photo only; profile exposes `个人资料设置`, `法律法规`, and `退出登录`; family management, account deletion, doctor contact, archive audio, time letters, persona settings, echo text/image input, and password change remain hidden.

Release feature matrix was documented under:

```text
docs/superpowers/status/2026-06-17-release-feature-matrix.md
```

QA report:

```text
tmp/visual-qa/prd-stitch-ui/release-feature-matrix/20260617-current/
```

Guard check:

```text
Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift
```

Finding: default enabled flags are pinned to `careDashboard`, `profileSettings`, and `legalCenter`; the check also guards archive text/photo-only creation, voice-first echo, profile release rows, and hidden high-risk or unfinished branches.

Pre-submit inventory was documented under:

```text
docs/superpowers/status/2026-06-17-pre-submit-inventory.md
```

Finding: source changes are now grouped into reviewable slices; `tmp/**/DerivedData*/` is ignored so build caches do not pollute `git status`; QA artifacts are separated into optional branch evidence vs local-only generated output.

Pre-submit inventory QA report:

```text
tmp/visual-qa/prd-stitch-ui/pre-submit-inventory/20260617-current/report.md
```

Group 1 scaffolding/release-gates review was documented under:

```text
docs/superpowers/status/2026-06-17-group1-scaffolding-review.md
```

Finding: no blocking release-gating issue was found. The remaining Group 1 decisions are whether to keep `http://127.0.0.1:3100` as dev-only branch config and whether branch-specific signing/bundle-id settings should be committed before wider handoff.

Latest Group 1 verification was captured under:

```text
tmp/visual-qa/prd-stitch-ui/group1-scaffolding/20260617-current/report.md
```

Finding: Group 1 guard, release matrix guard, `git diff --check`, plist/pbxproj lint, `pod install`, iOS Debug simulator build, and archive-to-echo smoke all passed. The latest smoke result is `completed=true` and `containsArchiveContext=true` under `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-121902/`.

Group 2 shell/login/echo review was documented under:

```text
docs/superpowers/status/2026-06-17-group2-shell-echo-review.md
```

Finding: the bottom navigation overlap was fixed by suppressing the residual system `UITabBar` and compacting the custom tabbar shadow. The latest screenshot under `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-124045/` shows a single visible bottom navigation layer, and runtime UI snapshot no longer exposes extra system `tab` targets.

Group 3 archive core/creation branch review was documented under:

```text
docs/superpowers/status/2026-06-17-group3-archive-core-review.md
```

Finding: no blocking issue was found. Public archive creation remains text/photo only; audio, time-letter, persona, and video routes remain hidden or unavailable by default. Archive model/context executable checks passed, and the latest archive-to-echo smoke under `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-125207/` still reports `completed=true` and `containsArchiveContext=true`.

Group 4 profile/care/settings/legal review was documented under:

```text
docs/superpowers/status/2026-06-17-group4-profile-care-review.md
```

Finding: no blocking issue was found after fixing pushed profile pages to hide the floating tabbar. Public rows remain `个人资料设置`, `法律法规`, and `退出登录`; `家人管理`, `注销账户`, and `立即通话` remain hidden by default. Simulator evidence is under `tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/`.

## Must-Run Regression

After any change touching `记忆档案馆`, archive detail, local analysis, prompt building, `回响`, microphone flow, or Stitch UI structure:

```bash
Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh
```

Expected result JSON:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

Latest refreshed pass:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-profile-care-fallback/
```

Latest backend integration evidence:

```text
tmp/visual-qa/prd-stitch-ui/backend-integration/20260617-current/
```

Latest backend auth token evidence:

```text
tmp/visual-qa/prd-stitch-ui/backend-auth-token/20260617-current/
```

Latest backend fallback UI evidence:

```text
tmp/visual-qa/prd-stitch-ui/backend-fallback-ui/20260617-current/
```

Latest backend build config evidence:

```text
tmp/visual-qa/prd-stitch-ui/backend-build-config/20260617-current/
```

Latest backend environment smoke evidence:

```text
tmp/visual-qa/prd-stitch-ui/backend-env-smoke/20260617-backend-env-smoke2/
```

Run this smoke after Stitch UI changes that touch archive/profile structure, and after archive/care backend API or token configuration changes:

```bash
BACKEND_BASE_URL=http://127.0.0.1:3100 BACKEND_API_TOKEN=<token> Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh
```

Expected result JSON includes `completed=true`, `containsBackendContractPhoto=true`, and `careMoodStatus=需关注`.

Latest isolated core smoke after backend QA:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-backend-build-config/
```

Latest Echo archive-context indicator evidence:

```text
tmp/visual-qa/prd-stitch-ui/echo-archive-context-indicator/20260617-current/
```

Indicator acceptance:

- Clean login with no available archive context keeps the indicator hidden.
- Seeded available archive context shows `档案线索正在参与回响` above the Echo quote bubble.
- Core archive-to-echo smoke remains green with `containsArchiveContext=true`.

Latest Echo voice-state visual evidence:

```text
tmp/visual-qa/prd-stitch-ui/echo-voice-state-visual/20260617-current/
```

Voice-state acceptance:

- Idle Echo keeps the Stitch/htmlCode default composition; no extra status capsule is visible.
- Listening preview shows `我在听，您慢慢说` through `DJShowEchoListeningStatePreview`.
- Waiting-reply preview shows `约 5 分钟后再听` between the quote bubble and mic button.
- Speaking preview shows `回响正在抵达` through `DJShowEchoSpeakingStatePreview`.
- The status previews are driven by UIQA simulator launch arguments only.

## Recommended Next Small Target

Continue with one of these release-convergence tracks:

- Final visual QA against the current Stitch canvas and `htmlCode` for login, archive, echo, and profile/care.
- Backend integration verification for archive sync/fetch and care dashboard data against the real staging backend environment.
- Device-level verification for microphone, photo library, and voice SDK behavior.

Do not promote family management, account deletion, or `立即通话` until their real product contracts, confirmation states, and safety copy are implemented.
