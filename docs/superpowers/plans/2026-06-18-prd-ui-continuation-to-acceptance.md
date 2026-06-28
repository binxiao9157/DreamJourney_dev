# PRD UI Continuation To Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Continue from commit `a50d3b7` and move DreamJourney toward PRD-complete, Stitch-aligned, real-backend-ready, true-device-acceptable MVP status without reopening already aligned UI or exposing incomplete safety-critical features.

**Architecture:** Keep the current UIKit architecture, `记忆档案 / 回响 / 我的` shell, shared `DJDesignTokens`, existing repositories, and `DreamJourneyBackendClient`. New work should be added as small release-gated slices with static guards, simulator smokes, and documentation updates before promotion into the public surface.

**Tech Stack:** Swift 5, UIKit, Auto Layout, Xcode workspace `DreamJourney.xcworkspace`, CocoaPods, Alamofire, current Stitch canvas and `htmlCode`, local QA scripts under `tmp/visual-qa/prd-stitch-ui`, Lodestar docs under `docs/`.

---

## Baseline

- Date: 2026-06-18
- Branch: `feature/prd-stitch-ui-adaptation`
- Current local head: `a50d3b7 test: add care escalation boundary smoke`
- Remote state at plan creation: local branch is ahead of `origin/feature/prd-stitch-ui-adaptation` by 15 commits.
- Product source: latest attached `《寻梦环游 产品PRD V1.0》(1).md`.
- Visual source: current Stitch canvas first, Stitch `htmlCode` second, MCP screenshot only as auxiliary review evidence.
- Current blocker class: real backend URL/token, Apple signing, physical device operation, and product/legal decisions for destructive or intervention flows.

## Current Progress Snapshot

| Area | Current state | Evidence |
| --- | --- | --- |
| App shell | Public shell is `记忆档案 / 回响 / 我的`; old route shell is no longer public. | `DreamJourney/Sources/App/TabCoordinator.swift`, `DreamJourney/Sources/TabBar/WarmTabBarController.swift`, `Scripts/QA/prd-stitch-ui/group2-shell-echo-check.swift` |
| Design system | Stitch cream/orange UI has central tokens and shared component helpers. | `DreamJourney/Sources/DesignSystem/DJDesignTokens.swift`, `DreamJourney/Sources/DesignSystem/DJComponentFactory.swift` |
| Login | Light Stitch login is implemented while preserving current login callback flow. | `DreamJourney/Sources/Modules/Auth/LoginViewController.swift` |
| Archive | Public text/photo creation, local persistence, local analysis state, detail view, timeline cards, and archive-to-echo context are implemented. Audio/time-letter/persona branches remain hidden. | `DreamJourney/Sources/Modules/Archive/`, `Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh` |
| Echo | Voice-first scenic screen, archive-context prompt injection, waiting/listening UI states, and mode-boundary copy are implemented. Text/image inputs remain hidden. | `DreamJourney/Sources/Modules/Echo/`, `Scripts/QA/prd-stitch-ui/echo-voice-state-visual-check.swift` |
| Persona scope | Selected self/family owner scopes archive storage, backend payloads, and Echo archive context. | `DreamJourney/Sources/App/DigitalHumanContextStore.swift`, `Scripts/QA/prd-stitch-ui/persona-scoped-archive-context-check.swift` |
| Profile | Profile root, settings, legal center, logout, care dashboard, elder care child dashboard, hidden family/persona switcher, hidden account deletion shell, and hidden care escalation draft exist. | `DreamJourney/Sources/Modules/Profile/`, `Scripts/QA/prd-stitch-ui/group4-profile-care-check.swift` |
| Backend | Configurable backend base URL/token, archive/care/family wrappers, local fallback behavior, and backend smoke harness exist. Real environment acceptance still requires credentials/server. | `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`, `Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh` |
| Release gates | Default enabled flags remain `careDashboard`, `profileSettings`, `legalCenter`; high-risk and unfinished flows are hidden. | `DreamJourney/Sources/App/FeatureFlagService.swift`, `docs/superpowers/status/2026-06-17-release-feature-matrix.md` |
| QA | Static guards and simulator smokes cover core loop, archive media boundary, family persona boundary, care escalation boundary, release matrix, and submit inventory. | `Scripts/QA/prd-stitch-ui/*.swift`, `Scripts/QA/prd-stitch-ui/run-*.sh` |

## Completion Assessment

| Track | Estimate | Meaning |
| --- | --- | --- |
| Current Stitch UI adaptation | High for visible MVP shell; medium for future hidden branches | Login, Echo, Archive, Profile align with the last captured Stitch/htmlCode package. Every Stitch update still requires a refresh pass. |
| PRD MVP core loop | Medium-high in simulator | `记忆档案 -> 回响` is repeatable in simulator and persona-scoped. True-device microphone/photo behavior remains unaccepted. |
| Backend readiness | Medium | Client and smoke contract exist. Real staging/prod URL/token execution is still external. |
| True-device readiness | Low until executed | Runbook and privacy keys exist; physical-device evidence is still missing. |
| Safety-critical PRD branches | Intentionally low/public-hidden | Account deletion, doctor intervention, family management release, and lifecycle transition need product/backend/legal decisions before public exposure. |

## Development Rules For The Remaining Work

