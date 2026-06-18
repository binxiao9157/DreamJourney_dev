# Post Backend Acceptance Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After simulator release-like FastAPI/Postgres acceptance has passed, move DreamJourney toward true-device acceptance, final Stitch UI alignment, and a clean PRD release boundary.

**Architecture:** Keep the current UIKit app shell and release-gated feature model. Treat current Stitch canvas + downloaded `htmlCode` as visual authority, with MCP screenshots only as auxiliary evidence. Keep backend release-like regression as a required gate after any backend, Archive, Profile/Care, Family, or configuration change.

**Tech Stack:** UIKit, Swift, Xcode simulator/device builds, FastAPI/Postgres backend, Stitch MCP/htmlCode, shell/Python/Swift QA scripts.

---

## Current Baseline

- Branch: `feature/prd-stitch-ui-adaptation`
- App repo: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- Backend repo: `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend`
- Backend simulator release-like acceptance: accepted with run `20260618-deployed-postgres-acceptance-after-deploy`
- Backend evidence: `tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-deployed-postgres-acceptance-after-deploy/`
- Remaining external blocker: true-device signing/operation
- Confirmed product/design decision: keep the public tab shell as `记忆档案 / 回响 / 我的`; `我的` carries settings, account, legal, family/care, and hidden safety entries.
- Remaining product/design blocker: newest Stitch Echo variants are candidates only and need explicit selection before replacing the current public Echo surface.

## Phase Order

1. Phase A: True-device readiness without changing product scope.
2. Phase B: Profile IA consolidation under `我的` and Stitch visual alignment.
3. Phase C: Release-scope hardening for public MVP features.
4. Phase D: Hidden PRD candidates, still gated by feature flags.
5. Phase E: Final release QA package and handoff.

Do not start Phase D public exposure work until Phase B keeps hidden entries gated and documents which `我的` entries are public versus QA-only.

---

### Task 1: True-Device Readiness Checklist

**Purpose:** Prepare a precise device验收 checklist before touching signing or device-specific code.

**Files:**
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-06-18-prd-coverage-matrix.md`
- Test: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift`

- [ ] **Step 1: Read current readiness docs**

Run:

```bash
sed -n '1,220p' docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md
sed -n '1,140p' docs/superpowers/status/2026-06-18-prd-coverage-matrix.md
```

Expected: docs still mark true-device as `not accepted`.

- [ ] **Step 2: Add device checklist sections**

Add these sections to `2026-06-18-device-backend-acceptance-readiness.md`:

```markdown
## True-Device Acceptance Checklist

- Signing profile and team are configured for the app bundle.
- Device can install the current Debug or release-like build.
- `DreamJourneyBackendBaseURL` points to `https://dreamjourney-api.liftora.cn`.
- `DreamJourneyBackendAPIToken` is injected from a local/private config source and not committed.
- Microphone permission prompt appears and recording state is visible.
- Photo picker permission/access path works with a real photo.
- Archive -> Echo context uses the real created archive item.
- Profile/Care fetches `需关注` backend care data from the deployed backend.
- App can recover gracefully when network is offline and then online again.

## Evidence To Capture

- Device model and iOS version.
- Install/build command.
- Screenshot or screen recording for Archive -> Echo -> Profile/Care.
- Device console excerpts for backend success and permission paths.
```

- [ ] **Step 3: Update PRD coverage wording**

In `2026-06-18-prd-coverage-matrix.md`, keep:

```markdown
- 真机验收：not accepted
```

Add:

```markdown
- Backend release-like simulator acceptance has passed; true-device acceptance remains separate.
```

- [ ] **Step 4: Update guard**

In `prd-coverage-matrix-check.swift`, assert both strings:

```swift
assertContains(coverage, "真机验收：not accepted", "coverage matrix should preserve true-device boundary")
assertContains(coverage, "Backend release-like simulator acceptance has passed", "coverage matrix should separate backend simulator and true-device acceptance")
```

- [ ] **Step 5: Verify**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: both commands pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md docs/superpowers/status/2026-06-18-prd-coverage-matrix.md tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift
git commit -m "docs: refine true-device acceptance checklist"
```

---

### Task 2: Profile IA Contract Under `我的`

**Purpose:** Convert the confirmed product decision into an implementation contract: `我的` stays as the third public tab and carries settings/account/legal/care entries. `长辈关怀` is content inside Profile/Care, not a tab replacement.

**Files:**
- Create: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-06-18-profile-ia-contract.md`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/task_plan.md`
- Test: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift`

- [x] **Step 1: Refresh Stitch source list**

Use Stitch MCP for project `2650033127117292960`:

```text
get_project(projects/2650033127117292960)
list_screens(projectId=2650033127117292960)
```

Expected: record current screen titles, screen IDs, and which records are current targets versus candidate/hidden variants.

- [x] **Step 2: Create Profile IA contract**

Create `2026-06-18-profile-ia-contract.md` with:

```markdown
# Profile IA Contract

Date: 2026-06-18

## Confirmed Decision

