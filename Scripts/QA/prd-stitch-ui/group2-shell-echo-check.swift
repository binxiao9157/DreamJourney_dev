import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let tabbar = read("DreamJourney/Sources/TabBar/WarmTabBarController.swift")
let appCoordinator = read("DreamJourney/Sources/App/AppCoordinator.swift")
let authCoordinator = read("DreamJourney/Sources/App/AuthCoordinator.swift")
let tabCoordinator = read("DreamJourney/Sources/App/TabCoordinator.swift")
let login = read("DreamJourney/Sources/Modules/Auth/LoginViewController.swift")
let echoView = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let echoViewModel = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
let dialogManager = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let microphone = read("DreamJourney/Sources/Services/MicrophonePermissionManager.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")

assertContains(tabbar, "title: \"记忆档案\"", "shell first tab")
assertContains(tabbar, "title: \"回响\"", "shell second tab")
assertContains(tabbar, "title: \"我的\"", "shell third tab")
assertContains(tabbar, "private func suppressSystemTabBar()", "shell must suppress system tabbar")
assertContains(tabbar, "tabBar.accessibilityElementsHidden = true", "system tabbar must not remain in UI tree")
assertContains(tabbar, "private func updateShadowPath()", "custom tabbar shadow must stay single-layer")
assertNotContains(tabbar, "warmTabBar.safeBottom =", "custom tabbar should not keep stale safe-bottom feedback")
assertNotContains(tabbar, "shadowRadius = 40", "custom tabbar must not render a second-bottom-bar shadow")

assertContains(appCoordinator, "if UserManager.shared.isLoggedIn", "root coordinator should route by login state")
assertContains(appCoordinator, "showMainTab()", "root coordinator should expose main shell route")
assertContains(appCoordinator, "showAuth()", "root coordinator should expose auth route")
assertContains(appCoordinator, "name: .djUserDidLogout", "logout should return to auth via notification")
assertContains(appCoordinator, "window?.rootViewController = navigationController", "auth route should own the root while logged out")
assertContains(appCoordinator, "window?.rootViewController = tabCoordinator.tabBarController", "main route should own the root while logged in")

assertContains(authCoordinator, "loginVC.didLogin", "auth coordinator should observe login completion")
assertContains(authCoordinator, "self?.didFinishLogin?()", "auth coordinator should hand login completion to root coordinator")

assertContains(tabCoordinator, "let archiveNav = UINavigationController(rootViewController: MemoryArchiveViewController())", "shell should mount archive root")
assertContains(tabCoordinator, "let echoNav = UINavigationController(rootViewController: EchoViewController())", "shell should mount echo root")
assertContains(tabCoordinator, "let profileVC = ProfileViewController()", "shell should mount profile root")
assertContains(tabCoordinator, "tabBarController.viewControllers = [archiveNav, echoNav, profileNav]", "shell should only expose PRD MVP tabs")
assertContains(tabCoordinator, "tabBarController.selectedIndex = 1", "shell should default to echo per current Stitch flow")
assertNotContains(tabCoordinator, "MapFootprintViewController", "map should not be exposed in MVP shell")
assertNotContains(tabCoordinator, "FamilyCircleViewController", "family space should not be exposed in MVP shell")

assertContains(login, "string: \"寻梦环游\"", "login title should match Stitch")
assertContains(login, "在时空中，留下你的身影", "login subtitle should match Stitch")
assertContains(login, "UserManager.shared.login(phone: rawPhone, nickname: \"\")", "login should preserve existing user flow")
assertContains(login, "guard rawPhone.count == 11 else { return }", "login should require 11-digit phone")

assertContains(echoView, "private let scenicView = EchoScenicParkView()", "echo should keep full-screen scenic background")
assertContains(echoView, "accessibilityLabel = \"开始语音\"", "echo public entry should remain voice-first")
assertContains(echoView, "DialogEngineManager.shared.startDialog()", "echo microphone action should start dialog")
assertNotContains(echoView, "FeatureFlagService.shared.isEnabled(.echoTextInput)", "echo text input must stay hidden")
assertNotContains(echoView, "FeatureFlagService.shared.isEnabled(.echoImageInput)", "echo image input must stay hidden")

assertContains(echoViewModel, "archiveContextStatusProvider", "echo view model should expose archive context status")
assertContains(echoViewModel, "refreshArchiveContextStatus()", "echo view model should refresh archive context")
assertContains(echoViewModel, "MemoryArchiveRepository.shared.contextSnapshot()", "echo status should read archive repository")

assertContains(dialogManager, "private func buildArchiveContext() -> String", "dialog manager should isolate archive prompt context")
assertContains(dialogManager, "let archiveContext = buildArchiveContext()", "dialog prompt should build archive context")
assertContains(dialogManager, "fullPrompt += archiveContext", "dialog prompt should append archive context")
assertContains(dialogManager, "DialogPromptDebugRecorder.record(prompt:", "debug recorder should capture prompt")
assertContains(dialogManager, "containsArchiveContext: prompt.contains(\"【记忆档案馆素材线索】\")", "debug snapshot should mark archive context")

assertContains(microphone, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)", "microphone simulator gate")
assertContains(microphone, "completion(true)", "UIQA simulator microphone should auto grant")

assertContains(userManager, "func updateProfile(nickname: String)", "profile update should stay in UserManager")
assertContains(userManager, "NotificationCenter.default.post(name: .djUserDidUpdate", "profile update should notify visible screens")