1. Preserve the public MVP shell: `记忆档案 / 回响 / 我的`.
2. Preserve the visual source-of-truth rule: Stitch canvas + `htmlCode` decides final visual intent; screenshots only verify.
3. Do not expose hidden features unless the task explicitly promotes them and adds a release guard.
4. Do not execute account deletion, emergency contact, doctor contact, or third-party notification without a product/legal/backend contract.
5. Every implementation slice must add or update at least one guard, smoke, runbook, or status doc.
6. Every independent slice ends with `git diff --check`, relevant static checks, iOS Debug simulator build, and a commit.
7. Generated logs, screenshots, DerivedData, and local Stitch caches stay out of commits unless the plan explicitly asks to preserve a small reference artifact.

## File Map

Core app files to preserve:

- `DreamJourney/Sources/App/TabCoordinator.swift`: public 3-tab shell composition.
- `DreamJourney/Sources/App/FeatureFlagService.swift`: release gates and UIQA-only launch-argument gates.
- `DreamJourney/Sources/App/DigitalHumanContextStore.swift`: selected owner/persona/mode state.
- `DreamJourney/Sources/AppDelegate.swift`: UIQA smoke launch hooks.
- `DreamJourney/Sources/DesignSystem/DJDesignTokens.swift`: central Stitch token mapping.
- `DreamJourney/Sources/DesignSystem/DJComponentFactory.swift`: shared UIKit helpers.
- `DreamJourney/Sources/Modules/Archive/`: archive home, creation sheet, entries, details, repository, media readiness.
- `DreamJourney/Sources/Modules/Echo/`: voice-first interaction and archive context bridge.
- `DreamJourney/Sources/Modules/Profile/`: profile root, settings, legal center, care models, elder dashboard, hidden safety flows.
- `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`: backend integration boundary.
- `DreamJourney/Sources/Services/FamilyRepository.swift`: backend-backed family state.

Durable docs to update as work proceeds:

- `task_plan.md`
- `docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md`
- `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- `docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`
- `docs/superpowers/status/2026-06-18-release-qa-handoff.md`
- `docs/plans/impl_plan_index.md` when a new Lodestar task is added.

Reusable QA entry points:

- `Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh`
- `Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh`
- `Scripts/QA/prd-stitch-ui/run-archive-media-entries-smoke.sh`
- `Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh`
- `Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh`
- `Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift`
- `Scripts/QA/prd-stitch-ui/final-visual-qa-package-check.swift`
- `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- `Scripts/QA/prd-stitch-ui/submit-slice-inventory-check.swift`

---

## P0 Work

P0 work protects the release candidate from false readiness claims. Do these before promoting any more hidden features.

### Task 1: Refresh Final Stitch Visual QA Package

**Objective:** Rebuild the visual evidence package against the current Stitch canvas and `htmlCode`, then fix only accidental drift in visible MVP UI.

**Files:**

- Read: `docs/superpowers/status/2026-06-17-prd-stitch-ui-gap-audit.md`
- Read: `tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-profile-inset-fix/report.md`
- Modify if drift is confirmed: `DreamJourney/Sources/Modules/Auth/LoginViewController.swift`
- Modify if drift is confirmed: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Modify if drift is confirmed: `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- Modify if drift is confirmed: `DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationSheetViewController.swift`
- Modify if drift is confirmed: `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- Modify: `docs/superpowers/status/YYYY-MM-DD-final-stitch-visual-refresh.md`

- [ ] **Step 1: Confirm current source-of-truth rule**

Run:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
rg -n "current Stitch canvas|htmlCode|MCP screenshot" docs/superpowers/status docs/superpowers/plans task_plan.md
```

Expected: output includes the current Stitch canvas + `htmlCode` rule and no doc says MCP screenshot is the final visual authority.

- [ ] **Step 2: Capture current app screenshots in release mode**

Use the simulator UI workflow already used by the existing visual QA packages. Save screenshots under:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/YYYYMMDD-current/app/
```

Required app screenshots:

```text
01-login.png
02-echo-default.png
03-archive-default.png
04-profile-default.png
05-echo-stitch-qa.png
06-archive-stitch-qa-hidden-branches.png
07-profile-stitch-qa-hidden-branches.png
08-profile-stitch-qa-hidden-branches-scrolled-bottom.png
```

Expected: release screenshots do not expose audio/time-letter/persona/family/account-delete/call entries unless an explicit UIQA launch argument is used.

- [ ] **Step 3: Save current Stitch references**

Save current Stitch `htmlCode` and raster references under:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/YYYYMMDD-current/stitch/
```

Required files:

```text
login.html
login.png
echo.html
echo.png
archive.html
archive.png
profile.html
profile.png
source-manifest.md
```

Expected: `source-manifest.md` lists Stitch project `projects/2650033127117292960`, screen titles, screen ids when available, and notes that MCP screenshots are auxiliary only.

- [ ] **Step 4: Write the visual refresh report**

Create:

```text
docs/superpowers/status/YYYY-MM-DD-final-stitch-visual-refresh.md
```

The report must contain these sections:

```markdown
# Final Stitch Visual Refresh

Date: YYYY-MM-DD
Branch: feature/prd-stitch-ui-adaptation
Head: <git sha>
Source of truth: current Stitch canvas and htmlCode; MCP screenshots are auxiliary only.