The app currently ships a three-tab MVP shell:

- `记忆档案`
- `回响`
- `我的`

Keep `我的` as the third public tab. Do not rename the tab to `长辈关怀`.

`我的` is the container for:

- user identity/persona summary;
- `心境追踪`;
- `长辈关怀` aggregate card or child dashboard entry;
- `个人资料设置`;
- `法律法规`;
- `退出登录`;
- hidden QA-only entries such as `家人管理`, `立即通话`, and `注销账户`.

## Public Release Boundary

- Public by default: identity/persona card, mood/care summary, profile settings, legal center, logout.
- Public only if existing release gates say yes: aggregate care dashboard.
- Hidden unless feature flags are enabled: family management, doctor contact/care escalation, account deletion, persona/lifecycle management.

## Stitch Evidence Rules

- Current Stitch canvas + downloaded `htmlCode` are the visual authority.
- MCP screenshot and `list_screens` metadata are auxiliary only.
- Multiple `时空对话` records in MCP are candidate/variant evidence, not automatic targets.
- A profile-like screen title containing `长辈关怀` does not override the tab label when the canvas/instance/product decision says `我的`.

## Implementation Implications

- Keep `TabCoordinator` and bottom nav label as `我的`.
- Keep Profile module as the owner of account/settings/legal/care entry composition.
- If care UX grows, add a Profile child page or section under `我的`; do not add a fourth tab or rename the third tab.
- If a future Stitch update changes this IA, require a new explicit product decision before code changes.
```

- [x] **Step 3: Update task plan**

In `task_plan.md`, add:

```markdown
- Profile IA contract exists; `我的` remains the third public tab and carries settings/account/legal/care entries.
```

- [x] **Step 4: Extend visual QA guard**

Add the Profile IA contract to the final visual QA guard required docs if that script already enumerates required files:

```swift
assertFileExists(
    "docs/superpowers/status/2026-06-18-profile-ia-contract.md",
    "Profile IA contract"
)
```

- [x] **Step 5: Verify**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: guard passes and no whitespace errors.

- [x] **Step 6: Commit**

Run:

```bash
git add docs/superpowers/status/2026-06-18-profile-ia-contract.md task_plan.md tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift
git commit -m "docs: add Profile IA contract"
```

---

### Task 3: Release-Like Regression Should Require Backend Pass

**Purpose:** Now that deployed backend acceptance exists, make the one-command release regression optionally enforce it for release handoff.

**Files:**
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-06-18-one-command-release-regression.md`
- Test: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift`

- [ ] **Step 1: Inspect current regression flags**

Run:

```bash
sed -n '1,230p' tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

Expected: confirm `RUN_RELEASE_LIKE_BACKEND` exists and defaults to optional.

- [ ] **Step 2: Add release handoff mode**

In `run-release-regression.sh`, add:

```bash
if [[ "${RELEASE_HANDOFF_MODE:-0}" == "1" ]]; then
  RUN_RELEASE_LIKE_BACKEND="${RUN_RELEASE_LIKE_BACKEND:-1}"
fi
```

Place this after default flag initialization and before executing checks.

- [ ] **Step 3: Document command**

In `2026-06-18-one-command-release-regression.md`, add:

```markdown
## Release Handoff Mode

Use this when backend credentials are available and the build is being prepared for broader handoff:

```bash
RELEASE_HANDOFF_MODE=1 \
BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn \
BACKEND_API_TOKEN='<server token from private access doc>' \
RUN_ID=20260618-release-handoff \
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

This forces release-like FastAPI/Postgres acceptance to run as part of the one-command package.
```

- [ ] **Step 4: Update package guard**

In `release-qa-package-check.swift`, assert:

```swift
assertContains(runner, "RELEASE_HANDOFF_MODE", "release regression should support backend-required handoff mode")
```

- [ ] **Step 5: Verify without backend**

Run:

```bash
RUN_ID=20260618-regression-no-backend RUN_RELEASE_LIKE_BACKEND=0 tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

Expected: release-like backend acceptance is skipped by explicit flag, other checks pass.

- [ ] **Step 6: Verify package guard**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: both pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add tmp/visual-qa/prd-stitch-ui/run-release-regression.sh docs/superpowers/status/2026-06-18-one-command-release-regression.md tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift
git commit -m "test: require backend in release handoff mode"
```

---

### Task 4: Public MVP UI Polish Pass

**Purpose:** Polish only currently public surfaces without exposing hidden PRD candidates.

**Files:**
- Modify as needed:
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/App/WarmTabBarController.swift`
- Test:
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`

- [ ] **Step 1: Capture current public screenshots**

Run the existing release state or final visual QA smoke, saving screenshots under:

```text
tmp/visual-qa/prd-stitch-ui/public-mvp-polish/20260618-current/
```

Expected screenshots:

```text
01-echo-default.png
02-archive-default.png
03-profile-default.png
```

- [ ] **Step 2: Compare against Stitch authority**

Use current Stitch canvas + downloaded `htmlCode`, not MCP screenshot alone. Record differences in:

```text
tmp/visual-qa/prd-stitch-ui/public-mvp-polish/20260618-current/report.md
```

Required headings:

```markdown
## Accepted Release-Gated Differences
## Public UI Issues To Fix
## Hidden Features Not Exposed
```

- [ ] **Step 3: Fix one visual issue only**

Choose the highest-impact low-risk issue, such as:

- bottom inset spacing,
- list/card vertical rhythm,
- tab selected/unselected state,
- profile care card text alignment.

Do not rename tabs, expose hidden buttons, or replace Echo variants in this task.

- [ ] **Step 4: Run simulator smoke**

Run:

```bash
RUN_ID=20260618-public-mvp-polish tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

