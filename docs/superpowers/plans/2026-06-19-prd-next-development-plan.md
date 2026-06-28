# PRD Next Development Plan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于最新 PRD、当前 Stitch UI 依据和已实现工程，把 DreamJourney 继续推进到隐藏全功能可验、公开 MVP 不误暴露、真机验收准备更充分的状态。

**Architecture:** 继续保持 UIKit 三 Tab：`记忆档案 / 回响 / 我的`。公开 MVP 只保留已验收入口；family、voice、time-letter、video、account deletion、doctor contact、digital inheritance 等高风险功能继续通过 feature flag、hidden QA launch arg 或 release gate 管理。

**Tech Stack:** iOS UIKit/Swift、Alamofire、UserDefaults/local file persistence、FastAPI/Postgres backend、`tmp/visual-qa/prd-stitch-ui` static guards and smoke scripts。

---

## Current Baseline

- P0 public MVP gates 已覆盖：Archive -> Echo、Profile/Care、release regression。
- 后端部署 smoke 已覆盖 family digital-human 三态和 voice profile lifecycle。
- iOS 已消费 family/voice 后端合同：`FamilyMember.fromBackendJSON`、`DreamJourneyBackendClient.fetchFamilyMembers`、`VoiceCloneProfileSnapshot.init(backendContract:)`。
- 隐藏媒体 audio/video/timeLetter 已有 schema、mock upload、详情状态、backend sync、combo gate。
- 仍未声明完成：真机麦克风/相册/视频选择、APNs provider delivery、生产语音 SDK 质量、公开 family management、真实声音克隆、数字继承生命周期。

## Task 1: Hidden Family / Voice UIQA Consumer Gate

**Priority:** P1, next best task.

**Files:**
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift`
- Modify: `Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh`
- Create: `Scripts/QA/prd-stitch-ui/ios-family-voice-hidden-uiqa-smoke-check.swift`
- Create or modify: `docs/superpowers/status/YYYY-MM-DD-ios-family-voice-hidden-uiqa.md`

- [ ] Write a failing static guard that requires hidden UIQA to exercise backend-derived `digitalHumanMode`, `familyPersonaContractVersion`, `voiceProfileId`, `sampleStatus`, and `providerMode`.
- [ ] Run the guard and verify it fails because UIQA still only checks static shells.
- [ ] Extend hidden profile/family QA route to refresh family members through `DreamJourneyBackendClient.fetchFamilyMembers`.
- [ ] Extend voice clone hidden shell or QA fixture to render a `VoiceCloneProfileSnapshot` built from `VoiceCloneProfileContract`.
- [ ] Update the smoke script to launch hidden profile branches and assert backend-derived family/voice fields are visible only in hidden QA mode.
- [ ] Run `ios-family-voice-hidden-uiqa-smoke-check.swift`, `run-profile-family-persona-release-smoke.sh`, release QA package, iOS build, and `git diff --check`.
- [ ] Commit with `feat: add hidden family voice UIQA consumer smoke`.

## Task 2: Time Letter Delivery Policy Shell

**Priority:** P1, after Task 1.

**Files:**
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- Modify: `Scripts/QA/prd-stitch-ui/archive-time-letter-backend-lifecycle-check.swift`
- Create: `Scripts/QA/prd-stitch-ui/time-letter-delivery-policy-check.swift`
- Create or modify: `docs/superpowers/status/YYYY-MM-DD-time-letter-delivery-policy.md`

- [ ] Write a failing guard requiring explicit states: `draft`、`sealed`、`deliveryPendingPolicy`、`deliveryDisabledUntilProductDecision`。
- [ ] Verify failure before implementation.
- [ ] Add non-delivery policy copy to sealed time-letter details without scheduling notifications or exposing public delivery.
- [ ] Ensure drafts do not enter Echo context; sealed items may enter context only as user-authored archive content.
- [ ] Run time-letter lifecycle smoke, archive media echo context smoke, release QA package, iOS build, and `git diff --check`.
- [ ] Commit with `feat: guard time letter delivery policy shell`.

## Task 3: Video Hidden Candidate Readiness

**Priority:** P1.

**Files:**
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveVideoEntryViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift`
- Create or modify: `Scripts/QA/prd-stitch-ui/archive-video-hidden-readiness-check.swift`
- Create or modify: `docs/superpowers/status/YYYY-MM-DD-archive-video-hidden-readiness.md`

- [ ] Write a failing guard requiring video hidden state to show thumbnail placeholder, file-size limit, upload provider mode, analysis status, failure/retry copy, and release-hidden boundary.
- [ ] Verify failure.
- [ ] Tighten video detail/list display for mock video items; do not add true video picker or compression.
- [ ] Ensure release mode does not expose video creation by default.
- [ ] Run hidden media combo gate, release regression static guards, iOS build, and `git diff --check`.
- [ ] Commit with `feat: harden hidden video archive readiness`.

## Task 4: True Device Acceptance Re-Run Package

**Priority:** P0 before any public release claim.

**Files:**
- Modify: `Scripts/QA/prd-stitch-ui/run-true-device-archive-audio-preflight.sh`
- Modify: `docs/superpowers/status/2026-06-19-true-device-archive-audio-acceptance.md`
- Create or modify: `Scripts/QA/prd-stitch-ui/true-device-release-readiness-check.swift`

- [ ] Add a guard that requires evidence slots for microphone allow/deny/re-authorize, photo picker, foreground/background recovery, playback route, and screenshots.
- [ ] Run the guard and verify it fails when evidence is missing.
- [ ] Update the true-device script/report to produce structured evidence paths without claiming acceptance automatically.
- [ ] Run script against connected device only when available; otherwise record blocked status.
- [ ] Commit with `test: harden true device acceptance package`.

## Task 5: Production Voice SDK Readiness Boundary

**Priority:** P1 after true-device package is clear.

**Files:**
- Modify: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Modify: `DreamJourney/Sources/Modules/Echo/`
- Create or modify: `Scripts/QA/prd-stitch-ui/production-voice-sdk-readiness-check.swift`
- Create or modify: `docs/superpowers/status/YYYY-MM-DD-production-voice-sdk-readiness.md`

- [ ] Write a guard requiring runtime config to distinguish mock ASR/TTS, backend token fallback, and production SDK readiness.
- [ ] Verify failure where the boundary is not explicit.
- [ ] Surface voice runtime state in hidden QA diagnostics only; do not alter public Echo copy.
- [ ] Ensure Echo state machine still works with mock voice runtime.
- [ ] Run backend voice runtime guard, Echo delayed reply notification smoke, Archive -> Echo smoke, iOS build, and `git diff --check`.
- [ ] Commit with `feat: guard production voice sdk readiness boundary`.

## Execution Order

1. Task 1: Hidden Family / Voice UIQA Consumer Gate.
2. Task 2: Time Letter Delivery Policy Shell.
3. Task 3: Video Hidden Candidate Readiness.
4. Task 4: True Device Acceptance Re-Run Package.
5. Task 5: Production Voice SDK Readiness Boundary.

## Validation Gate For Each Task

Run at minimum:

```bash
git diff --check
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

When backend contracts are touched, also run the relevant deployed smoke with the existing private backend access doc. Do not print tokens.

## Stop Conditions

- Need product decision to publicly expose family management, time-letter delivery, video creation, account deletion, doctor contact, voice clone, or digital inheritance.
- Need developer account/APNs provider setup for production push delivery proof.
- Need true-device manual operation for microphone, photo picker, video picker, and production audio quality.
