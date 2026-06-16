# PRD Stitch UI Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adapt the existing UIKit iOS app to the current Stitch UI and the updated DreamJourney PRD V1.0 MVP: `记忆档案 / 回响 / 我的`.

**Architecture:** Keep the existing UIKit app and reusable voice, memory, KBLite, and family services, but replace the current main information architecture with a new PRD-aligned shell. Add a small design system, a unified DreamJourney backend client, and feature-scoped view models so the UI can follow Stitch without hard-coding business logic into view controllers.

**Tech Stack:** Swift 5, UIKit, Auto Layout, Alamofire, CocoaPods, Xcode workspace `DreamJourney.xcworkspace`, existing `DialogEngineManager`, `ConversationMemoryManager`, `KBLiteManager`, and `MemoryRepository`.

---

## Source Of Truth

- Visual target: current Stitch canvas first, Stitch `htmlCode` second.
- Do not use MCP screenshots as final visual authority when they conflict with the current Stitch canvas.
- Product target: updated `《寻梦环游 产品PRD V1.0》(1).md`.
- Code target: `DreamJourney_dev` on branch `feature/prd-stitch-ui-adaptation`.

## Current State

- Current branch: `feature/prd-stitch-ui-adaptation`.
- Dirty files already existed before this plan:
  - `DreamJourney.xcodeproj/project.pbxproj`
  - `DreamJourney/Resources/Info.plist`
- Current app shell: `回忆 / 足迹 / 亲友 / 知识`.
- Target app shell: `记忆档案 / 回响 / 我的`.
- Current UI layer is UIKit, so Stitch HTML is a reference, not importable runtime code.

## Scope

This plan targets a shippable PRD MVP, not the full future product.

Included:

- Login screen restyle to current Stitch login.
- New 3-tab shell.
- `回响` screen with voice-first interaction and hidden internal mode state.
- `记忆档案馆` screen with upload/material/persona-progress structure.
- `我的` screen with profile settings, family management entry, legal entry, logout, account deletion entry, and care dashboard card.
- Unified DreamJourney backend client for `/archive`, `/kb`, `/family`, and `/care`.
- Feature flags to hide unfinished second-level features while keeping routes compiled.

Excluded from this plan:

- Real digital-human 3D rendering.
- Full voice clone training pipeline.
- Payment, subscriptions, B-end institution workflows.
- Full second-stage family space.
- Medical diagnosis or self-harm intervention automation beyond safe wording and emergency guidance surfaces.

## File Structure

Create:

- `DreamJourney/Sources/DesignSystem/DJDesignTokens.swift`  
  Central colors, typography, spacing, radii, shadow helpers, and Stitch-to-UIKit token mapping.
- `DreamJourney/Sources/DesignSystem/DJComponentFactory.swift`  
  Shared button, card, pill, input, and icon helpers.
- `DreamJourney/Sources/App/FeatureFlagService.swift`  
  Local feature availability for unfinished functions.
- `DreamJourney/Sources/App/DigitalHumanContextStore.swift`  
  Current selected persona, owner, and internal mode state.
- `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`  
  Typed Alamofire client for the existing backend endpoints.
- `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`  
  Stitch-aligned `回响` page.