## App Evidence

## Stitch Evidence

## Release-Gated Differences

## Accidental Drift Findings

## Fixes Applied

## Verification

## Remaining Risks
```

Expected content:

- `Release-Gated Differences` explains that audio/time-letter/persona, family management, account deletion, and doctor contact may be present in full Stitch/UIQA mode but hidden from public release.
- `Accidental Drift Findings` lists only unintended visual deviations.
- `Fixes Applied` is `None` if no code change was needed.

- [ ] **Step 5: If drift exists, fix one screen at a time**

Allowed changes:

- spacing constants inside local layout enums,
- text copy that differs from current Stitch/PRD,
- icon sizing or tint,
- content inset and floating tabbar clearance,
- card radius, shadow, and background color through `DJDesignTokens`.

Disallowed changes:

- replacing the three-tab shell,
- exposing hidden branches by default,
- changing backend or persistence behavior during visual-only work.

- [ ] **Step 6: Run visual QA guards**

Run:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-scroll-inset-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/warm-tabbar-single-layer-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 7: Build**

Run:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/YYYYMMDD-current/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

If only docs/evidence were updated:

```bash
git add docs/superpowers/status/YYYY-MM-DD-final-stitch-visual-refresh.md
git commit -m "docs: refresh final stitch visual qa"
```

If code was changed:

```bash
git add DreamJourney/Sources docs/superpowers/status/YYYY-MM-DD-final-stitch-visual-refresh.md
git commit -m "fix: refresh stitch visual alignment"
```

### Task 2: Add One-Command Release Regression Runner

**Objective:** Reduce repeated manual command selection by creating a single guarded script that runs the current static checks, core simulator smokes, build, and summarizes artifact paths.

**Files:**

- Create: `Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh`
- Create: `Scripts/QA/prd-stitch-ui/release-regression-suite-check.swift`
- Modify: `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- Modify: `docs/superpowers/status/2026-06-18-release-qa-handoff.md`

- [ ] **Step 1: Write the static guard first**

Create `Scripts/QA/prd-stitch-ui/release-regression-suite-check.swift` with these assertions:

```swift
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func exists(_ path: String) {
    let url = root.appendingPathComponent(path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        fatalError("Missing \(path)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

exists("Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh")

let script = read("Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh")
for command in [
    "release-feature-matrix-check.swift",
    "profile-safety-flow-check.swift",
    "profile-care-escalation-backend-boundary-check.swift",
    "profile-family-persona-release-readiness-check.swift",
    "archive-media-release-readiness-check.swift",
    "submit-slice-inventory-check.swift",
    "run-archive-to-echo-smoke.sh",
    "run-profile-family-persona-release-smoke.sh",
    "run-profile-care-escalation-boundary-smoke.sh",
    "xcodebuild",
    "git diff --check"
] {
    assertContains(script, command, "release regression suite should run \(command)")
}

assertContains(script, "RUN_ID=", "suite should create a stable run id")
assertContains(script, "set -euo pipefail", "suite should fail fast")
assertContains(script, "CODE_SIGNING_ALLOWED=NO", "suite should build without device signing")

let package = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
assertContains(package, "run-release-regression-suite.sh", "release QA package should require the suite")
assertContains(package, "release-regression-suite-check.swift", "release QA package should require the suite guard")

print("Release regression suite checks passed")
```

- [ ] **Step 2: Run the guard and verify it fails**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/release-regression-suite-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fails because the script and package wiring do not exist yet.

- [ ] **Step 3: Create the runner script**

Create `Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="tmp/visual-qa/prd-stitch-ui/release-regression-suite/$RUN_ID"
mkdir -p "$OUT_DIR"

echo "[release-regression] run id: $RUN_ID"

swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift "$ROOT_DIR"
swift Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift "$ROOT_DIR"
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-contract-check.swift "$ROOT_DIR"
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift "$ROOT_DIR"
swift Scripts/QA/prd-stitch-ui/profile-family-persona-release-readiness-check.swift "$ROOT_DIR"
swift Scripts/QA/prd-stitch-ui/archive-media-release-readiness-check.swift "$ROOT_DIR"
swift Scripts/QA/prd-stitch-ui/persona-scoped-archive-context-check.swift "$ROOT_DIR"
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift "$ROOT_DIR"
swift Scripts/QA/prd-stitch-ui/submit-slice-inventory-check.swift "$ROOT_DIR"

RUN_ID="$RUN_ID-archive" Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh
RUN_ID="$RUN_ID-family" Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh
RUN_ID="$RUN_ID-care" Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh

git diff --check

xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$OUT_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build | tee "$OUT_DIR/build.log"

cat > "$OUT_DIR/report.md" <<REPORT
# Release Regression Suite

Run ID: $RUN_ID

## Commands

- release static guards
- archive-to-echo smoke
- family persona release smoke
- care escalation boundary smoke
- git diff --check
- iOS Debug simulator build

## Artifacts

- $OUT_DIR/build.log
- tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/$RUN_ID-archive/
- tmp/visual-qa/prd-stitch-ui/profile-family-persona-release-smoke/$RUN_ID-family/
- tmp/visual-qa/prd-stitch-ui/profile-care-escalation-boundary-smoke/$RUN_ID-care/
REPORT

echo "[release-regression] report: $OUT_DIR/report.md"
```

