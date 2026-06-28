# PRD Full Feature Follow-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于 2026-06-18 新 PRD 明确项，把 DreamJourney 从“模拟器验证过的 MVP 候选”推进到“公开 MVP 功能完整、后端可验收、真机验收准备充分”的状态。

**Architecture:** 继续保持 UIKit 三 Tab 架构：`记忆档案`、`回响`、`我的`。公开 MVP 只补齐已经明确的能力；语音档案、时间信件、家人管理、账号注销、医生联系执行、数字人生命周期等高风险/隐藏候选继续受 feature flag 或 QA launch arg 保护。

**Tech Stack:** UIKit, Swift, UserDefaults/local persistence, Alamofire backend client, FastAPI backend, Xcode simulator UIQA scripts, Swift static guard scripts, release regression shell scripts.

---

## Source Of Truth

- Product decisions: `docs/superpowers/status/2026-06-18-prd-full-feature-closure-decisions.md`
- PRD coverage: `docs/superpowers/status/2026-06-18-prd-coverage-matrix.md`
- Release scope: `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- Echo wait policy: `docs/superpowers/status/2026-06-18-echo-waiting-reply-policy.md`
- Profile save state: `docs/superpowers/status/2026-06-18-profile-settings-save-state.md`
- Visual authority: current Stitch canvas + exported `htmlCode`; MCP screenshot is auxiliary evidence only.

## Current Baseline

Already done:

- Public tabs remain `记忆档案`、`回响`、`我的`.
- Echo default wait policy has been updated from old third-turn policy to ten-round baseline.
- Echo wait copy uses walk-out guidance: `先去窗边走走，约 5 分钟后我再回信`.
- Profile settings has nickname validation, save states, local persistence, backend-ready fallback.
- Release regression includes PRD decision sync guard.

Still missing for full PRD closure:

- Echo local notification, push notification contract, and wait-state restoration.
- Account profile fields: avatar, name, gender, region, phone, password change.
- Archive text/photo production persistence with family digital-human visibility and ownership rules.
- Archive media analysis disclosure: backend + AI assisted, AI primary.
- Care dashboard backend states and visible non-executing intervention placeholder.
- True-device acceptance for microphone, photo library, notification permission, signing.

## File Map

Echo notification slice:

- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewModel.swift`
- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Create: `DreamJourney/Sources/Services/EchoDelayedReplyStore.swift`
- Create: `DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift`
- Modify: `DreamJourney/Sources/AppDelegate.swift`
- Create: `Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift`
- Modify: `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- Modify: `Scripts/QA/prd-stitch-ui/run-release-regression.sh`
- Update: `docs/superpowers/status/2026-06-18-echo-waiting-reply-policy.md`

Profile/account slice:

- Modify: `DreamJourney/Sources/Services/MemoryModel.swift`
- Modify: `DreamJourney/Sources/Services/UserManager.swift`
- Modify: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift`
- Create: `DreamJourney/Sources/Modules/Profile/ProfilePasswordChangeViewController.swift`
- Create: `Scripts/QA/prd-stitch-ui/profile-account-fields-check.swift`
- Create: `Scripts/QA/prd-stitch-ui/profile-password-change-check.swift`
- Update: `docs/superpowers/status/2026-06-18-profile-settings-save-state.md`

Archive production slice:

- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift`
- Modify: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Create: `Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift`
- Create: `Scripts/QA/prd-stitch-ui/archive-analysis-disclaimer-check.swift`

Care dashboard slice:

- Modify: `DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileElderCareDashboardViewController.swift`
- Modify: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Create: `Scripts/QA/prd-stitch-ui/profile-care-public-placeholder-check.swift`

Release/QA slice:

- Modify: `docs/superpowers/status/2026-06-18-prd-coverage-matrix.md`
- Modify: `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- Modify: `Scripts/QA/prd-stitch-ui/run-release-regression.sh`
- Modify: `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`

---