- `DreamJourney/Sources/Modules/Echo/EchoViewModel.swift`  
  Voice interaction, waiting-reply state, and persona context adapter.
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift`  
  Archive material model aligned with PRD.
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`  
  Local archive storage and KBLite bridge.
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`  
  Stitch-aligned `记忆档案馆` page.
- `DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift`  
  UI-facing care snapshot models.
- `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`  
  Stitch-aligned `我的 / 长辈关怀` page.

Modify:

- `DreamJourney/Sources/App/TabCoordinator.swift`  
  Replace current four-tab composition with target three-tab composition.
- `DreamJourney/Sources/TabBar/WarmTabBarController.swift`  
  Make tab items injectable and update labels/icons.
- `DreamJourney/Sources/Modules/Auth/LoginViewController.swift`  
  Restyle to Stitch login without changing login callback behavior.
- `DreamJourney/Resources/Info.plist`  
  Add `DreamJourneyBackendBaseURL`.
- `DreamJourney.xcodeproj/project.pbxproj`  
  Add new Swift files to the app target if Xcode does not pick them up automatically.

Keep as reusable internals:

- `DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift`
- `DreamJourney/Sources/Services/DialogEngineManager.swift`
- `DreamJourney/Sources/Services/ConversationMemoryManager.swift`
- `DreamJourney/Sources/Services/KBLiteManager.swift`
- `DreamJourney/Sources/Services/MemoryRepository.swift`
- `DreamJourney/Sources/Services/FamilyRepository.swift`

---

### Task 1: Baseline Verification And Branch Guard

**Files:**
- Read: `DreamJourney.xcworkspace`
- Read: `DreamJourney/Resources/Info.plist`
- Read: `DreamJourney/Sources/App/TabCoordinator.swift`

- [ ] **Step 1: Confirm branch and dirty files**

Run:

```bash
git branch --show-current
git status --short
```

Expected:

```text
feature/prd-stitch-ui-adaptation
 M DreamJourney.xcodeproj/project.pbxproj
 M DreamJourney/Resources/Info.plist
```

- [ ] **Step 2: Confirm the workspace scheme**

Run:

```bash
xcodebuild -list -workspace DreamJourney.xcworkspace
```

Expected includes:

```text
Schemes:
    DreamJourney
    DreamJourneyWidget
```

- [ ] **Step 3: Run compile baseline**

Run:

```bash
xcodebuild \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build
```

Expected: build succeeds. If it fails before feature work starts, record the first compiler error and decide whether to fix baseline first or continue with known failures.

- [ ] **Step 4: Commit nothing**

Do not commit pre-existing dirty `project.pbxproj` or `Info.plist` changes unless they are confirmed to belong to this branch's work.

---

### Task 2: Add Design Tokens And Shared UI Helpers

**Files:**
- Create: `DreamJourney/Sources/DesignSystem/DJDesignTokens.swift`
- Create: `DreamJourney/Sources/DesignSystem/DJComponentFactory.swift`
- Modify if needed: `DreamJourney.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create `DJDesignTokens.swift`**

Implement the Stitch palette and sizing primitives:

```swift
import UIKit

enum DJDesignTokens {
    enum Color {
        static let background = UIColor(hex: "#fff9f0")
        static let surface = UIColor(hex: "#ffffff")
        static let surfaceLow = UIColor(hex: "#f9f3ea")
        static let surfaceContainer = UIColor(hex: "#f3ede4")
        static let textPrimary = UIColor(hex: "#1d1b16")
        static let textSecondary = UIColor(hex: "#564334")
        static let textTertiary = UIColor(hex: "#897362")
        static let accent = UIColor(hex: "#ff8c00")
        static let accentDeep = UIColor(hex: "#904d00")
        static let divider = UIColor(hex: "#ddc1ae")
        static let danger = UIColor(hex: "#ba1a1a")
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let unit: CGFloat = 8
        static let page: CGFloat = 24
        static let card: CGFloat = 16
        static let section: CGFloat = 32
        static let tabBarHeight: CGFloat = 64
    }

    enum Font {
        static func display(_ size: CGFloat = 28) -> UIFont {
            .systemFont(ofSize: size, weight: .light)
        }

        static func title(_ size: CGFloat = 20) -> UIFont {
            .systemFont(ofSize: size, weight: .semibold)
        }

        static func body(_ size: CGFloat = 15) -> UIFont {
            .systemFont(ofSize: size, weight: .regular)
        }

        static func label(_ size: CGFloat = 12) -> UIFont {
            .systemFont(ofSize: size, weight: .semibold)
        }
    }

    static func applySoftShadow(to view: UIView) {
        view.layer.shadowColor = UIColor(hex: "#8C7B6D").cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.layer.shadowRadius = 24
    }
}
```

