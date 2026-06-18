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

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let store = read("DreamJourney/Sources/Services/EchoDelayedReplyStore.swift")
let docs = read("docs/superpowers/status/2026-06-18-echo-waiting-reply-policy.md")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

assertContains(store, "struct EchoDelayedReply: Codable, Equatable", "Push contract should reuse the persisted delayed reply model")
assertContains(client, "func scheduleEchoDelayedReplyPush", "Backend client should expose Echo push scheduling contract")
assertContains(client, "/echo/delayed-replies", "Push scheduling should use explicit Echo delayed reply endpoint")
assertContains(client, "\"delayedReplyId\": delayedReply.id", "Push payload should include delayed reply id")
assertContains(client, "\"deliverAt\": ISO8601DateFormatter().string(from: delayedReply.deliverAt)", "Push payload should include delivery timestamp")
assertContains(client, "\"minutes\": delayedReply.minutes", "Push payload should include delay minutes")
assertContains(client, "\"trigger\": delayedReply.trigger.rawValue", "Push payload should include trigger reason")
assertContains(docs, "推送通知后端合同", "Echo wait docs should mention backend push contract")
assertContains(docs, "/echo/delayed-replies", "Echo wait docs should document push endpoint")
assertContains(docs, "APNs", "Echo wait docs should keep APNs as an external acceptance gate")
assertContains(releasePackage, "echo-delayed-reply-push-contract-check.swift", "release QA package should include Echo push contract guard")
assertContains(releaseRegression, "echo-delayed-reply-push-contract-check.swift", "release regression should run Echo push contract guard")

print("Echo delayed reply push contract checks passed")