Then run:

```bash
chmod +x Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh
```

- [ ] **Step 4: Wire the runner into package checks**

Modify `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift` so `requiredScripts` includes:

```swift
"Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh",
"Scripts/QA/prd-stitch-ui/release-regression-suite-check.swift",
```

- [ ] **Step 5: Update the release handoff doc**

Modify `docs/superpowers/status/2026-06-18-release-qa-handoff.md` and add:

````markdown
## One-Command Regression

After Stitch UI, archive, Echo, Profile, family/persona, care, backend config, or release-gating changes, run:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=YYYYMMDD-purpose Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh
```

This suite is simulator/static evidence only. It does not replace true-device acceptance or real-backend acceptance.
````

- [ ] **Step 6: Verify the guard passes**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/release-regression-suite-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 7: Run the full suite**

Run:

```bash
RUN_ID=YYYYMMDD-release-regression Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh
```

Expected:

- archive smoke result has `completed = true`;
- family persona smoke result has `completed = true`;
- care escalation boundary smoke result has `completed = true`;
- build log contains `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

Run:

```bash
git add \
  Scripts/QA/prd-stitch-ui/run-release-regression-suite.sh \
  Scripts/QA/prd-stitch-ui/release-regression-suite-check.swift \
  Scripts/QA/prd-stitch-ui/release-qa-package-check.swift \
  docs/superpowers/status/2026-06-18-release-qa-handoff.md
git commit -m "test: add release regression suite"
```

### Task 3: Execute Real Backend Acceptance When Credentials Exist

**Objective:** Convert backend readiness into real backend evidence without committing credentials.

**Files:**

- Read: `docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`
- Read: `DreamJourney/Config/Backend.example.xcconfig`
- Read: `.gitignore`
- Read: `Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh`
- Modify if backend contract differs: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Modify if backend contract differs: `Scripts/QA/prd-stitch-ui/backend-family-acceptance-check.swift`
- Modify: `docs/superpowers/status/YYYY-MM-DD-real-backend-acceptance.md`

- [ ] **Step 1: Confirm credentials are available outside git**

Run:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
test -n "${BACKEND_BASE_URL:-}" && test -n "${BACKEND_API_TOKEN:-}"
```

Expected: exit 0. If this fails, stop and ask the user for backend URL/token.

- [ ] **Step 2: Confirm local config is ignored**

Run:

```bash
git check-ignore -v DreamJourney/Config/Backend.local.xcconfig
```

Expected: output includes `.gitignore`.

- [ ] **Step 3: Run backend acceptance smoke**

Run:

```bash
BACKEND_BASE_URL="$BACKEND_BASE_URL" \
BACKEND_API_TOKEN="$BACKEND_API_TOKEN" \
RUN_ID=YYYYMMDD-real-backend \
Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh
```

Expected result JSON:

```json
{
  "completed": true,
  "archiveRefreshSucceeded": true,
  "containsBackendContractPhoto": true,
  "careMoodStatus": "需关注",
  "familyRefreshSucceeded": true,
  "containsBackendFamilyMember": true
}
```

- [ ] **Step 4: If backend fields differ, update the typed boundary**

Only modify `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift` when the backend returns a stable field contract that differs from current code.

Allowed updates:

- add optional decode aliases,
- add fallback parsing for renamed fields,
- preserve current local fallback behavior,
- keep token required for real smoke.

Disallowed updates:

- hard-coding server URL or token,
- removing auth-token requirement,
- hiding backend failures as success.

- [ ] **Step 5: Document real backend result**

Create `docs/superpowers/status/YYYY-MM-DD-real-backend-acceptance.md` with:

```markdown
# Real Backend Acceptance

Date: YYYY-MM-DD
Branch: feature/prd-stitch-ui-adaptation
Backend: <host only, no token>

## Commands

## Result JSON

## Screenshots

## Contract Notes

## Failures And Fixes

## Remaining Risks
```

Do not include token values.

- [ ] **Step 6: Verify**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/backend-env-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/backend-family-acceptance-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/backend-real-acceptance/YYYYMMDD/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: all commands exit 0 and build succeeds.

- [ ] **Step 7: Commit**

Run:

```bash
git add DreamJourney/Sources/Services/DreamJourneyBackendClient.swift Scripts/QA/prd-stitch-ui/backend-family-acceptance-check.swift docs/superpowers/status/YYYY-MM-DD-real-backend-acceptance.md
git commit -m "test: record real backend acceptance"
```

If only docs changed, stage only the new doc.

### Task 4: Execute True-Device Acceptance When Device And Signing Exist

**Objective:** Convert true-device readiness into actual evidence for microphone, speech recognition, photo library, camera/privacy strings, foreground/background recovery, and archive-to-echo continuity.

**Files:**

- Read: `docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`
- Read: `DreamJourney/Resources/Info.plist`
- Modify if needed: `DreamJourney/Sources/Services/MicrophonePermissionManager.swift`
- Modify if needed: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Modify if needed: `DreamJourney/Sources/Modules/Archive/MemoryArchivePhotoEntryViewController.swift`
- Create: `docs/superpowers/status/YYYY-MM-DD-true-device-acceptance.md`

- [ ] **Step 1: Confirm device/signing availability**

Run:

```bash
xcrun xctrace list devices
```

Expected: an attached physical iPhone appears. If no device appears, stop and ask the user for true-device operation.

- [ ] **Step 2: Build for device**

Run with the user's signing configuration:

```bash
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'platform=iOS,name=<device name>' \
  build