- [ ] **Step 2: Create `DJComponentFactory.swift`**

Add shared UIKit helpers:

```swift
import UIKit

enum DJComponentFactory {
    static func cardView(radius: CGFloat = DJDesignTokens.Radius.large) -> UIView {
        let view = UIView()
        view.backgroundColor = DJDesignTokens.Color.surface
        view.layer.cornerRadius = radius
        view.layer.masksToBounds = false
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }

    static func primaryButton(title: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(15)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = DJDesignTokens.Color.accent
        button.layer.cornerRadius = 22
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }

    static func iconButton(systemName: String, target: Any?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = DJDesignTokens.Color.textSecondary
        button.backgroundColor = DJDesignTokens.Color.surfaceLow
        button.layer.cornerRadius = 22
        button.addTarget(target, action: action, for: .touchUpInside)
        return button
    }

    static func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DJDesignTokens.Font.title(18)
        label.textColor = DJDesignTokens.Color.textPrimary
        return label
    }
}
```

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add DreamJourney/Sources/DesignSystem DreamJourney.xcodeproj/project.pbxproj
git commit -m "feat: add dreamjourney design tokens"
```

---

### Task 3: Add Feature Flags And Persona Context

**Files:**
- Create: `DreamJourney/Sources/App/FeatureFlagService.swift`
- Create: `DreamJourney/Sources/App/DigitalHumanContextStore.swift`

- [ ] **Step 1: Create feature flags**

```swift
import Foundation

enum DJFeature: String {
    case echoTextInput
    case echoImageInput
    case timeLetters
    case familyManagement
    case legalCenter
    case accountDeletion
    case careDashboard
}

final class FeatureFlagService {
    static let shared = FeatureFlagService()

    private var enabled: Set<DJFeature> = [
        .familyManagement,
        .legalCenter,
        .careDashboard
    ]

    private init() {}

    func isEnabled(_ feature: DJFeature) -> Bool {
        enabled.contains(feature)
    }

    func set(_ feature: DJFeature, enabled isEnabled: Bool) {
        if isEnabled {
            enabled.insert(feature)
        } else {
            enabled.remove(feature)
        }
    }
}
```

- [ ] **Step 2: Create persona context store**

```swift
import Foundation

enum DigitalHumanMode: String, Codable {
    case sunlight
    case star
    case silent
}

struct DigitalHumanContext: Codable {
    var ownerId: String
    var displayName: String
    var relation: String?
    var mode: DigitalHumanMode
    var isSelfAssistant: Bool

    static func defaultContext(userId: String) -> DigitalHumanContext {
        DigitalHumanContext(
            ownerId: userId,
            displayName: "外面世界很美好",
            relation: nil,
            mode: .sunlight,
            isSelfAssistant: false
        )
    }
}

final class DigitalHumanContextStore {
    static let shared = DigitalHumanContextStore()

    private let key = "dj.digitalHuman.currentContext"

    private init() {}

