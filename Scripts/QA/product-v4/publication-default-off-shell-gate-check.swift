import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
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
        fatalError("\(message): unexpectedly found \(needle)")
    }
}

func section(_ source: String, from start: String, to end: String) -> String {
    guard let startRange = source.range(of: start),
          let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
        fatalError("Unable to isolate section from \(start) to \(end)")
    }
    return String(source[startRange.lowerBound..<endRange.lowerBound])
}

let features = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let visitorView = read("DreamJourney/Sources/Modules/Profile/ProfilePublicationVisitorViewController.swift")
let visitorAccess = read("DreamJourney/Sources/Services/PublicationVisitorAccess.swift")
let managementAccess = read("DreamJourney/Sources/Services/PublicationManagementAccess.swift")
let tabCoordinator = read("DreamJourney/Sources/App/TabCoordinator.swift")
let appCoordinator = read("DreamJourney/Sources/App/AppCoordinator.swift")
let sceneDelegate = read("DreamJourney/Sources/SceneDelegate.swift")
let accountRuntime = read("DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

let defaults = section(
    features,
    from: "private static let defaultEnabled",
    to: "private static let nonPersistentFeatures"
)
for feature in [
    ".publicationManagementM2",
    ".publicationGrantManagementM2",
    ".publicationVisitorM2",
] {
    assertNotContains(defaults, feature, "M2 publication surfaces must remain default-off")
}

for required in [
    ".publicationVisitorM2",
    ".publicationGrantManagementM2",
    ".publicationManagementM2",
    "return \"publication\"",
    "return \"visitorAccess\"",
    "return \"visitor\"",
    "\"closedPilotAdultSelf\"",
] {
    assertContains(features, required, "Feature policy mapping must stay explicit")
}

for required in [
    "PublicationManagementM2AccessGate.isManagementRouteAllowed",
    "PublicationVisitorRuntime.shared.hasPendingOrActiveAccess",
    "PublicationVisitorM2AccessGate.isRouteAllowed",
    "ProfilePublicationVisitorViewController()",
] {
    assertContains(profile, required, "Profile must own all controlled M2 entry points")
}

for required in [
    "tabBarController.viewControllers = [archiveNav, echoNav, profileNav]",
    "tabBarController.selectedIndex = 2",
    "ProfilePublicationVisitorViewController(runtime: runtime)",
] {
    assertContains(tabCoordinator, required, "Visitor routing must reuse the Profile tab")
}
assertNotContains(tabCoordinator, "visitorNav", "Visitor must not add a fourth tab")

for required in [
    "func receiveAppDeepLink(_ url: URL)",
    "publicationVisitorRuntime.stage(deepLinkURL: url)",
    "refreshPolicy(for: .publicationVisitorM2)",
    "publicationVisitorRuntime.clear(reason: .policyDenied)",
] {
    assertContains(appCoordinator, required, "Deep links must be policy-gated before routing")
}
assertContains(sceneDelegate, "receiveAppDeepLink", "Scene routing must pass app and universal links through the policy gate")

for required in [
    "enum PublicationVisitorM2AccessGate",
    "private var admissionGeneration = UUID()",
    "case expired",
    "case accessRevoked",
    "case policyDenied",
    "no visitor content is",
    "written to app storage",
] {
    assertContains(visitorAccess, required, "Visitor runtime must fail closed and remain process-local")
}
for required in [
    "enum PublicationManagementM2AccessGate",
    ".publicationManagementM2",
    ".publicationGrantManagementM2",
] {
    assertContains(managementAccess, required, "Owner management must require independent server policies")
}

assertContains(visitorView, "内容来自本人确认的公开副本。", "Visitor disclosure must identify the redacted publication copy")
for required in [
    "profile-publication-visitor-shell",
    "profile-publication-visitor-disclosure",
] {
    assertContains(visitorView, required, "Visitor shell must remain observable in QA")
}
for forbidden in ["EchoViewController", "MemoirTTSService", "DigitalHuman", "voiceProfileId"] {
    assertNotContains(visitorView, forbidden, "Neutral Visitor must not activate private Echo, voice, or Digital Human")
}

for required in [
    "PublicationVisitorRuntime.shared.clear(reason: .accountLeaseInvalid)",
    "for audience in [\"owner\", \"visitor\"]",
    "audience: audience",
] {
    assertContains(accountRuntime, required, "Account teardown must clear both policy audiences and visitor state")
}

for required in [
    "ProfilePublicationVisitorViewController.swift in Sources",
    "ProfilePublicationVisitorViewController.swift",
] {
    assertContains(project, required, "Visitor shell must be included in the app target")
}

print("Publication default-off iOS shell gate passed")
