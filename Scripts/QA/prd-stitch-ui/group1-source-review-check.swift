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

let gitignore = read(".gitignore")
let plist = read("DreamJourney/Resources/Info.plist")
let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let componentFactory = read("DreamJourney/Sources/DesignSystem/DJComponentFactory.swift")
let podfile = read("Podfile")
let podfileLock = read("Podfile.lock")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

assertContains(gitignore, "tmp/**/DerivedData*/", "generated DerivedData should stay ignored")

for placeholder in [
    "YOUR_AMAP_KEY",
    "YOUR_DEEPSEEK_API_KEY",
    "YOUR_VOICECLONE_API_KEY",
] {
    assertContains(plist, placeholder, "Info.plist should keep placeholder \(placeholder)")
}
for buildSetting in [
    "$(VOLCENGINE_APP_ID)",
    "$(VOLCENGINE_APP_KEY)",
    "$(VOLCENGINE_APP_TOKEN)",
] {
    assertContains(plist, buildSetting, "Info.plist should inject voice SDK config through build setting \(buildSetting)")
}
assertContains(plist, "<key>DreamJourneyBackendBaseURL</key>", "backend base URL key")
assertContains(plist, "<string>$(DREAMJOURNEY_BACKEND_BASE_URL)</string>", "backend URL should resolve from build setting")
assertContains(plist, "<key>DreamJourneyBackendAPIToken</key>", "backend API token key")
assertContains(plist, "<string>$(DREAMJOURNEY_BACKEND_API_TOKEN)</string>", "backend API token should resolve from build setting")

assertContains(flags, "private static let storageVersionKey = \"dj.featureFlags.schemaVersion\"", "feature flag storage should be versioned")
assertContains(flags, "private static let currentStorageVersion = 9", "feature flag storage version")
assertContains(flags, "let storedVersion = UserDefaults.standard.integer(forKey: Self.storageVersionKey)", "feature flags should read stored version")
assertContains(flags, "storedVersion == Self.currentStorageVersion", "feature flags should only trust matching-version storage")
assertContains(flags, "self.enabled = Self.defaultEnabled\n            persist()", "old flag storage should reset to current defaults")
assertContains(flags, "UserDefaults.standard.set(Self.currentStorageVersion, forKey: Self.storageVersionKey)", "persist should write storage version")
assertContains(flags, "private static let defaultEnabled: Set<DJFeature> = [\n        .careDashboard,\n        .profileSettings,\n        .legalCenter,\n    ]", "default release flags should stay narrow")
assertNotContains(flags, ".familyManagement,\n        .legalCenter,\n        .accountDeletion", "old risky defaults must not return")

assertContains(appDelegate, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))\nimport SpeechEngineToB", "speech import should be excluded from UIQA simulator")
assertContains(appDelegate, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))\nimport SpeechEngineToB\nimport AMapFoundationKit\nimport MAMapKit\n#endif", "device-only imports should stay gated together")
assertContains(appDelegate, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)\n        configureUIQASmokeHarnessIfNeeded()\n        #endif", "UIQA harness should be simulator gated")
assertContains(appDelegate, "arguments.contains(\"DJEnableArchiveRemoteFetch\")", "archive backend fetch QA launch arg")
assertContains(appDelegate, "arguments.contains(\"DJRunArchiveToEchoSmoke\")", "archive-to-echo smoke launch arg")
assertContains(appDelegate, "MemoryArchiveRepository.shared.add(item, syncToBackend: false)", "UIQA seeds should not sync to backend")
assertContains(appDelegate, "archive-to-echo-smoke-result.json", "smoke result file should stay stable")

assertContains(componentFactory, "UIButton.Configuration", "design system buttons should use modern UIButton.Configuration")
assertContains(componentFactory, "configuration.contentInsets", "design system buttons should set insets through configuration")
assertNotContains(componentFactory, "contentEdgeInsets", "design system buttons should avoid deprecated contentEdgeInsets")

assertContains(podfile, "SpeechEngineToB and AMap ship device-only binaries", "Podfile should document simulator workaround")
assertContains(podfile, "SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator*] = $(inherited) UI_QA_SIMULATOR", "simulator builds should define UI_QA_SIMULATOR")
assertContains(podfile, "lines.reject! do |line|", "Podfile simulator overrides should be idempotent")
assertContains(podfile, "OTHER_LDFLAGS[sdk=iphonesimulator*]", "simulator ldflags override")
assertContains(podfileLock, "PODFILE CHECKSUM: 1772f9d2ed1ed2651531d16a96ac333b4a71f8b1", "Podfile.lock should match Podfile change")

for source in [
    "FeatureFlagService.swift",
    "MemoryArchiveTextEntryViewController.swift",
    "MemoryArchivePhotoEntryViewController.swift",
    "MemoryArchiveAudioRecorderViewController.swift",
    "ProfileLegalViewController.swift",
    "ProfileSettingsViewController.swift",
] {
    assertContains(project, "\(source) in Sources", "\(source) should be target-included")
}
assertContains(project, "DREAMJOURNEY_BACKEND_BASE_URL = \"http://127.0.0.1:3100\";", "backend base URL build setting should default to local")
assertContains(project, "DREAMJOURNEY_BACKEND_API_TOKEN = YOUR_DREAMJOURNEY_BACKEND_API_TOKEN;", "backend token build setting should stay placeholder")
assertContains(project, "VOLCENGINE_APP_ID = YOUR_VOLCENGINE_APP_ID;", "VolcEngine app id build setting should default to placeholder")
assertContains(project, "VOLCENGINE_APP_KEY = YOUR_VOLCENGINE_APP_KEY;", "VolcEngine app key build setting should default to placeholder")
assertContains(project, "VOLCENGINE_APP_TOKEN = YOUR_VOLCENGINE_APP_TOKEN;", "VolcEngine token build setting should default to placeholder")

print("Group 1 source review checks passed")
