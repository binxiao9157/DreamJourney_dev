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

func extractDefaultEnabledFeatures(from flags: String) -> Set<String> {
    let marker = "private static let defaultEnabled: Set<DJFeature> = ["
    guard let start = flags.range(of: marker)?.upperBound,
          let end = flags[start...].range(of: "]")?.lowerBound else {
        fatalError("Unable to find FeatureFlagService.defaultEnabled")
    }

    let body = flags[start..<end]
    let regex = try! NSRegularExpression(pattern: "\\.([A-Za-z0-9_]+)")
    let nsRange = NSRange(body.startIndex..<body.endIndex, in: body)
    return Set(regex.matches(in: String(body), range: nsRange).compactMap { match in
        guard let range = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[range])
    })
}

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let tabCoordinator = read("DreamJourney/Sources/App/TabCoordinator.swift")
let warmTabBar = read("DreamJourney/Sources/TabBar/WarmTabBarController.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let archiveOptions = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
let aiRecording = read("DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift")
let map = read("DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift")
let annotation = read("DreamJourney/Sources/Modules/Map/MemoryAnnotation.swift")
let annotationView = read("DreamJourney/Sources/Modules/Map/MemoryAnnotationView.swift")
let memoirFlow = read("DreamJourney/Sources/Memoir/MemoirFlowManager.swift")
let memoirTTS = read("DreamJourney/Sources/Memoir/MemoirTTSService.swift")
let voiceClone = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let infoPlist = read("DreamJourney/Resources/Info.plist")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

let defaults = extractDefaultEnabledFeatures(from: flags)
for feature in ["timeLetters", "archiveAudioUpload", "personaSettings", "familyManagement"] {
    guard !defaults.contains(feature) else {
        fatalError("\(feature) must remain hidden by default")
    }
}

assertContains(tabCoordinator, "tabBarController.viewControllers = [archiveNav, echoNav, profileNav]", "PRD shell should stay archive/echo/profile")
assertContains(tabCoordinator, "tabBarController.selectedIndex = 1", "PRD shell should open on echo")
for legacyRoute in ["MapFootprintViewController()", "AIRecordingViewController()", "FamilyCircleViewController()"] {
    assertNotContains(tabCoordinator, legacyRoute, "PRD shell must not directly route legacy \(legacyRoute)")
}

for label in ["记忆档案", "回响", "我的"] {
    assertContains(warmTabBar, "title: \"\(label)\"", "custom tabbar must expose \(label)")
}
for legacyLabel in ["足迹", "亲友", "知识", "往日记念", "时光回响", "记念"] {
    assertNotContains(warmTabBar, "title: \"\(legacyLabel)\"", "custom tabbar must not expose old label \(legacyLabel)")
}

assertContains(archiveOptions, "if isTimeLettersEnabled {\n            options.append(.timeLetter)\n        }", "time-letter creation should be opt-in")
assertContains(archive, "return FeatureFlagService.shared.isEnabled(.timeLetters)", "time-letter feature should be release gated")
assertContains(archive, "DJEnableArchiveHiddenBranches", "archive hidden branches should require explicit UIQA launch argument")
assertContains(archive, "@objc private func mapFootprintTapped()", "map route should stay localized in archive future route")
assertContains(archive, "guard isTimeLetterCreationEnabled else { return }\n        let currentUser = UserManager.shared.currentUser", "map route should be guarded before creating MapFootprintViewController")
assertContains(archive, "case .timeLetter:\n            guard isTimeLetterCreationEnabled else { return }\n            presentTextEntry(kind: .timeLetter)", "time-letter sheet branch should be guarded")

assertContains(map, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)", "map should have simulator/UIQA fallback")
assertContains(map, "模拟器视觉 QA 暂不加载地图 SDK", "map UIQA fallback should avoid live map SDK")
assertContains(map, "#else\nimport UIKit\nimport MAMapKit\nimport AMapFoundationKit", "map production branch should keep AMap imports isolated")
assertContains(annotation, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))", "annotation should be excluded from UIQA simulator")
assertContains(annotationView, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))", "annotation view should be excluded from UIQA simulator")

assertContains(infoPlist, "<key>NSLocationWhenInUseUsageDescription</key>", "map future route should keep location privacy declaration")
assertContains(infoPlist, "寻梦环游需要访问位置以在地图上标记回忆地点", "location privacy copy should stay product-specific")
assertContains(infoPlist, "<key>AMapAPIKey</key>", "map future route should keep AMap key configuration slot")
assertContains(appDelegate, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))\nimport SpeechEngineToB\nimport AMapFoundationKit\nimport MAMapKit", "AMap imports should stay out of UIQA simulator")
assertContains(appDelegate, "MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)", "AMap privacy show call should happen before map creation")
assertContains(appDelegate, "MAMapView.updatePrivacyAgree(.didAgree)", "AMap privacy agree call should happen before map creation")
assertContains(appDelegate, "Bundle.main.object(forInfoDictionaryKey: \"AMapAPIKey\")", "AMap key should be read from Info.plist")
assertContains(appDelegate, "apiKey != \"YOUR_AMAP_KEY\"", "placeholder AMap key should not be registered")
assertContains(appDelegate, "AMapServices.shared().apiKey = apiKey", "AMap key should be registered when configured")

for fileName in ["MapFootprintViewController.swift", "MemoryAnnotation.swift", "MemoryAnnotationView.swift"] {
    assertContains(project, "\(fileName) in Sources", "\(fileName) should remain in target for future compatibility")
}

assertNotContains(memoirFlow, "tabBar.viewControllers?[1]", "legacy memoir banner must not assume tab index 1 is the old footprint map")
assertNotContains(memoirFlow, "已保存到足迹", "legacy hidden memoir copy should not leak old footprint destination")
assertNotContains(memoirFlow, "trainVoice(audioURL: recordingURL) { [weak self]", "voice training callback should not capture unused self")
assertContains(aiRecording, "showToast(\"寻梦环游已经记住您说的了，下次再聊～\", type: .success)", "legacy recording keyword end copy should stay intact")
assertNotContains(aiRecording, "case .keyword(let kw):", "legacy recording keyword end should not bind an unused kw value")
assertContains(memoirTTS, "DDLogInfo(\"[MemoirTTS] 使用系统TTS降级播放（无法导出文件）\")", "system TTS fallback should remain explicit about no file export")
assertNotContains(memoirTTS, "let synthesizer = AVSpeechSynthesizer()", "system TTS fallback should not create an unused synthesizer")
assertContains(voiceClone, "let body: [String: Any] = [\n            \"speaker_id\": finalSpeakerId", "voice clone request body should be immutable")
assertNotContains(voiceClone, "var body: [String: Any] = [", "voice clone request body should not use an unused var")

print("Group 5 map/future route compatibility checks passed")