```

Expected: build succeeds on the physical device destination.

- [ ] **Step 3: Validate permissions manually**

Record screenshots for:

```text
01-microphone-permission-allow.png
02-microphone-permission-deny.png
03-microphone-permission-recover.png
04-speech-permission.png
05-photo-permission.png
06-photo-selected-archive.png
07-archive-context-in-echo.png
08-background-foreground-recovery.png
```

Expected behavior:

- allowing microphone enters recording/listening state;
- denying microphone shows recoverable feedback and does not crash;
- restoring permission in Settings allows recording again;
- selecting a photo creates an archive item and local analysis state;
- Echo sees archive context after photo archive creation;
- background/foreground does not lose archive item or Echo UI state.

- [ ] **Step 4: Fix only verified true-device bugs**

Allowed fixes:

- permission denial copy,
- missing Settings recovery affordance,
- lifecycle cleanup for active recording,
- photo picker result handling,
- foreground/background state restoration.

Disallowed fixes:

- changing release-gating policy,
- replacing the voice engine,
- altering archive persistence format without migration.

- [ ] **Step 5: Document device acceptance**

Create `docs/superpowers/status/YYYY-MM-DD-true-device-acceptance.md`:

```markdown
# True Device Acceptance

Date: YYYY-MM-DD
Device:
iOS:
Branch:
Head:

## Build

## Permission Evidence

## Archive To Echo Evidence

## Bugs Found

## Fixes Applied

## Remaining Risks
```

- [ ] **Step 6: Verify post-fix simulator contracts**

Run:

```bash
Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh
swift Scripts/QA/prd-stitch-ui/device-backend-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 7: Commit**

Run:

```bash
git add DreamJourney/Sources docs/superpowers/status/YYYY-MM-DD-true-device-acceptance.md
git commit -m "test: record true device acceptance"
```

---

## P1 Work

P1 work fills PRD functionality that is currently hidden or only partially implemented. Promote one feature at a time.

### Task 5: Promote Archive Audio And Time Letters From Hidden QA To Product-Ready Release Gate

**Objective:** Make audio and time-letter archive branches technically releasable while keeping them hidden until true-device permission/playback and product release scope are approved.

**Files:**

- Read: `docs/superpowers/status/2026-06-18-archive-media-release-readiness.md`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationSheetViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- Modify: `Scripts/QA/prd-stitch-ui/archive-media-release-readiness-check.swift`
- Modify: `Scripts/QA/prd-stitch-ui/run-archive-media-entries-smoke.sh`
- Modify: `docs/superpowers/status/YYYY-MM-DD-archive-media-promotion.md`

- [ ] **Step 1: Preserve default hidden policy**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: public archive creation exposes text/photo only.

- [ ] **Step 2: Add or tighten static assertions**

Update `Scripts/QA/prd-stitch-ui/archive-media-release-readiness-check.swift` so it asserts:

- audio item has local persistence metadata;
- time-letter item has delivery/opening metadata;
- audio/time-letter remain hidden without `DJEnableArchiveHiddenBranches`;
- audio/time-letter appear with `DJEnableArchiveHiddenBranches`;
- video remains unavailable until a specific video task is created.

- [ ] **Step 3: Run the updated guard before code changes**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/archive-media-release-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fails if the new assertions are not implemented.

- [ ] **Step 4: Implement minimal release-ready metadata**

Add only metadata fields that support display, persistence, and PRD semantics:

```swift
[
    "mediaKind": "audio",
    "durationSeconds": "<integer string>",
    "createdFrom": "localRecorder",
    "releaseState": "hiddenReady"
]
```

For time letters:

```swift
[
    "mediaKind": "timeLetter",
    "scheduledOpenDate": "<ISO-8601 date string>",
    "deliveryState": "sealed",
    "releaseState": "hiddenReady"
]
```

Expected: metadata is stored with `MemoryArchiveItem` and visible in detail UI only as product-safe copy, not debug keys.

- [ ] **Step 5: Run media smoke**

Run:

```bash
RUN_ID=YYYYMMDD-archive-media Scripts/QA/prd-stitch-ui/run-archive-media-entries-smoke.sh
```

Expected result JSON:

```json
{
  "completed": true,
  "textCreated": true,
  "photoCreated": true,
  "audioCreated": true,
  "timeLetterCreated": true
}
```

- [ ] **Step 6: Verify and build**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/archive-media-release-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/archive-media-promotion/YYYYMMDD/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: all commands exit 0 and build succeeds.

- [ ] **Step 7: Commit**

Run:

```bash
git add DreamJourney/Sources/Modules/Archive Scripts/QA/prd-stitch-ui/archive-media-release-readiness-check.swift Scripts/QA/prd-stitch-ui/run-archive-media-entries-smoke.sh docs/superpowers/status/YYYY-MM-DD-archive-media-promotion.md
git commit -m "feat: harden hidden archive media readiness"
```

### Task 6: Prepare Public Family Management Promotion Without Exposing It

**Objective:** Turn the hidden family/persona switcher into a complete release candidate route while keeping public exposure behind `DJFeature.familyManagement` or explicit launch args.

