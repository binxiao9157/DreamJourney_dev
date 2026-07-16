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

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let legal = read("DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

assertContains(flags, "private static let defaultEnabled: Set<DJFeature> = [\n        .echoTextInput,\n        .profileSettings,\n        .legalCenter,\n        .accountDeletion,\n    ]", "profile settings and legal center should remain in the V4 owner-core defaults")

assertContains(profile, "case .legalCenter:\n            showLegalCenter()", "legal row should push a real page")
assertContains(profile, "private func showLegalCenter()", "profile should expose a legal center route")
assertContains(profile, "ProfileLegalViewController()", "profile should instantiate the legal page")
assertNotContains(profile, "case .legalCenter:\n            showUnavailableAlert()", "legal row must not be an unavailable placeholder")

assertContains(legal, "final class ProfileLegalViewController", "legal page view controller")
assertContains(legal, "title = \"法律法规\"", "legal page title")
assertContains(legal, "AI 辅助说明", "AI assistance explanation section")
assertContains(legal, "心理支持边界", "mental health boundary section")
assertContains(legal, "隐私与数据", "privacy and data section")
assertContains(legal, "紧急情况", "emergency guidance section")
assertContains(legal, "不是医疗诊断", "medical diagnosis disclaimer")
assertContains(legal, "不展示聊天原文", "care privacy promise")

assertContains(project, "ProfileLegalViewController.swift in Sources", "legal page added to app target")
assertContains(project, "ProfileLegalViewController.swift", "legal page file reference")