Expected: regression passes or fails with a concrete visual/functional reason to fix.

- [ ] **Step 5: Build**

Run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/public-mvp-polish/20260618-current/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

Run:

```bash
git add DreamJourney/Sources tmp/visual-qa/prd-stitch-ui/public-mvp-polish/20260618-current/report.md
git commit -m "ui: polish public MVP surfaces"
```

---

### Task 5: Hidden Candidate Release Matrix

**Purpose:** Keep hidden PRD candidates explicit and prevent accidental public exposure.

**Files:**
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-06-18-prd-coverage-matrix.md`
- Test: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift`

- [ ] **Step 1: Audit hidden features**

Check and list:

```text
archive audio upload
time letters
video upload
persona settings
family management public release
account deletion execution
doctor contact / intervention execution
sunlight/star/silent lifecycle transition controls
digital inheritance lifecycle
```

- [ ] **Step 2: Add release decision columns**

In release matrix, add columns:

```markdown
| Feature | Current gate | Public in MVP | Needed before public | Test evidence |
```

- [ ] **Step 3: Update guard**

Assert these public rules:

```swift
assertContains(matrix, "archive audio upload", "matrix should include audio upload")
assertContains(matrix, "Public in MVP", "matrix should include public MVP decision column")
assertContains(matrix, "No hidden PRD feature is public by default", "matrix should preserve gating policy")
```

- [ ] **Step 4: Verify**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Expected: all pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add docs/superpowers/status/2026-06-17-release-feature-matrix.md docs/superpowers/status/2026-06-18-prd-coverage-matrix.md tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift
git commit -m "docs: clarify hidden candidate release gates"
```

---

### Task 6: True-Device Acceptance Execution

**Purpose:** Execute final device acceptance once a physical device, signing, and local/private config are available.

**Files:**
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`
- Modify: `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/superpowers/status/2026-06-18-prd-coverage-matrix.md`
- Test evidence directory:
  - `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/true-device-acceptance/<run-id>/`

- [ ] **Step 1: Confirm external inputs**

Required before running:

```text
physical iPhone device connected
Apple signing team selected
bundle id installable on device
backend URL/token available via private config
microphone permission can be granted
photo library access can be granted
```

- [ ] **Step 2: Build/install on device**

Use Xcode or `xcodebuild` with an actual device destination. Record exact command in:

```text
tmp/visual-qa/prd-stitch-ui/true-device-acceptance/<run-id>/commands.log
```

- [ ] **Step 3: Manual device flow**

Run this sequence on device:

```text
Login/Register -> 记忆档案 -> create text/photo archive -> 回响 -> voice interaction -> 我的 -> 心境追踪 / 关怀
```

- [ ] **Step 4: Capture evidence**

Save:

```text
01-device-login.jpg
02-device-archive-created.jpg
03-device-echo-context.jpg
04-device-profile-care.jpg
device-console.log
report.md
```

- [ ] **Step 5: Update acceptance docs**

Only if all device checks pass, change:

```markdown
- 真机验收：accepted
```

If any device check fails, keep:

```markdown
- 真机验收：not accepted
```

and list exact failure.

- [ ] **Step 6: Verify and commit**

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

Commit:

```bash
git add docs/superpowers/status tmp/visual-qa/prd-stitch-ui/true-device-acceptance/<run-id>/report.md
git commit -m "docs: record true-device acceptance"
```

---

## Recommended Next Task

Task 2 is complete. Start with **Task 3: Release-Like Regression Should Require Backend Pass** if no physical device/signing is ready.

Start with **Task 1: True-Device Readiness Checklist** if you want to prepare for device acceptance before more UI work.

Start with **Task 3: Release-Like Regression Should Require Backend Pass** if you want the QA package to enforce the backend gate automatically for release handoff.

## Self-Review

- Spec coverage: PRD core loop is covered by backend simulator acceptance; `我的` / `长辈关怀` IA is now decided; remaining uncovered items are true-device, hidden candidate public exposure, and explicit Echo variant selection if the current public Echo surface changes.
- Placeholder scan: no task uses open-ended placeholder instructions.
- Type consistency: scripts and docs use the existing `run-release-like-backend-acceptance.sh`, `run-release-regression.sh`, PRD matrix guard, and final visual QA guard names consistently.