**Files:**

- Modify: `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- Modify: `DreamJourney/Sources/Services/FamilyRepository.swift`
- Modify: `DreamJourney/Sources/App/DigitalHumanContextStore.swift`
- Modify: `Scripts/QA/prd-stitch-ui/profile-family-persona-switcher-check.swift`
- Modify: `Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh`
- Create: `docs/superpowers/status/YYYY-MM-DD-family-management-release-candidate.md`

- [ ] **Step 1: Confirm hidden public boundary**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: default profile does not expose `家人管理`, but UIQA hidden branch can switch persona context.

- [ ] **Step 2: Add candidate acceptance assertions**

Extend `profile-family-persona-switcher-check.swift` to assert:

- self context has owner id equal to current login user;
- family context has stable member id and display name;
- archive repository uses selected owner after switching;
- Echo context uses selected owner after switching;
- no delete action exists for family members, matching PRD "家人一旦创建无法删除".

- [ ] **Step 3: Verify the new assertions fail if missing**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fails until the candidate contract is implemented.

- [ ] **Step 4: Implement only candidate-safe behavior**

Allowed implementation:

- show self and accepted family members in hidden `家人管理`;
- switch selected context through `DigitalHumanContextStore`;
- refresh archive and Echo context after switching;
- display "不可删除" or omit delete controls.

Disallowed implementation:

- deleting family members;
- exposing invite/accept flows publicly without backend acceptance;
- exposing family management in default public release.

- [ ] **Step 5: Run release smoke**

Run:

```bash
RUN_ID=YYYYMMDD-family-candidate Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh
```

Expected: result JSON has `completed = true` and `profileTabSelected = true`.

- [ ] **Step 6: Verify and build**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-family-persona-release-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/family-management-candidate/YYYYMMDD/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: all commands exit 0 and build succeeds.

- [ ] **Step 7: Commit**

Run:

```bash
git add DreamJourney/Sources/Modules/Profile DreamJourney/Sources/Services/FamilyRepository.swift DreamJourney/Sources/App/DigitalHumanContextStore.swift Scripts/QA/prd-stitch-ui/profile-family-persona-switcher-check.swift Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh docs/superpowers/status/YYYY-MM-DD-family-management-release-candidate.md
git commit -m "feat: harden hidden family management candidate"
```

### Task 7: Define And Guard Sunlight / Star / Silent Lifecycle Policy

**Objective:** Make PRD lifecycle states actionable in code boundaries while keeping mode names out of Echo visible copy.

**Files:**

- Modify: `DreamJourney/Sources/App/DigitalHumanContextStore.swift`
- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewModel.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- Modify: `Scripts/QA/prd-stitch-ui/digital-human-mode-lifecycle-check.swift`
- Modify: `docs/superpowers/status/2026-06-18-digital-human-mode-lifecycle.md`

- [ ] **Step 1: Expand lifecycle guard**

Update `digital-human-mode-lifecycle-check.swift` to require:

- sunlight mode has no `心境追踪` requirement for ordinary family/self assistant unless current release fallback allows it;
- star mode enables psychological guidance and `心境追踪`;
- silent mode does not claim death or inheritance without family confirmation;
- Echo visible text does not show internal strings `阳光模式`, `星辰模式`, `静默模式`;
- mode-specific behavior is represented in prompt/context metadata.

- [ ] **Step 2: Run the guard before code changes**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/digital-human-mode-lifecycle-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fails if any new lifecycle assertion is missing.

- [ ] **Step 3: Implement lifecycle boundary helpers**

Use explicit helper names in `DigitalHumanContextStore` or a nearby model:

```swift
var enablesCareGuidance: Bool
var allowsInheritanceCopy: Bool
var visibleEchoModeLabel: String?
```

Expected:

- `enablesCareGuidance` is true only for star-like state or default self fallback explicitly documented for current release;
- `allowsInheritanceCopy` is false until product/legal confirms digital inheritance flow;
- `visibleEchoModeLabel` is nil for internal mode names.

- [ ] **Step 4: Verify mode behavior**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/digital-human-mode-lifecycle-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Build and commit**

Run:

```bash
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/digital-human-mode-lifecycle/YYYYMMDD/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git add DreamJourney/Sources/App/DigitalHumanContextStore.swift DreamJourney/Sources/Modules/Echo/EchoViewModel.swift DreamJourney/Sources/Modules/Profile Scripts/QA/prd-stitch-ui/digital-human-mode-lifecycle-check.swift docs/superpowers/status/2026-06-18-digital-human-mode-lifecycle.md
git commit -m "feat: guard digital human lifecycle policy"
```

### Task 8: Turn Account Deletion Shell Into Compliance-Blocked Contract

**Objective:** Keep account deletion hidden, but make its required backend/product contract explicit and testable.

**Files:**

- Modify: `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- Create: `DreamJourney/Sources/Modules/Profile/ProfileAccountDeletionContract.swift`
- Modify: `Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift`
- Create: `Scripts/QA/prd-stitch-ui/profile-account-deletion-boundary-check.swift`
- Create: `docs/superpowers/status/YYYY-MM-DD-account-deletion-boundary.md`

- [ ] **Step 1: Create failing static guard**

`profile-account-deletion-boundary-check.swift` must assert:

