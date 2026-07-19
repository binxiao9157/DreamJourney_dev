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
let backendExampleConfig = read("DreamJourney/Config/Backend.example.xcconfig")

assertContains(gitignore, "tmp/**/DerivedData*/", "generated DerivedData should stay ignored")

assertContains(plist, "YOUR_AMAP_KEY", "Info.plist should keep the non-secret map placeholder")
assertContains(plist, "<key>DreamJourneyBackendBaseURL</key>", "backend base URL key")
assertContains(plist, "<string>$(DREAMJOURNEY_BACKEND_BASE_URL)</string>", "backend URL should resolve from build setting")
for retiredKey in ["DreamJourneyBackendAPIToken", "DREAMJOURNEY_BACKEND_API_TOKEN", "YOUR_DEEPSEEK_API_KEY", "YOUR_VOICECLONE_API_KEY", "VOLCENGINE_APP_ID", "VOLCENGINE_APP_KEY", "VOLCENGINE_APP_TOKEN"] {
    assertNotContains(plist, retiredKey, "mobile credentials must stay retired from Info.plist")
}

assertContains(flags, "private static let storageVersionKey = \"dj.featureFlags.schemaVersion\"", "feature flag storage should be versioned")
assertContains(flags, "private static let currentStorageVersion", "feature flag storage version")
assertContains(flags, "let storedVersion = UserDefaults.standard.integer(forKey: Self.storageVersionKey)", "feature flags should read stored version")
assertContains(flags, "storedVersion == Self.currentStorageVersion", "feature flags should only trust matching-version storage")
assertContains(flags, "self.enabled = Self.defaultEnabled\n            persist()", "old flag storage should reset to current defaults")
assertContains(flags, "UserDefaults.standard.set(Self.currentStorageVersion, forKey: Self.storageVersionKey)", "persist should write storage version")
assertContains(
    flags,
    "private static let defaultEnabled: Set<DJFeature> = [\n        .echoTextInput,\n        .profileSettings,\n        .legalCenter,\n        .accountDeletion,\n    ]",
    "default release flags should match the V4 owner core"
)
assertContains(flags, "private static let nonPersistentFeatures: Set<DJFeature>", "future and beta features should remain available only through process-scoped QA overrides")

assertContains(appDelegate, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))\nimport SpeechEngineToB", "speech import should be excluded from UIQA simulator")
assertContains(appDelegate, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))\nimport SpeechEngineToB\nimport AMapFoundationKit\nimport MAMapKit\n#endif", "device-only imports should stay gated together")
assertContains(appDelegate, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)\n        configureUIQASmokeHarnessIfNeeded()\n        #endif", "UIQA harness should be simulator gated")
assertContains(flags, "DJEnableArchiveRemoteFetch", "archive backend fetch QA launch arg should live in centralized feature registry")
assertContains(flags, "DJRunArchiveToEchoSmoke", "archive-to-echo smoke launch arg should live in centralized scenario registry")
assertContains(appDelegate, "configuration.shouldEnableArchiveRemoteFetch", "AppDelegate should consume the centralized archive remote fetch policy")
assertContains(appDelegate, "case .archiveToEchoSmoke", "AppDelegate should dispatch archive-to-echo through the scenario registry")
assertContains(appDelegate, "MemoryArchiveRepository.shared.add(item, syncToBackend: false)", "UIQA seeds should not sync to backend")
assertContains(appDelegate, "archive-to-echo-smoke-result.json", "smoke result file should stay stable")

assertContains(componentFactory, "UIButton.Configuration", "design system buttons should use modern UIButton.Configuration")
assertContains(componentFactory, "configuration.contentInsets", "design system buttons should set insets through configuration")
assertNotContains(componentFactory, "contentEdgeInsets", "design system buttons should avoid deprecated contentEdgeInsets")

assertContains(podfile, "SpeechEngineToB and AMap ship device-only binaries", "Podfile should document simulator workaround")
assertContains(podfile, "SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator*] = $(inherited) UI_QA_SIMULATOR", "simulator builds should define UI_QA_SIMULATOR")
assertContains(podfile, "lines.reject! do |line|", "Podfile simulator overrides should be idempotent")
assertContains(podfile, "OTHER_LDFLAGS[sdk=iphonesimulator*]", "simulator ldflags override")
assertContains(podfileLock, "PODFILE CHECKSUM:", "Podfile.lock should include the current Podfile checksum")
assertContains(podfileLock, "SpeechEngineToB", "Podfile.lock should retain the voice SDK pod")
assertContains(podfileLock, "TXLiteAVSDK_TRTC", "Podfile.lock should retain the Tencent TRTC compile-time pod")

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
assertContains(project, "DREAMJOURNEY_BACKEND_BASE_URL", "project should expose backend base URL as a build setting")
assertContains(backendExampleConfig, "DREAMJOURNEY_BACKEND_BASE_URL = http://127.0.0.1:3100", "backend example config should document the local default")
for retiredSetting in ["DREAMJOURNEY_BACKEND_API_TOKEN", "VOLCENGINE_APP_ID", "VOLCENGINE_APP_KEY", "VOLCENGINE_APP_TOKEN"] {
    assertNotContains(project, retiredSetting, "mobile provider/shared-token build setting must stay retired")
}

print("Group 1 source review checks passed")