## Phase 1: Echo Wait Reply Completion

Priority: P0.

Product basis:

- 用户发言 + AI 回复算 1 轮。
- 默认 10 轮后等待回信。
- 情绪/内容问题可提前触发。
- 等待时长 5-10 分钟。
- App 内状态、本地通知、推送通知都需要。

### Task 1.1: Persist Delayed Reply State

**Files:**

- Create: `DreamJourney/Sources/Services/EchoDelayedReplyStore.swift`
- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewModel.swift`
- Test: `Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift`

- [ ] **Step 1: Write failing static guard**

Create a guard that requires a persisted delayed reply model:

```swift
assertContains(echoStore, "struct EchoDelayedReply: Codable, Equatable", "Echo delayed reply should be persisted")
assertContains(echoStore, "scheduledAt: Date", "Echo delayed reply should store scheduled time")
assertContains(echoStore, "deliverAt: Date", "Echo delayed reply should store delivery time")
assertContains(echoStore, "userTurnCount: Int", "Echo delayed reply should store triggering turn count")
assertContains(echoStore, "trigger: EchoDelayedReplyTrigger", "Echo delayed reply should store trigger reason")
```

Run:

```bash
swift Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: FAIL because the store does not exist.

- [ ] **Step 2: Add persisted model and store**

Implement:

```swift
struct EchoDelayedReply: Codable, Equatable {
    let id: String
    let scheduledAt: Date
    let deliverAt: Date
    let minutes: Int
    let userTurnCount: Int
    let trigger: EchoDelayedReplyTrigger
}

enum EchoDelayedReplyTrigger: String, Codable {
    case tenRoundBaseline
    case contentSignal
}

final class EchoDelayedReplyStore {
    static let shared = EchoDelayedReplyStore()
    private let storageKey = "dj.echo.delayedReply"

    func save(_ reply: EchoDelayedReply) -> Bool
    func load() -> EchoDelayedReply?
    func clear()
}
```

- [ ] **Step 3: Save wait state from `EchoViewModel`**

When `finishUserVoice(text:)` enters `.waitingReply(minutes:)`, create and save `EchoDelayedReply`.

- [ ] **Step 4: Re-run guard**

Run:

```bash
swift Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add DreamJourney/Sources/Services/EchoDelayedReplyStore.swift DreamJourney/Sources/Modules/Echo/EchoViewModel.swift Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift
git commit -m "feat: persist Echo delayed reply state"
```

### Task 1.2: Schedule Local Notification

**Files:**

- Create: `DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift`
- Modify: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Modify: `DreamJourney/Sources/AppDelegate.swift`
- Test: `Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift`

- [ ] **Step 1: Extend guard**

Require `UserNotifications` and scheduler methods:

```swift
assertContains(scheduler, "import UserNotifications", "Echo delayed reply should use local notifications")
assertContains(scheduler, "func requestAuthorizationIfNeeded", "Scheduler should request local notification authorization")
assertContains(scheduler, "func schedule(_ delayedReply: EchoDelayedReply", "Scheduler should schedule local notification")
assertContains(scheduler, "func cancelPendingDelayedReply", "Scheduler should cancel stale Echo notifications")
```

Expected: FAIL before scheduler exists.

- [ ] **Step 2: Implement scheduler**

Use one stable notification identifier:

```swift
final class EchoDelayedReplyNotificationScheduler {
    static let shared = EchoDelayedReplyNotificationScheduler()
    static let notificationIdentifier = "dj.echo.delayedReply"

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void)
    func schedule(_ delayedReply: EchoDelayedReply, completion: ((Error?) -> Void)?)
    func cancelPendingDelayedReply()
}
```

Notification body:

```text
回信到了，回来听听这段回响。
```

- [ ] **Step 3: Wire scheduler from waiting transition**

When `EchoViewController` detects `viewModel.isWaitingForDelayedReply`, request permission and schedule local notification. Do not block the in-app waiting state if permission is denied.