- account deletion is hidden by default;
- hidden shell exists only under profile hidden branches or `DJFeature.accountDeletion`;
- no backend deletion call exists;
- confirmation copy mentions irreversible deletion and data export/cooling-off requirements;
- no user data is deleted locally by the shell.

- [ ] **Step 2: Run guard and confirm failure**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/profile-account-deletion-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fails until the contract file and wiring exist.

- [ ] **Step 3: Add explicit contract model**

Create `ProfileAccountDeletionContract.swift` with a simple non-executing model:

```swift
import Foundation

struct ProfileAccountDeletionContract {
    let schemaVersion = "profileAccountDeletion.v1"
    let executionState = "blockedPendingCompliance"
    let requiresDataExport = true
    let requiresCoolingOffPeriod = true
    let requiresFinalConfirmation = true
    let backendContractConnected = false
    let deletesLocalDataImmediately = false
}
```

- [ ] **Step 4: Wire the shell to display contract-safe copy**

Expected visible hidden-branch copy:

```text
账号注销暂未开放
正式注销前需要完成数据导出、冷静期和最终确认。当前不会删除任何本地或云端数据。
```

- [ ] **Step 5: Verify**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/profile-account-deletion-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/account-deletion-boundary/YYYYMMDD/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: all commands exit 0 and build succeeds.

- [ ] **Step 6: Commit**

Run:

```bash
git add DreamJourney/Sources/Modules/Profile Scripts/QA/prd-stitch-ui/profile-account-deletion-boundary-check.swift Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift docs/superpowers/status/YYYY-MM-DD-account-deletion-boundary.md
git commit -m "feat: add account deletion boundary contract"
```

### Task 9: Define Care Escalation Real Backend Contract Without Enabling Calls

**Objective:** Move `关怀升级草稿` from draft-only evidence toward a backend contract spec, but keep real doctor contact disabled until product/legal/backend approval.

**Files:**

- Modify: `DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- Modify: `Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift`
- Modify: `Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh`
- Create: `docs/superpowers/status/YYYY-MM-DD-care-escalation-backend-contract.md`

- [ ] **Step 1: Extend contract assertions**

Update `profile-care-escalation-backend-boundary-check.swift` so payload assertions require:

- `schemaVersion = profileCareEscalationDraft.v1`;
- `deliveryState = draftOnly`;
- `riskLevel` uses PRD values `L1`, `L2`, `L3`, or `L4`;
- `emergencyUse = false`;
- `requiresHumanReview = true`;
- `containsRawTranscript = false`;
- `contactActionEnabled = false`;
- `backendContractConnected = false`.

- [ ] **Step 2: Run guard before implementation**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: fails if the richer contract is missing.

- [ ] **Step 3: Add risk-level mapping**

Implement a safe mapping in `ProfileCareModels.swift`:

```swift
enum ProfileCareRiskLevel: String {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
    case l4 = "L4"
}
```

Map current care snapshot copy to the lowest safe explicit level when unknown:

```swift
let riskLevel = ProfileCareRiskLevel.l2.rawValue
```

Do not claim diagnosis or emergency detection.

- [ ] **Step 4: Update smoke result validation**

`run-profile-care-escalation-boundary-smoke.sh` must validate:

```text
"riskLevel":"L2"
"contactActionEnabled":false
"backendContractConnected":false
"containsRawTranscript":false
```

- [ ] **Step 5: Verify and build**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=YYYYMMDD-care-contract Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/care-escalation-contract/YYYYMMDD/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: all commands exit 0 and build succeeds.

- [ ] **Step 6: Commit**

Run:

```bash
git add DreamJourney/Sources/Modules/Profile Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh docs/superpowers/status/YYYY-MM-DD-care-escalation-backend-contract.md
git commit -m "feat: extend care escalation backend contract"
```

---

## P2 Work

P2 work improves maintainability and prepares future PRD stages. Do this after P0 is stable and P1 boundaries are guarded.

### Task 10: Add PRD Coverage Matrix

**Objective:** Keep one living matrix that maps each PRD requirement to implemented, hidden, blocked, or future status.

**Files:**

- Create: `docs/superpowers/status/YYYY-MM-DD-prd-coverage-matrix.md`
- Create: `Scripts/QA/prd-stitch-ui/prd-coverage-matrix-check.swift`
- Modify: `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`

- [ ] **Step 1: Create matrix doc**

The doc must include these rows:

```markdown
| PRD requirement | Current status | Public? | Evidence | Next action |
| --- | --- | --- | --- | --- |
| 回响语音输入 | implemented | yes | EchoViewController, archive-to-echo smoke | true-device microphone acceptance |
| 2-3轮后等待回信 | partially implemented | yes | EchoViewModel | tune delay policy after product review |
| 档案照片 | implemented | yes | Archive photo entry smoke | true-device photo acceptance |
| 档案视频 | not implemented | no | release matrix | define video upload scope |
| 档案录音 | hidden candidate | no | archive media smoke | true-device audio acceptance |
| 档案文字描述 | implemented | yes | archive smoke | maintain |
| 时间信件 | hidden candidate | no | archive media smoke | delivery policy |
| 个人资料管理 | partially implemented | yes | ProfileSettingsViewController | avatar/password scope |
| 心境追踪 | implemented fallback | yes | Profile care checks | lifecycle policy |
| 家人管理 | hidden candidate | no | family persona smoke | product exposure decision |
| 法律法规 | implemented | yes | ProfileLegalViewController | legal review |
| 账号退出 | implemented | yes | ProfileViewController | maintain |
| 账号注销 | hidden blocked shell | no | safety check | compliance/backend contract |
| 长辈关怀 | implemented aggregate | yes | elder dashboard check | real backend acceptance |
| 生死转换机制 | hidden boundary | no | mode lifecycle checks | product/legal policy |
```

- [ ] **Step 2: Create matrix guard**

`prd-coverage-matrix-check.swift` must assert the matrix contains all rows above and does not mark true-device/backend acceptance as complete unless a real acceptance doc exists.

- [ ] **Step 3: Verify**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/prd-coverage-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/superpowers/status/YYYY-MM-DD-prd-coverage-matrix.md Scripts/QA/prd-stitch-ui/prd-coverage-matrix-check.swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift
git commit -m "docs: add prd coverage matrix"
```

