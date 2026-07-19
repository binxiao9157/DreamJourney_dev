import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

func url(_ relativePath: String) -> URL {
    root.appendingPathComponent(relativePath)
}

func read(_ relativePath: String) -> String {
    let fileURL = url(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertFileExists(_ relativePath: String, _ message: String) {
    guard fileManager.fileExists(atPath: url(relativePath).path) else {
        fatalError("\(message): missing \(relativePath)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let storePath = "DreamJourney/Sources/Services/EchoDelayedReplyStore.swift"
let schedulerPath = "DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift"

assertFileExists(storePath, "Echo delayed reply store")
assertFileExists(schedulerPath, "Echo delayed reply notification scheduler")

let store = read(storePath)
let scheduler = read(schedulerPath)
let echoViewModel = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
let echoViewController = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

assertContains(store, "struct EchoDelayedReply: Codable, Equatable", "Echo delayed reply should be persisted")
assertContains(store, "scheduledAt: Date", "Echo delayed reply should store scheduled time")
assertContains(store, "deliverAt: Date", "Echo delayed reply should store delivery time")
assertContains(store, "userTurnCount: Int", "Echo delayed reply should store triggering turn count")
assertContains(store, "trigger: EchoDelayedReplyTrigger", "Echo delayed reply should store trigger reason")
assertContains(store, "enum EchoDelayedReplyTrigger: String, Codable", "Echo delayed reply should encode trigger reason")
assertContains(store, "case tenRoundBaseline", "Echo delayed reply should identify ten-round baseline triggers")
assertContains(store, "case contentSignal", "Echo delayed reply should identify content signal triggers")
assertContains(store, "final class EchoDelayedReplyStore", "Echo delayed reply store should be centralized")
assertContains(store, "func save(_ reply: EchoDelayedReply) -> Bool", "Echo delayed reply store should save state")
assertContains(store, "func load() -> EchoDelayedReply?", "Echo delayed reply store should load state")
assertContains(store, "func clear()", "Echo delayed reply store should clear stale state")

assertContains(scheduler, "import UserNotifications", "Echo delayed reply should use local notifications")
assertContains(scheduler, "final class EchoDelayedReplyNotificationScheduler", "Echo delayed reply should have a local notification scheduler")
assertContains(scheduler, "static let notificationIdentifier = \"dj.echo.delayedReply\"", "Scheduler should use a stable notification identifier")
assertContains(scheduler, "func requestAuthorizationIfNeeded", "Scheduler should request local notification authorization")
assertContains(scheduler, "func schedule(_ delayedReply: EchoDelayedReply", "Scheduler should schedule local notification")
assertContains(scheduler, "func cancelPendingDelayedReply", "Scheduler should cancel stale Echo notifications")
assertContains(scheduler, "回信到了，回来听听这段回响。", "Local notification copy should match PRD tone")

assertContains(echoViewModel, "private(set) var pendingDelayedReply: EchoDelayedReply?", "Echo view model should expose generated delayed reply state")
assertContains(echoViewModel, "EchoDelayedReplyStore.shared.save(delayedReply)", "Echo view model should persist delayed reply state")
assertContains(echoViewModel, "EchoDelayedReplyStore.shared.clear()", "Echo view model should clear stale delayed reply state")
assertContains(echoViewModel, "EchoReplyPacingPolicy.triggerForWait", "Echo view model should persist the wait trigger reason")

assertContains(echoViewController, "scheduleDelayedReplyNotificationIfNeeded(rawTranscript:", "Echo controller should schedule local notification after waiting starts")
assertContains(echoViewController, "EchoDelayedReplyNotificationScheduler.shared.requestAuthorizationIfNeeded", "Echo controller should request local notification authorization")
assertContains(echoViewController, "EchoDelayedReplyNotificationScheduler.shared.schedule", "Echo controller should schedule local notification")

assertContains(featureFlags, "DJRunEchoDelayedReplyNotificationSmoke", "QA scenario registry should expose Echo delayed reply notification smoke")
assertContains(appDelegate, "case .echoDelayedReplyNotificationSmoke", "AppDelegate should dispatch Echo delayed reply notification smoke through the scenario registry")
assertContains(appDelegate, "runEchoDelayedReplyNotificationSmoke", "App delegate should run Echo delayed reply notification smoke")
assertContains(appDelegate, "writeEchoDelayedReplyNotificationSmokeResult", "App delegate should write Echo notification smoke evidence")
assertContains(appDelegate, "\"delayMinutesInRange\"", "Echo notification smoke should report delay range")
assertContains(appDelegate, "\"storedDelayedReply\"", "Echo notification smoke should report stored delayed reply")
assertContains(appDelegate, "\"localNotificationContractPresent\"", "Echo notification smoke should report local notification contract")
assertContains(appDelegate, "EchoDelayedReplyNotificationScheduler.shared.schedule", "Echo notification smoke should actually schedule a local notification")
assertContains(appDelegate, "UNUserNotificationCenter.current().getPendingNotificationRequests", "Echo notification smoke should query pending local notification requests")
assertContains(appDelegate, "pendingNotificationMatched", "Echo notification smoke should report whether a pending request exists")
assertContains(appDelegate, "pendingNotificationIdentifierMatched", "Echo notification smoke should verify the pending request identifier")
assertContains(appDelegate, "pendingNotificationTriggerMatched", "Echo notification smoke should verify the pending request trigger")
assertContains(appDelegate, "pendingNotificationUserInfoMatched", "Echo notification smoke should verify pending request userInfo")
assertContains(appDelegate, "pendingNotificationCount", "Echo notification smoke should report pending request count")
assertContains(appDelegate, "restoreStoredDelayedReplyIfAvailable(", "Echo notification smoke should verify cold-start delayed reply restore")
assertContains(appDelegate, "now: delayedReply.scheduledAt.addingTimeInterval(60)", "Echo notification smoke should verify restore before delivery")
assertContains(appDelegate, "\"restoredWaitingState\"", "Echo notification smoke should report restored waiting state")
assertContains(appDelegate, "\"restoredWaitingMinutesInRange\"", "Echo notification smoke should report restored waiting minutes")
assertContains(appDelegate, "\"restoredDelayedReplyIdMatched\"", "Echo notification smoke should verify restored delayed reply identity")
assertContains(appDelegate, "\"expiredDelayedReplyArrived\"", "Echo notification smoke should report expired delayed reply arrival")
assertContains(appDelegate, "\"expiredDelayedReplyCleared\"", "Echo notification smoke should verify expired delayed reply clears storage")

let smokeScript = read("Scripts/QA/prd-stitch-ui/run-echo-delayed-reply-notification-smoke.sh")
assertContains(smokeScript, "\"pendingNotificationMatched\"", "Echo notification smoke script should assert pending request existence")
assertContains(smokeScript, "\"pendingNotificationUserInfoMatched\"", "Echo notification smoke script should assert pending request userInfo")
assertContains(smokeScript, "\"restoredWaitingState\"", "Echo notification smoke script should assert restored waiting state")
assertContains(smokeScript, "\"restoredWaitingMinutesInRange\"", "Echo notification smoke script should assert restored waiting minutes")
assertContains(smokeScript, "\"restoredDelayedReplyIdMatched\"", "Echo notification smoke script should assert restored delayed reply identity")
assertContains(smokeScript, "\"expiredDelayedReplyArrived\"", "Echo notification smoke script should assert expired delayed reply arrival")
assertContains(smokeScript, "\"expiredDelayedReplyCleared\"", "Echo notification smoke script should assert expired delayed reply clearing")

assertContains(project, "EchoDelayedReplyStore.swift in Sources", "Echo delayed reply store should be in the Xcode target")
assertContains(project, "EchoDelayedReplyNotificationScheduler.swift in Sources", "Echo delayed reply scheduler should be in the Xcode target")
assertContains(releasePackage, "echo-delayed-reply-notification-check.swift", "release QA package should include Echo delayed reply notification guard")
assertContains(releaseRegression, "echo-delayed-reply-notification-check.swift", "release regression should run Echo delayed reply notification guard")

print("Echo delayed reply notification checks passed")