- [ ] **Step 4: Add UIQA launch arg for notification smoke**

In `AppDelegate`, add a simulator-only launch arg:

```text
DJRunEchoDelayedReplyNotificationSmoke
```

It should write JSON with:

```json
{
  "completed": true,
  "delayMinutesInRange": true,
  "storedDelayedReply": true,
  "localNotificationContractPresent": true
}
```

- [ ] **Step 5: Run checks**

```bash
swift Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260618-echo-delayed-reply-notification Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

- [ ] **Step 6: Commit**

```bash
git add DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift DreamJourney/Sources/Modules/Echo/EchoViewController.swift DreamJourney/Sources/AppDelegate.swift Scripts/QA/prd-stitch-ui/echo-delayed-reply-notification-check.swift
git commit -m "feat: schedule Echo delayed reply notifications"
```

### Task 1.3: Define Push Notification Backend Contract

**Files:**

- Modify: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Create: `Scripts/QA/prd-stitch-ui/echo-delayed-reply-push-contract-check.swift`
- Update: `docs/superpowers/status/2026-06-18-echo-waiting-reply-policy.md`

- [ ] **Step 1: Add failing guard**

Require backend client method:

```swift
assertContains(client, "func scheduleEchoDelayedReplyPush", "Backend client should expose Echo push scheduling contract")
assertContains(client, "/echo/delayed-replies", "Push scheduling should use explicit Echo delayed reply endpoint")
```

- [ ] **Step 2: Add backend-ready client method**

Add:

```swift
func scheduleEchoDelayedReplyPush(
    userId: String,
    delayedReply: EchoDelayedReply,
    completion: @escaping (Result<[String: Any], Error>) -> Void
) {
    let payload: [String: Any] = [
        "userId": userId,
        "delayedReplyId": delayedReply.id,
        "deliverAt": ISO8601DateFormatter().string(from: delayedReply.deliverAt),
        "minutes": delayedReply.minutes,
        "trigger": delayedReply.trigger.rawValue
    ]
    requestJSON(path: "/echo/delayed-replies", method: .post, payload: payload, completion: completion)
}
```

Do not fail the in-app state when this request fails; record fallback status in local smoke evidence.

- [ ] **Step 3: Update docs**

State that push is backend-ready but production APNs/device token validation remains a true-device/backend acceptance gate.

- [ ] **Step 4: Validate**

```bash
swift Scripts/QA/prd-stitch-ui/echo-delayed-reply-push-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
```

- [ ] **Step 5: Commit**

```bash
git add DreamJourney/Sources/Services/DreamJourneyBackendClient.swift Scripts/QA/prd-stitch-ui/echo-delayed-reply-push-contract-check.swift docs/superpowers/status/2026-06-18-echo-waiting-reply-policy.md
git commit -m "feat: add Echo delayed reply push contract"
```

---

## Phase 2: Account Profile Completion

Priority: P0.

Product basis:

- 个人资料只面向用户本人，是账户资料，不是数字人人格资料。
- 头像代表用户头像。
- 完整账号中心字段：头像、名称、性别、地区、手机号。
- App 内需要修改密码。

### Task 2.1: Expand Local Account Profile Model

**Files:**

- Modify: `DreamJourney/Sources/Services/MemoryModel.swift`
- Modify: `DreamJourney/Sources/Services/UserManager.swift`
- Test: `Scripts/QA/prd-stitch-ui/profile-account-fields-check.swift`

- [ ] **Step 1: Write failing guard**

Require fields:

```swift
assertContains(userModel, "var gender: String?", "UserModel should store gender")
assertContains(userModel, "var region: String?", "UserModel should store region")
assertContains(userModel, "var avatarName: String?", "UserModel should keep avatar display")
assertContains(userManager, "saveProfile(nickname: String, gender: String?, region: String?", "UserManager should save full account profile fields")
```

- [ ] **Step 2: Update model and migration**

Keep backward compatibility with existing encoded users. Optional fields must decode from old local data without failure.

- [ ] **Step 3: Update `UserManager.saveProfile`**

Preserve existing nickname validation, add gender/region persistence, and keep backend fallback behavior.

- [ ] **Step 4: Validate**

```bash
swift Scripts/QA/prd-stitch-ui/profile-account-fields-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-settings-save-state-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

