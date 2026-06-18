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

let echoViewModel = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
let echoView = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releasePackageCheck = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

assertContains(echoViewModel, "case thinking", "Echo state machine should include a thinking state between final user speech and AI reply")
assertContains(echoViewModel, "case replied", "Echo state machine should include a replied state after an AI reply has arrived")
assertContains(echoViewModel, "struct EchoReplyPacingPolicy", "Echo should centralize the waiting reply policy")
assertContains(echoViewModel, "static let waitAfterUserTurnCount = 10", "Echo should follow the updated PRD ten-round default wait policy")
assertContains(echoViewModel, "static let replyDelayMinuteRange = 5...10", "Echo waiting reply delay should stay within the updated PRD 5-10 minute range")
assertContains(echoViewModel, "static func shouldWaitForReply(afterUserTurnCount userTurnCount: Int, userText: String) -> Bool", "Echo waiting policy should be testable with turn count and content signal")
assertContains(echoViewModel, "static func shouldTriggerEarlyWait(for userText: String) -> Bool", "Echo should expose the updated PRD early trigger hook for emotion/content signals")
assertContains(echoViewModel, "userTurnCount >= waitAfterUserTurnCount", "Echo waiting policy should trigger at the configured turn threshold")
assertContains(echoViewModel, "private var currentSessionUserTurnCount = 0", "Echo view model should track user turns within the current voice session")
assertContains(echoViewModel, "currentSessionUserTurnCount += 1", "Echo should increment the current voice-session user turn count")
assertContains(echoViewModel, "EchoReplyPacingPolicy.shouldWaitForReply(", "Echo should use the pacing policy before entering waiting reply")
assertContains(echoViewModel, "afterUserTurnCount: currentSessionUserTurnCount", "Echo waiting policy should receive the current turn count")
assertContains(echoViewModel, "userText: normalizedText", "Echo waiting policy should receive the current user text")
assertContains(echoViewModel, "updateState(.thinking)", "Echo should enter thinking state before the waiting threshold is reached")
assertContains(echoViewModel, "max(0, sessionCount) % 6", "Echo should distribute wait minutes across the 5-10 minute range")
assertContains(echoViewModel, "currentSessionUserTurnCount = 0", "Echo should reset the session turn count when returning to idle")
assertContains(echoViewModel, "var isWaitingForDelayedReply: Bool", "Echo should expose whether a delayed reply wait is active")
assertContains(echoViewModel, "func markReplyDelivered()", "Echo should expose a replied state transition after TTS finishes")

assertContains(echoView, "case .thinking:", "Echo UI should render thinking state")
assertContains(echoView, "renderVoiceStatus(text: \"我在想一想\", isVisible: true)", "Echo thinking UI should use warm public copy")
assertContains(echoView, "case .replied:", "Echo UI should render replied state")
assertContains(echoView, "renderVoiceStatus(text: \"回信已抵达\", isVisible: true)", "Echo replied UI should use explicit arrived copy")
assertContains(echoView, "先去窗边走走，约 \\(minutes) 分钟后我再回信", "Echo waiting UI should use the updated PRD walk-out guidance copy")
assertContains(echoView, "private var isStoppingForDelayedReply = false", "Echo controller should preserve waiting UI while stopping the live voice engine")
assertContains(echoView, "beginDelayedReplyWait()", "Echo controller should stop live voice capture when delayed reply wait starts")
assertContains(echoView, "guard !viewModel.isWaitingForDelayedReply else { return }", "Echo controller should ignore immediate AI reply callbacks while waiting")
assertContains(echoView, "viewModel.markReplyDelivered()", "Echo controller should mark replies as delivered after TTS finishes")
assertContains(echoView, "第十次想起这件事", "Echo waiting-reply UIQA preview should drive the ten-round waiting policy")

assertContains(releasePackageCheck, "echo-waiting-reply-policy-check.swift", "release QA package should include Echo waiting reply policy guard")
assertContains(releaseRegression, "echo-waiting-reply-policy-check.swift", "release regression should run Echo waiting reply policy guard")