### Task 11: Clean Up Warning Debt Only After Functional Slices Are Stable

**Objective:** Reduce low-risk source warnings without changing behavior or disrupting PRD/UI work.

**Files:**

- Read: `docs/superpowers/status/2026-06-17-source-warning-cleanup.md`
- Modify only files listed by warning logs and `source-warning-cleanup-check.swift`
- Modify: `Scripts/QA/prd-stitch-ui/source-warning-cleanup-check.swift`
- Create: `docs/superpowers/status/YYYY-MM-DD-source-warning-cleanup-batch.md`

- [ ] **Step 1: Capture warnings**

Run:

```bash
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/source-warning-cleanup/YYYYMMDD/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build | tee tmp/visual-qa/prd-stitch-ui/source-warning-cleanup/YYYYMMDD/build.log
rg -n "warning:" tmp/visual-qa/prd-stitch-ui/source-warning-cleanup/YYYYMMDD/build.log
```

Expected: warning list is explicit before edits.

- [ ] **Step 2: Fix one warning class**

Allowed warning classes:

- unused local variable,
- unnecessary optional cast,
- redundant access modifier,
- deprecated API with direct replacement.

Disallowed warning classes:

- behavior-affecting concurrency fixes without tests,
- third-party Pods warning edits,
- architecture refactors.

- [ ] **Step 3: Verify**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/source-warning-cleanup-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/source-warning-cleanup/YYYYMMDD/DerivedDataFinal \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: build succeeds; no new app-source warning of the fixed class remains.

- [ ] **Step 4: Commit**

Run:

```bash
git add DreamJourney/Sources Scripts/QA/prd-stitch-ui/source-warning-cleanup-check.swift docs/superpowers/status/YYYY-MM-DD-source-warning-cleanup-batch.md
git commit -m "chore: clean low risk source warnings"
```

---

## Release Candidate Gate

Run this gate when P0 is complete and before asking the user to push or true-device test.

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-care-escalation-backend-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-family-persona-release-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/archive-media-release-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/device-backend-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/backend-build-config-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/backend-env-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=YYYYMMDD-rc-archive Scripts/QA/prd-stitch-ui/run-archive-to-echo-smoke.sh
RUN_ID=YYYYMMDD-rc-family Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh
RUN_ID=YYYYMMDD-rc-care Scripts/QA/prd-stitch-ui/run-profile-care-escalation-boundary-smoke.sh
git diff --check
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath tmp/visual-qa/prd-stitch-ui/release-candidate/YYYYMMDD/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected:

- all static guards exit 0;
- all smoke result JSON files have `completed = true`;
- build succeeds;
- default public surface still hides unfinished/high-risk flows;
- no real backend or true-device claims are made unless Tasks 3 and 4 have completed with evidence.

## Stop Conditions

Stop and ask the user before continuing if any task requires:

- real `DREAMJOURNEY_BACKEND_BASE_URL` or `DREAMJOURNEY_BACKEND_API_TOKEN`;
- Apple Developer Team, signing certificate, provisioning profile, or physical device operation;
- changing public exposure of family management, account deletion, doctor contact, audio/time-letter/video upload, or lifecycle transitions;
- deleting user data, migrating existing persistent data, or changing backend compatibility;
- emergency, medical, or third-party contact behavior.

## Recommended Execution Order

1. Task 1: Refresh final Stitch visual QA package.
2. Task 2: Add one-command release regression runner.
3. Task 10: Add PRD coverage matrix.
4. Task 5: Harden hidden archive media readiness.
5. Task 6: Harden hidden family management candidate.
6. Task 7: Guard lifecycle policy.
7. Task 8: Add account deletion boundary contract.
8. Task 9: Extend care escalation backend contract.
9. Task 3: Execute real backend acceptance when credentials exist.
10. Task 4: Execute true-device acceptance when device/signing exists.
11. Task 11: Clean low-risk warning debt after functional work is stable.

## Next Best Task From Current State

Start with **Task 1: Refresh Final Stitch Visual QA Package**.

Reason:

- It directly protects the current UI adaptation goal.
- It catches accidental visual drift after the many P1/P0 safety and backend boundary commits.
- It does not require backend credentials or physical device access.
- It creates the cleanest baseline before adding more product functionality.