- [ ] **Step 5: Commit**

```bash
git add DreamJourney/Sources/Services/UserManager.swift DreamJourney/Sources/Services/MemoryModel.swift Scripts/QA/prd-stitch-ui/profile-account-fields-check.swift
git commit -m "feat: persist full account profile fields"
```

### Task 2.2: Update Profile Settings UI

**Files:**

- Modify: `DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift`
- Test: `Scripts/QA/prd-stitch-ui/profile-account-fields-check.swift`

- [ ] **Step 1: Extend guard**

Require visible field labels and accessibility identifiers:

```swift
assertContains(profileSettings, "名称", "Profile settings should expose name field")
assertContains(profileSettings, "性别", "Profile settings should expose gender field")
assertContains(profileSettings, "地区", "Profile settings should expose region field")
assertContains(profileSettings, "profile-settings-gender-field", "Gender field should be stable for QA")
assertContains(profileSettings, "profile-settings-region-field", "Region field should be stable for QA")
```

- [ ] **Step 2: Add fields**

Add rows under existing nickname/phone card:

```text
昵称 / 名称
性别
地区
手机号（只读脱敏）
```

Keep phone read-only unless backend/auth contract explicitly supports phone change.

- [ ] **Step 3: Add validation**

Rules:

```text
名称不能为空，最多 24 个字。
性别可为空；非空时只允许 男 / 女 / 不便透露。
地区可为空；非空最多 32 个字。
```

- [ ] **Step 4: Simulator screenshot**

Launch profile settings UIQA path and save:

```text
tmp/visual-qa/prd-stitch-ui/profile-account-fields/<run-id>/01-profile-account-fields.png
```

- [ ] **Step 5: Validate and commit**

```bash
swift Scripts/QA/prd-stitch-ui/profile-account-fields-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260618-profile-account-fields Scripts/QA/prd-stitch-ui/run-release-regression.sh
git add DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift Scripts/QA/prd-stitch-ui/profile-account-fields-check.swift
git commit -m "feat: expose account profile fields"
```

### Task 2.3: Add Password Change Shell With Backend Contract

**Files:**

- Create: `DreamJourney/Sources/Modules/Profile/ProfilePasswordChangeViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift`
- Modify: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Test: `Scripts/QA/prd-stitch-ui/profile-password-change-check.swift`

- [ ] **Step 1: Add failing guard**

Require page and client method:

```swift
assertContains(passwordVC, "ProfilePasswordChangeViewController", "Password change page should exist")
assertContains(client, "func changePassword", "Backend client should expose password change contract")
assertContains(profileSettings, "修改密码", "Profile settings should expose password change entry")
```

- [ ] **Step 2: Add backend client method**

Add:

```swift
func changePassword(
    userId: String,
    oldPassword: String,
    newPassword: String,
    completion: @escaping (Result<[String: Any], Error>) -> Void
) {
    requestJSON(
        path: "/auth/password",
        method: .post,
        payload: ["userId": userId, "oldPassword": oldPassword, "newPassword": newPassword],
        completion: completion
    )
}
```

- [ ] **Step 3: Build UI**

Fields:

```text
当前密码
新密码
确认新密码
```

Validation:

```text
当前密码不能为空。
新密码至少 8 位。
确认新密码必须一致。
后端未配置时显示“当前环境暂不支持修改密码”，不假装成功。
```

- [ ] **Step 4: Verify**