    var current: DigitalHumanContext {
        get {
            if let data = UserDefaults.standard.data(forKey: key),
               let context = try? JSONDecoder().decode(DigitalHumanContext.self, from: data) {
                return context
            }
            let userId = UserManager.shared.currentUser?.id ?? "user_001"
            return .defaultContext(userId: userId)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}
```

- [ ] **Step 3: Verify the mode is not shown in UI**

Add no visible label that says `阳光模式`, `星辰模式`, or `静默模式` on `回响`. This context exists for behavior and settings only.

- [ ] **Step 4: Build and commit**

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
git add DreamJourney/Sources/App/FeatureFlagService.swift DreamJourney/Sources/App/DigitalHumanContextStore.swift DreamJourney.xcodeproj/project.pbxproj
git commit -m "feat: add prd feature flags and persona context"
```

---

### Task 4: Add DreamJourney Backend Client

**Files:**
- Create: `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift`
- Modify: `DreamJourney/Resources/Info.plist`

- [ ] **Step 1: Add `DreamJourneyBackendBaseURL`**

Add this key to `DreamJourney/Resources/Info.plist`:

```xml
<key>DreamJourneyBackendBaseURL</key>
<string>http://127.0.0.1:3100</string>
```

- [ ] **Step 2: Create backend client**

```swift
import Foundation
import Alamofire

final class DreamJourneyBackendClient {
    static let shared = DreamJourneyBackendClient()

    private let baseURL: String

    private init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "DreamJourneyBackendBaseURL") as? String
        let raw = configured?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = (raw?.isEmpty == false ? raw! : "http://127.0.0.1:3100").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func postArchiveItem(_ payload: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/archive/items", method: .post, payload: payload, completion: completion)
    }

    func listArchiveItems(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/archive/items/\(userId)", method: .get, payload: nil, completion: completion)
    }

    func syncKnowledge(userId: String, graph: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/kb/sync", method: .post, payload: ["userId": userId, "graph": graph], completion: completion)
    }

    func listFamilyMembers(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/family/members/\(userId)", method: .get, payload: nil, completion: completion)
    }

    func latestCareSnapshot(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/care/snapshots/latest/\(userId)", method: .get, payload: nil, completion: completion)
    }

    private func requestJSON(
        path: String,
        method: HTTPMethod,
        payload: [String: Any]?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let url = "\(baseURL)\(path)"
        AF.request(url, method: method, parameters: payload, encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .responseData(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success(let data):
                    let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                    DispatchQueue.main.async {
                        completion(.success(object ?? [:]))
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
    }
}
```

- [ ] **Step 3: Build and commit**

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
git add DreamJourney/Sources/Services/DreamJourneyBackendClient.swift DreamJourney/Resources/Info.plist DreamJourney.xcodeproj/project.pbxproj
git commit -m "feat: add dreamjourney backend client"
```

---

### Task 5: Make Warm Tab Bar Injectable And Switch To Three Tabs

**Files:**
- Modify: `DreamJourney/Sources/TabBar/WarmTabBarController.swift`
- Modify: `DreamJourney/Sources/App/TabCoordinator.swift`

- [ ] **Step 1: Make `WarmTabBarView` accept items**

Change `WarmTabBarView` from a hard-coded item list to an initializer-backed list:

```swift
final class WarmTabBarView: UIView {
    static let tabBarHeight: CGFloat = 64

    struct TabItem {
        let iconName: String
        let iconNameFill: String
        let title: String
    }

    private let items: [TabItem]

    init(items: [TabItem]) {
        self.items = items
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }
}
```

Update `WarmTabBarController` to create:

```swift
private let warmTabBar = WarmTabBarView(items: [
    .init(iconName: "archivebox", iconNameFill: "archivebox.fill", title: "记忆档案"),
    .init(iconName: "mic", iconNameFill: "mic.fill", title: "回响"),
    .init(iconName: "person", iconNameFill: "person.fill", title: "我的")
])
```

- [ ] **Step 2: Update `TabCoordinator` target composition**

Use the new pages:

```swift
private func setupTabs() {
    let archiveNav = UINavigationController()
    archiveNav.viewControllers = [MemoryArchiveViewController()]
    archiveNav.navigationBar.tintColor = DJDesignTokens.Color.textPrimary

    let echoNav = UINavigationController()
    echoNav.viewControllers = [EchoViewController()]
    echoNav.navigationBar.tintColor = DJDesignTokens.Color.textPrimary

    let profileNav = UINavigationController()
    let profileVC = ProfileViewController()
    profileVC.didRequestLogout = { [weak self] in
        self?.didRequestLogout?()
    }
    profileNav.viewControllers = [profileVC]
    profileNav.navigationBar.tintColor = DJDesignTokens.Color.textPrimary

    tabBarController.viewControllers = [archiveNav, echoNav, profileNav]
    tabBarController.selectedIndex = 1
}
```

- [ ] **Step 3: Build**

This task will not compile until placeholder page classes exist. If Task 6, Task 7, and Task 8 are not started yet, create temporary empty classes with final UI names:

```swift
final class EchoViewController: UIViewController {}
final class MemoryArchiveViewController: UIViewController {}
final class ProfileViewController: UIViewController {
    var didRequestLogout: (() -> Void)?
}
```

Remove temporary empty classes when the real page files are implemented.

- [ ] **Step 4: Commit after real pages compile**

```bash
git add DreamJourney/Sources/TabBar/WarmTabBarController.swift DreamJourney/Sources/App/TabCoordinator.swift DreamJourney.xcodeproj/project.pbxproj
git commit -m "feat: switch app shell to prd tabs"
```

---

### Task 6: Implement `回响` Page

**Files:**
- Create: `DreamJourney/Sources/Modules/Echo/EchoViewModel.swift`
- Create: `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- Reuse: `DreamJourney/Sources/Services/DialogEngineManager.swift`
- Reuse: `DreamJourney/Sources/Services/ConversationMemoryManager.swift`

- [ ] **Step 1: Create view model state**

```swift
import Foundation

enum EchoInteractionState {
    case idle
    case listening
    case waitingReply(minutes: Int)
    case speaking
    case error(String)
}

final class EchoViewModel {
    private(set) var context: DigitalHumanContext
    private(set) var state: EchoInteractionState = .idle

    var onStateChange: ((EchoInteractionState) -> Void)?
    var onTranscriptAppend: ((String, Bool) -> Void)?

    init(contextStore: DigitalHumanContextStore = .shared) {
        self.context = contextStore.current
    }

    func beginVoiceInteraction() {
        state = .listening
        onStateChange?(state)
    }

    func finishUserVoice(text: String) {
        ConversationMemoryManager.shared.recordUserTurn(text: text)
        onTranscriptAppend?(text, true)

        let wait = Self.replyDelayMinutes(for: ConversationMemoryManager.shared.currentMemory.sessionCount)
        state = .waitingReply(minutes: wait)
        onStateChange?(state)
    }

    func receiveAIReply(_ text: String) {
        ConversationMemoryManager.shared.recordAITurn(text: text)
        onTranscriptAppend?(text, false)
        state = .speaking
        onStateChange?(state)
    }

    private static func replyDelayMinutes(for sessionCount: Int) -> Int {
        let options = [5, 10, 30]
        return options[max(0, sessionCount) % options.count]
    }
}
```

- [ ] **Step 2: Create page structure**

`EchoViewController` should include:

- full-screen warm background
- park image area
- short quote bubble
- central mic button
- bottom tab safe spacing
- no visible `阳光模式`, `星辰模式`, or `静默模式` label
- waiting state text such as `回信会晚一点抵达`

- [ ] **Step 3: Reuse voice engine through an adapter**

Move only the voice start/stop calls needed from `AIRecordingViewController` into private methods on `EchoViewController`. Keep `AIRecordingViewController` intact until `Echo` is verified.

- [ ] **Step 4: Build and verify strings**

Run:

```bash
rg -n "阳光模式|星辰模式|静默模式" DreamJourney/Sources/Modules/Echo
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

Expected:

- `rg` exits with no matches in visible UI files.
- Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add DreamJourney/Sources/Modules/Echo DreamJourney.xcodeproj/project.pbxproj
git commit -m "feat: add voice-first echo screen"
```

---

### Task 7: Implement `记忆档案馆`

**Files:**
- Create: `DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift`
- Create: `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- Create: `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- Reuse: `DreamJourney/Sources/Services/KBLiteManager.swift`
- Reuse: `DreamJourney/Sources/Memoir/DeepSeekService.swift`

- [ ] **Step 1: Create archive model**

```swift
import Foundation

enum MemoryArchiveItemKind: String, Codable {
    case photo
    case video
    case audio
    case text
    case timeLetter
}

enum MemoryArchiveAnalysisStatus: String, Codable {
    case manual
    case pending
    case analyzed
    case failed
}

struct MemoryArchiveItem: Codable, Identifiable {
    let id: String
    var kind: MemoryArchiveItemKind
    var title: String
    var note: String
    var localPath: String?
    var createdAt: Date
    var updatedAt: Date
    var analysisStatus: MemoryArchiveAnalysisStatus
    var analysisSummary: String?
    var detectedPeople: [String]
    var tags: [String]

    init(kind: MemoryArchiveItemKind, title: String, note: String, localPath: String? = nil) {
        self.id = UUID().uuidString
        self.kind = kind
        self.title = title
        self.note = note
        self.localPath = localPath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.analysisStatus = .manual
        self.analysisSummary = nil
        self.detectedPeople = []
        self.tags = []
    }
}
```

- [ ] **Step 2: Create repository**

Use `UserDefaults` for MVP local persistence and call backend opportunistically:

```swift
import Foundation

final class MemoryArchiveRepository {
    static let shared = MemoryArchiveRepository()

    private let key = "dj.memoryArchive.items"

    private init() {}

    func allItems() -> [MemoryArchiveItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([MemoryArchiveItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ item: MemoryArchiveItem) {
        var items = allItems()
        items.insert(item, at: 0)
        save(items)
        syncToBackend(item)
    }

    func summary() -> (total: Int, photos: Int, audio: Int, text: Int) {
        let items = allItems()
        return (
            total: items.count,
            photos: items.filter { $0.kind == .photo }.count,
            audio: items.filter { $0.kind == .audio }.count,
            text: items.filter { $0.kind == .text || $0.kind == .timeLetter }.count
        )
    }

    private func save(_ items: [MemoryArchiveItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func syncToBackend(_ item: MemoryArchiveItem) {
        let userId = UserManager.shared.currentUser?.id ?? "user_001"
        DreamJourneyBackendClient.shared.postArchiveItem([
            "userId": userId,
            "id": item.id,
            "kind": item.kind.rawValue,
            "title": item.title,
            "note": item.note,
            "createdAt": ISO8601DateFormatter().string(from: item.createdAt)
        ]) { result in
            if case .failure(let error) = result {
                print("[Archive] backend sync failed: \(error.localizedDescription)")
            }
        }
    }
}
```

- [ ] **Step 3: Build the page**

`MemoryArchiveViewController` should show:

- title `记忆档案馆`
- subtitle `整理、回顾与珍藏那些不愿遗忘的片段`
- cards for `相册影像`, `语音档案`, `人格设定`
- primary CTA `封存新记忆`
- time capsule list section
- small progress copy that explains archive materials and conversations keep improving the digital persona

- [ ] **Step 4: Connect actions**

For MVP:

- `封存新记忆` opens an action sheet with `添加文字描述`, `选择照片`, `录入时间信件`.
- `添加文字描述` saves a `.text` archive item.
- `录入时间信件` saves a `.timeLetter` archive item.
- `选择照片` uses `UIImagePickerController`, saves local file path, then saves a `.photo` archive item.

- [ ] **Step 5: Build and commit**

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
git add DreamJourney/Sources/Modules/Archive DreamJourney.xcodeproj/project.pbxproj
git commit -m "feat: add memory archive mvp"
```

---

### Task 8: Implement `我的` And Care Dashboard Surface

**Files:**
- Create: `DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift`
- Create: `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- Reuse: `DreamJourney/Sources/Services/FamilyRepository.swift`

- [ ] **Step 1: Add care UI model**

```swift
import Foundation

struct ProfileCareSnapshot {
    var moodTitle: String
    var moodStatus: String
    var emotionalIndex: Double
    var cognitiveIndex: Double
    var sleepStatus: String
    var lonelinessIndex: Double
    var riskReminder: String

    static let sample = ProfileCareSnapshot(
        moodTitle: "心境追踪",
        moodStatus: "平稳",
        emotionalIndex: 0.78,
        cognitiveIndex: 0.82,
        sleepStatus: "规律",
        lonelinessIndex: 0.22,
        riskReminder: "建议今天电话问候一次"
    )
}
```

- [ ] **Step 2: Build `ProfileViewController`**

The visible sections should be:

- avatar/persona card with `外面世界很美好`
- care card titled `心境追踪`
- doctor row `李医生 / 立即通话`
- setting rows: `个人资料设置`, `家人管理`, `法律法规`, `退出登录`, `注销账户`
- bottom tab safe spacing

- [ ] **Step 3: Enforce privacy in UI copy**

Use visible copy that says the care dashboard shows status signals, not raw conversation:

```swift
private let privacyText = "仅展示关怀信号，不展示聊天原文"
```

Do not render raw transcript text from `ConversationMemoryManager` in `ProfileViewController`.

- [ ] **Step 4: Wire logout**

Expose:

```swift
var didRequestLogout: (() -> Void)?
```

Call it from the `退出登录` row.

- [ ] **Step 5: Build and commit**

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
git add DreamJourney/Sources/Modules/Profile DreamJourney.xcodeproj/project.pbxproj
git commit -m "feat: add profile and care dashboard surface"
```

---

### Task 9: Restyle Login To Stitch

**Files:**
- Modify: `DreamJourney/Sources/Modules/Auth/LoginViewController.swift`

- [ ] **Step 1: Preserve behavior**

Keep:

```swift
var didLogin: (() -> Void)?
@objc private func loginTapped()
```

Do not change `UserManager.shared.login(phone:nickname:)` behavior in this task.

- [ ] **Step 2: Update visible content**

Target visible text:

- `寻梦环游`
- `在时空中，留下你的身影`
- `手机号`
- `密码`
- `忘记密码？`
- `登录`
- `还没有账号？`
- `立即注册`

Use a password field only for UI parity. The MVP can keep phone-only login internally by allowing login when phone is valid.

- [ ] **Step 3: Build and commit**

```bash
rg -n "开始记录回忆|让梦想在这里交织成网|想要大家怎么称呼" DreamJourney/Sources/Modules/Auth/LoginViewController.swift
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
git add DreamJourney/Sources/Modules/Auth/LoginViewController.swift
git commit -m "feat: align login screen with stitch"
```

Expected:

- `rg` returns no old login copy.
- Build succeeds.

---

### Task 10: Hide Or Relocate Old Features

**Files:**
- Modify: `DreamJourney/Sources/App/TabCoordinator.swift`
- Modify: `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- Modify: `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`

- [ ] **Step 1: Keep old feature classes compiled**

Do not delete:

- `MapFootprintViewController`
- `FamilyCircleViewController`
- `KnowledgeBaseViewController`
- `AIRecordingViewController`

- [ ] **Step 2: Move old features to secondary routes**

Expose:

- `KnowledgeBaseViewController` from `记忆档案馆 -> 人格设定`
- `FamilyCircleViewController` from `我的 -> 家人管理`
- `MapFootprintViewController` behind feature flag `timeLetters` or a hidden debug entry

- [ ] **Step 3: Guard unfinished public features**

Use:

```swift
if FeatureFlagService.shared.isEnabled(.timeLetters) {
    // show the row
}
```

For disabled features, do not render visible rows that imply availability.

- [ ] **Step 4: Build and commit**

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
git add DreamJourney/Sources/App DreamJourney/Sources/Modules/Archive DreamJourney/Sources/Modules/Profile
git commit -m "feat: gate legacy routes behind prd shell"
```

---

### Task 11: Visual QA Against Stitch

**Files:**
- Inspect rendered app through simulator.
- Compare against current Stitch canvas and `htmlCode`.

- [ ] **Step 1: Build and run on simulator**

Run:

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build
```

If `iPhone 16` is unavailable, run:

```bash
xcrun simctl list devices available
```

Then choose an available iPhone simulator and rerun the build.

- [ ] **Step 2: Capture core screens**

Capture:

- login
- `记忆档案馆`
- `回响`
- `我的`

Use the available simulator screenshot tooling in the session. Save screenshots under:

```text
tmp/visual-qa/prd-stitch-ui/
```

- [ ] **Step 3: Check critical visual invariants**

Verify:

- Login page is light/cream, not black.
- No `往日记念` or `时光回响` entry appears.
- Bottom nav labels are exactly `记忆档案`, `回响`, `我的`.
- `回响` does not visibly show `阳光模式`, `星辰模式`, or `静默模式`.
- `回响` primary input is voice.
- `记忆档案馆` communicates material upload and persona improvement.
- `我的` does not show raw chat content in care sections.

- [ ] **Step 4: Commit visual fixes**

Commit fixes in small groups:

```bash
git add DreamJourney/Sources
git commit -m "fix: align prd screens with stitch visual target"
```

---

### Task 12: Final Verification

**Files:**
- Inspect all changed Swift files.
- Inspect `DreamJourney/Resources/Info.plist`.
- Inspect `DreamJourney.xcodeproj/project.pbxproj`.

- [ ] **Step 1: Run source hygiene checks**

```bash
git diff --check
plutil -lint DreamJourney/Resources/Info.plist
plutil -lint DreamJourney.xcodeproj/project.pbxproj
```

Expected:

```text
DreamJourney/Resources/Info.plist: OK
DreamJourney.xcodeproj/project.pbxproj: OK
```

- [ ] **Step 2: Run final build**

```bash
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

Expected: build succeeds.

- [ ] **Step 3: Confirm copy constraints**

```bash
rg -n "往日记念|时光回响|记念页面|阳光模式|星辰模式|静默模式" DreamJourney/Sources
```

Expected:

- No matches for `往日记念`, `时光回响`, or `记念页面`.
- Matches for `阳光模式`, `星辰模式`, `静默模式` are allowed only in internal model comments or non-visible logic files, not in `EchoViewController`.

- [ ] **Step 4: Summarize branch**

```bash
git status --short
git log --oneline --decorate -n 12
```

Expected:

- No unintended uncommitted files beyond user-approved local config.
- Recent commits follow the task boundaries above.

## Implementation Order

Recommended order:

1. Task 1 baseline.
2. Task 2 design system.
3. Task 3 feature flags and persona context.
4. Task 4 backend client.
5. Task 7 archive page.
6. Task 6 echo page.
7. Task 8 profile page.
8. Task 5 tab switch, once real page classes exist.
9. Task 9 login restyle.
10. Task 10 old feature relocation.
11. Task 11 visual QA.
12. Task 12 final verification.

The tab switch is intentionally delayed until the three target pages compile, so the app remains runnable during development.

## Known Risks

- `project.pbxproj` and `Info.plist` were already dirty before this plan. Review those diffs before committing task changes that touch the same files.
- Stitch UI may update again. Keep visual constants centralized in `DJDesignTokens.swift` so future changes stay localized.
- The current backend client should not replace `OpenAvatarChatService` in one step. Keep the old service until `回响` and `记忆档案馆` are verified against the new client.
- Care dashboard copy must avoid medical diagnosis. Use `信号`, `关怀`, `建议`, and `风险提醒`; avoid definitive disease labels in user-facing UI.

## Self-Review

- PRD coverage: `回响`, `记忆档案馆`, `设置管理`, and `长辈关怀` each map to at least one implementation task.
- UI coverage: login and three Stitch-visible tabs are covered.
- Backend coverage: archive, KB, family, and care endpoints are covered by `DreamJourneyBackendClient`.
- Hidden-feature policy: unfinished inputs and old routes are gated through `FeatureFlagService`.
- Verification: each implementation group has a build command and commit boundary.
