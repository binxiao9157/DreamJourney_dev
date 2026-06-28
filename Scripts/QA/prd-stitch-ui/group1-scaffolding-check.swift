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
assertContains(plist, "<key>DreamJourneyBackendAPIToken</key>", "backend API token key")
assertContains(plist, "<string>$(DREAMJOURNEY_BACKEND_API_TOKEN)</string>", "backend API token should resolve from build setting")
assertContains(plist, "<string>YOUR_DEEPSEEK_API_KEY</string>", "DeepSeek API key must remain a placeholder")
assertContains(plist, "<string>$(VOLCENGINE_APP_ID)</string>", "VolcEngine app id should resolve from build setting")
assertContains(plist, "<string>$(VOLCENGINE_APP_KEY)</string>", "VolcEngine app key should resolve from build setting")
assertContains(plist, "<string>$(VOLCENGINE_APP_TOKEN)</string>", "VolcEngine token should resolve from build setting")

assertContains(flags, "private static let defaultEnabled: Set<DJFeature> = [\n        .careDashboard,\n        .profileSettings,\n        .legalCenter,\n    ]", "release defaults must stay narrow")
assertContains(flags, "private static let storageVersionKey = \"dj.featureFlags.schemaVersion\"", "feature flag storage should be versioned")
assertContains(flags, "storedVersion == Self.currentStorageVersion", "old persisted flags should not bypass current release defaults")
assertNotContains(flags, ".familyManagement,\n        .legalCenter,\n        .accountDeletion", "old risky profile defaults must not return")

assertContains(appDelegate, "#if !(UI_QA_SIMULATOR && targetEnvironment(simulator))\nimport SpeechEngineToB", "device-only speech import must be excluded from UIQA simulator")
assertContains(appDelegate, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)\n        configureUIQASmokeHarnessIfNeeded()", "UIQA harness must be simulator gated")
assertContains(appDelegate, "arguments.contains(\"DJRunArchiveToEchoSmoke\")", "core smoke launch arg")
assertContains(appDelegate, "MemoryArchiveRepository.shared.add(item, syncToBackend: false)", "UIQA seed must not sync to backend")

assertContains(podfile, "SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=iphonesimulator*] = $(inherited) UI_QA_SIMULATOR", "simulator Pod config must define UI_QA_SIMULATOR")
assertContains(podfile, "OTHER_LDFLAGS[sdk=iphonesimulator*]", "simulator-specific ldflags must exist")
assertContains(podfile, "SpeechEngineToB and AMap ship device-only binaries", "Podfile must document simulator workaround")
assertContains(podfileLock, "PODFILE CHECKSUM: 1772f9d2ed1ed2651531d16a96ac333b4a71f8b1", "Podfile.lock must be synced after Podfile changes")

assertContains(project, "PRODUCT_BUNDLE_IDENTIFIER = com.yxj.dreamjourney.app;", "bundle id used by simulator QA")
assertContains(project, "DREAMJOURNEY_BACKEND_BASE_URL = \"http://127.0.0.1:3100\";", "backend base URL build setting should default to local")
assertContains(project, "DREAMJOURNEY_BACKEND_API_TOKEN = YOUR_DREAMJOURNEY_BACKEND_API_TOKEN;", "backend token build setting should stay placeholder")
assertContains(project, "VOLCENGINE_APP_ID = YOUR_VOLCENGINE_APP_ID;", "VolcEngine app id build setting should default to placeholder")
assertContains(project, "VOLCENGINE_APP_KEY = YOUR_VOLCENGINE_APP_KEY;", "VolcEngine app key build setting should default to placeholder")
assertContains(project, "VOLCENGINE_APP_TOKEN = YOUR_VOLCENGINE_APP_TOKEN;", "VolcEngine token build setting should default to placeholder")
assertContains(project, "MemoryArchiveTextEntryViewController.swift in Sources", "new text entry file must be in target")
assertContains(project, "MemoryArchivePhotoEntryViewController.swift in Sources", "new photo entry file must be in target")
assertContains(project, "MemoryArchiveAudioRecorderViewController.swift in Sources", "new audio recorder file must be in target")
assertContains(project, "ProfileLegalViewController.swift in Sources", "legal page must be in target")
assertContains(project, "ProfileSettingsViewController.swift in Sources", "settings page must be in target")