```bash
swift Scripts/QA/prd-stitch-ui/profile-password-change-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/profile-password-change/DerivedData CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 5: Commit**

```bash
git add DreamJourney/Sources/Modules/Profile/ProfilePasswordChangeViewController.swift DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift DreamJourney/Sources/Services/DreamJourneyBackendClient.swift Scripts/QA/prd-stitch-ui/profile-password-change-check.swift
git commit -m "feat: add account password change flow"
```

---

## Phase 3: Archive Text/Photo Production Readiness

Priority: P0.

Product basis:

- 切到家庭数字人后，所有客户端档案页面内容一致。
- 谁上传谁拥有该条记忆的管理权限。
- 第一阶段媒体分析为后端 + AI 辅助，AI 为主；免责声明需要提示后端辅助。

### Task 3.1: Add Archive Ownership Metadata

**Files:**

- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- Test: `Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift`

- [ ] **Step 1: Add failing guard**

Require:

```swift
assertContains(item, "ownerUserId: String", "Archive item should store uploader ownership")
assertContains(item, "canManage(by userId: String)", "Archive item should enforce management ownership")
assertContains(factory, "ownerUserId", "Archive factory should assign uploader ownership")
```

- [ ] **Step 2: Implement ownership**

New and migrated archive items must have `ownerUserId`. For existing local items, use current logged-in user ID when migration occurs.

- [ ] **Step 3: Protect management actions**

Only show edit/delete management affordances when:

```swift
item.canManage(by: UserManager.shared.currentUser?.id ?? "")
```

- [ ] **Step 4: Validate and commit**

```bash
swift Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260618-archive-ownership Scripts/QA/prd-stitch-ui/run-release-regression.sh
git add DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift
git commit -m "feat: track archive item ownership"
```

### Task 3.2: Add Family Digital-Human Archive Visibility Contract

**Files:**

- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- Modify: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Test: `Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift`

- [ ] **Step 1: Add backend payload fields**

Archive item payloads should include:

```json
{
  "ownerUserId": "user_9999",
  "personaScope": "family",
  "digitalHumanId": "family_default"
}
```

- [ ] **Step 2: Add guard for shared visibility**

Require code strings:

```swift
assertContains(repository, "digitalHumanId", "Archive sync should scope items by digital human")
assertContains(repository, "personaScope", "Archive sync should distinguish personal/family visibility")
```

- [ ] **Step 3: Keep default public UI stable**

Do not add a new tab. Family digital-human context remains internal/profile-scoped until family management is promoted.

- [ ] **Step 4: Validate and commit**

```bash
swift Scripts/QA/prd-stitch-ui/archive-ownership-visibility-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
git commit -m "feat: add archive family visibility contract"
```

### Task 3.3: Add Backend+AI Analysis Disclaimer

**Files:**

- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- Test: `Scripts/QA/prd-stitch-ui/archive-analysis-disclaimer-check.swift`

- [ ] **Step 1: Add failing guard**

Require disclaimer text:

```swift
assertContains(detail, "AI 分析为主，后端辅助处理", "Archive detail should disclose backend + AI assisted analysis")
assertContains(archive, "不会人为查看你的记忆内容", "Archive public copy should clarify privacy boundary")
```

- [ ] **Step 2: Add copy near analysis state**

Use concise public copy:

```text
AI 分析为主，后端辅助处理；我们不会人为查看你的记忆内容。
```

- [ ] **Step 3: Screenshot**

Save:

```text
tmp/visual-qa/prd-stitch-ui/archive-analysis-disclaimer/<run-id>/01-archive-analysis-disclaimer.png
```

- [ ] **Step 4: Validate and commit**

```bash
swift Scripts/QA/prd-stitch-ui/archive-analysis-disclaimer-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260618-archive-analysis-disclaimer Scripts/QA/prd-stitch-ui/run-release-regression.sh
git commit -m "feat: disclose archive analysis assistance"
```

---

## Phase 4: Care Dashboard MVP Hardening

Priority: P1.

Product basis:

- 指标和阈值待后续输入，但当前要预留功能。
- 自己可见；原则上子女及父母可见；此外不可见；通过用户二次确认添加。
- 子女可看聚合信号和趋势解释。
- 医生联系 / 干预升级 MVP 需要功能实现或占位，但验证到一阶段完整发布。

### Task 4.1: Add Care Data State Contract

**Files:**

- Modify: `DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileElderCareDashboardViewController.swift`
- Test: `Scripts/QA/prd-stitch-ui/profile-care-public-placeholder-check.swift`

- [ ] **Step 1: Add failing guard**

Require states:

```swift
assertContains(careModels, "enum ProfileCareDataState", "Care dashboard should model data states")
assertContains(careModels, "case loading", "Care dashboard should support loading")
assertContains(careModels, "case empty", "Care dashboard should support empty")
assertContains(careModels, "case stale", "Care dashboard should support stale")
assertContains(careModels, "case failed", "Care dashboard should support failed")
```

- [ ] **Step 2: Implement state rendering**

Render:

```text
正在同步关怀信号
暂无可用关怀信号
数据可能不是最新
关怀信号加载失败
```

- [ ] **Step 3: Validate and commit**

```bash
swift Scripts/QA/prd-stitch-ui/profile-care-public-placeholder-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git commit -m "feat: add care dashboard data states"
```

### Task 4.2: Promote Non-Executing Intervention Placeholder

**Files:**

- Modify: `DreamJourney/Sources/Modules/Profile/ProfileElderCareDashboardViewController.swift`
- Modify: `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- Test: `Scripts/QA/prd-stitch-ui/profile-care-public-placeholder-check.swift`

