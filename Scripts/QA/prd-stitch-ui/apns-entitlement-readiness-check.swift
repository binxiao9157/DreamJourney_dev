import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)
let fileManager = FileManager.default

func url(_ relativePath: String) -> URL {
    rootURL.appendingPathComponent(relativePath)
}

func read(_ relativePath: String) -> String {
    let fileURL = url(relativePath)
    do {
        return try String(contentsOf: fileURL, encoding: .utf8)
    } catch {
        fatalError("Unable to read \(relativePath): \(error)")
    }
}

func assertFileExists(_ relativePath: String, _ message: String) {
    guard fileManager.fileExists(atPath: url(relativePath).path) else {
        fatalError(message)
    }
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let entitlementsPath = "DreamJourney/DreamJourney.entitlements"
assertFileExists(entitlementsPath, "DreamJourney app entitlements file should exist")

let entitlements = read(entitlementsPath)
let projectYML = read("project.yml")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let readinessDoc = read("docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md")
let coverage = read("docs/superpowers/status/2026-06-18-prd-coverage-matrix.md")

for required in [
    "<key>aps-environment</key>",
    "<string>development</string>",
] {
    assertContains(entitlements, required, "APNs entitlements should declare development push environment")
}

for required in [
    "CODE_SIGN_STYLE: Automatic",
] {
    assertContains(projectYML, required, "XcodeGen project should keep default automatic signing buildable for personal-team device smoke")
}

for required in [
    "CODE_SIGN_STYLE = Automatic;",
] {
    assertContains(project, required, "Xcode project should keep default automatic signing buildable for personal-team device smoke")
}

for required in [
    "embedded",
    "mobileprovision",
    "aps-environment",
    "APNs entitlement missing; skip remote notification registration",
    "registerForRemoteNotifications",
    "didRegisterForRemoteNotificationsWithDeviceToken",
    "didFailToRegisterForRemoteNotificationsWithError",
] {
    assertContains(appDelegate, required, "AppDelegate should implement APNs entitlement-gated token registration lifecycle")
}

assertContains(
    readinessDoc,
    "APNs entitlement",
    "Device/backend readiness doc should record APNs entitlement status"
)
assertContains(
    coverage,
    "APNs provider delivery / 真机通知到达",
    "PRD coverage should preserve APNs delivery as a separate acceptance gate"
)

print("APNs entitlement readiness checks passed")
