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
let podfile = read("Podfile")
let podfileLock = read("Podfile.lock")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

assertContains(gitignore, "tmp/**/DerivedData*/", "Xcode QA build caches should be ignored")
assertContains(gitignore, "DreamJourney/Config/Backend.local.xcconfig", "local backend config should stay ignored")
assertContains(gitignore, "DreamJourney/Config/VoiceSDK.local.xcconfig", "local voice SDK config should stay ignored")

assertContains(plist, "<key>DreamJourneyBackendBaseURL</key>", "backend base URL key")
assertContains(plist, "<string>$(DREAMJOURNEY_BACKEND_BASE_URL)</string>", "backend base URL should resolve from build setting")
for retiredKey in ["DreamJourneyBackendAPIToken", "DREAMJOURNEY_BACKEND_API_TOKEN", "YOUR_DEEPSEEK_API_KEY", "VOLCENGINE_APP_ID", "VOLCENGINE_APP_KEY", "VOLCENGINE_APP_TOKEN"] {
    assertNotContains(plist, retiredKey, "mobile credentials must stay retired from Info.plist")
}

assertContains(flags, "private static let defaultEnabled: Set<DJFeature> = [\n        .echoTextInput,\n        .profileSettings,\n        .legalCenter,\n        .accountDeletion,\n    ]", "release defaults must match the V4 owner core")
assertContains(flags, "private static let storageVersionKey = \"dj.featureFlags.schemaVersion\"", "feature flag storage should be versioned")
assertContains(flags, "storedVersion == Self.currentStorageVersion", "old persisted flags should not bypass current release defaults")
assertContains(flags, "private static let nonPersistentFeatures: Set<DJFeature>", "future and beta features must have a non-persistent QA boundary")

assertContains(appDelegate, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))\nimport SpeechEngineToB", "device-only speech import must be excluded from UIQA simulator")
assertContains(appDelegate, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)\n        configureUIQASmokeHarnessIfNeeded()", "UIQA harness must be simulator gated")
assertContains(appDelegate, "arguments.contains(\"DJRunArchiveToEchoSmoke\")", "core smoke launch arg")
assertContains(appDelegate, "MemoryArchiveRepository.shared.add(item, syncToBackend: false)", "UIQA seed must not sync to backend")

assertContains(podfile, "SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator*] = $(inherited) UI_QA_SIMULATOR", "simulator Pod config must define UI_QA_SIMULATOR")
assertContains(podfile, "OTHER_LDFLAGS[sdk=iphonesimulator*]", "simulator-specific ldflags must exist")
assertContains(podfile, "SpeechEngineToB and AMap ship device-only binaries", "Podfile must document simulator workaround")
assertContains(podfileLock, "PODFILE CHECKSUM:", "Podfile.lock must record the current Podfile checksum")

assertContains(project, "PRODUCT_BUNDLE_IDENTIFIER = \"$(DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER)\";", "bundle id should use the project-owned override setting")
assertContains(project, "DREAMJOURNEY_BACKEND_BASE_URL = \"\";", "tracked project should not force a backend environment")
for retiredSetting in ["DREAMJOURNEY_BACKEND_API_TOKEN", "VOLCENGINE_APP_ID", "VOLCENGINE_APP_KEY", "VOLCENGINE_APP_TOKEN"] {
    assertNotContains(project, retiredSetting, "mobile provider/shared-token build setting must stay retired")
}
assertContains(project, "MemoryArchiveTextEntryViewController.swift in Sources", "new text entry file must be in target")
assertContains(project, "MemoryArchivePhotoEntryViewController.swift in Sources", "new photo entry file must be in target")
assertContains(project, "MemoryArchiveAudioRecorderViewController.swift in Sources", "new audio recorder file must be in target")
assertContains(project, "ProfileLegalViewController.swift in Sources", "legal page must be in target")
assertContains(project, "ProfileSettingsViewController.swift in Sources", "settings page must be in target")