- [ ] **Step 1: Add guard**

Require public placeholder copy but no real call:

```swift
assertContains(careDashboard, "关怀升级准备中", "Care dashboard should expose MVP placeholder")
assertContains(careDashboard, "不会拨打电话或发送消息", "Placeholder must not imply real intervention")
assertNotContains(careDashboard, "立即通话", "Public care placeholder must not expose direct call")
```

- [ ] **Step 2: Add visible placeholder**

Show a disabled/actionless care escalation card:

```text
关怀升级准备中
当前仅提供聚合信号与趋势解释，不会拨打电话或发送消息。
```

Keep `careDoctorContact` hidden for real contact.

- [ ] **Step 3: Validate and commit**

```bash
swift Scripts/QA/prd-stitch-ui/profile-care-public-placeholder-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260618-care-placeholder Scripts/QA/prd-stitch-ui/run-release-regression.sh
git commit -m "feat: add care intervention placeholder"
```

---

## Phase 5: Backend And Release Gates

Priority: P1.

### Task 5.1: Align Backend Contract Matrix

**Files:**

- Modify: `docs/superpowers/status/2026-06-18-prd-coverage-matrix.md`
- Create: `docs/superpowers/status/2026-06-18-backend-contract-gap-matrix.md`
- Create: `Scripts/QA/prd-stitch-ui/backend-contract-gap-check.swift`

- [ ] **Step 1: Add matrix rows**

Rows:

```text
Echo delayed reply push -> /echo/delayed-replies -> backend/API token/APNs needed
Profile update -> /profile -> backend needed or /auth/login fallback
Password change -> /auth/password -> backend/security needed
Archive ownership -> /archive/items -> backend field migration needed
Care snapshot states -> /care/snapshots/latest/{userId} -> backend accepted, state variants needed
```

- [ ] **Step 2: Add static guard**

Require each endpoint string and each state in the matrix.

- [ ] **Step 3: Validate**

```bash
swift Scripts/QA/prd-stitch-ui/backend-contract-gap-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260618-backend-contract-gap Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

- [ ] **Step 4: Commit**

```bash
git commit -m "docs: add backend contract gap matrix"
```

### Task 5.2: Add Release Handoff Enforcement For New PRD Gates

**Files:**

- Modify: `Scripts/QA/prd-stitch-ui/run-release-regression.sh`
- Modify: `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- Modify: `docs/superpowers/status/2026-06-18-one-command-release-regression.md`

- [ ] **Step 1: Update release handoff mode**

When `RELEASE_HANDOFF_MODE=1`, require:

```text
PRD decision guard
Echo notification guard
Profile account fields guard
Archive ownership guard
Care placeholder guard
Release-like backend acceptance
```

- [ ] **Step 2: Validate**

```bash
RELEASE_HANDOFF_MODE=1 RUN_STANDARD_BUILD=1 RUN_SIMULATOR_SMOKE=1 RUN_ID=20260618-new-prd-release-handoff Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

- [ ] **Step 3: Commit**

```bash
git commit -m "test: enforce new PRD release handoff gates"
```

---

## Phase 6: Hidden Candidate Promotion Decisions

Priority: P2 until product explicitly promotes one candidate.

Do not open these by default in the public app during Phases 1-5:

- 语音档案 / 档案录音
- 时间信件
- 档案视频
- 人格设定
- 家人管理
- 账号注销执行
- 医生联系 / 干预执行
- 关怀升级草稿发送
- 阳光 / 星辰 / 静默生命周期切换
- 数字人继承生命周期
- Echo 文字 / 图片输入

Promotion order when product decides:

1. 语音档案：lowest conceptual risk, but needs true-device microphone acceptance.
2. 时间信件：needs delivery/scheduling/notification policy.
3. 家人管理：needs backend membership and consent.
4. 视频档案：needs storage/compression/backend policy.
5. 账号注销、医生联系、数字人继承：highest legal/compliance risk; keep blocked until contract is explicit.

Each promotion must include:

```text
feature flag decision
Stitch/htmlCode visual alignment
backend contract
static guard
simulator smoke
release regression
true-device acceptance when permission/media/notification is involved
```

---

## Recommended Execution Order

1. Phase 1 Task 1.1: Persist Echo delayed reply state.
2. Phase 1 Task 1.2: Schedule local notification.
3. Phase 1 Task 1.3: Add push backend contract.
4. Phase 2 Task 2.1: Expand local account profile model.
5. Phase 2 Task 2.2: Update profile settings UI.
6. Phase 2 Task 2.3: Add password change shell and backend contract.
7. Phase 3 Task 3.1: Add archive ownership metadata.
8. Phase 3 Task 3.2: Add family digital-human archive visibility contract.
9. Phase 3 Task 3.3: Add backend+AI analysis disclaimer.
10. Phase 4 Task 4.1: Add care data states.
11. Phase 4 Task 4.2: Promote non-executing intervention placeholder.
12. Phase 5 Task 5.1: Align backend contract matrix.
13. Phase 5 Task 5.2: Add release handoff enforcement.

## Required Verification Before Each Commit

Run at least:

```bash
git diff --check
swift Scripts/QA/prd-stitch-ui/prd-full-feature-closure-decisions-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/prd-coverage-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

For code changes, also run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/<run-id>/DerivedData CODE_SIGNING_ALLOWED=NO build
```

For UI changes, also run a simulator smoke and save screenshot:

```bash
RUN_ID=<run-id> Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

For backend-contract changes, run:

```bash
RUN_ID=<run-id> RELEASE_HANDOFF_MODE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## Completion Criteria

This plan is complete when:

1. Echo wait state survives app restart and has local notification plus backend-ready push contract.
2. Profile settings covers avatar display, name, gender, region, phone, and password change.
3. Archive text/photo items have ownership, family digital-human visibility contract, backend persistence, and AI/backend assistance disclosure.
4. Care dashboard has loading/empty/stale/failure states and visible non-executing escalation placeholder.
5. Release handoff mode enforces all new PRD guards.
6. No hidden PRD candidate is exposed in default release mode unless separately promoted by product decision.
7. Release regression passes.
8. True-device acceptance checklist is ready for microphone, photo library, notification permission, and signing.
