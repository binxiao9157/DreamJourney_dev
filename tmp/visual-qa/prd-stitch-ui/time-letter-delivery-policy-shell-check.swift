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
        fatalError("\(message): unexpected \(needle)")
    }
}

let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let hiddenShellRunner = read("tmp/visual-qa/prd-stitch-ui/run-archive-hidden-shell-smoke.sh")
let backendSmoke = read("tmp/visual-qa/prd-stitch-ui/backend-time-letter-lifecycle-smoke.py")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-time-letter-delivery-policy-shell.md")

for required in [
    "timeLetterDeliveryExecutionStateMetadataKey",
    "timeLetterDeliveryDecisionStateMetadataKey",
    "timeLetterDeliveryScheduleStateMetadataKey",
    "timeLetterDeliveryProviderStateMetadataKey",
    "timeLetterNotificationScheduledMetadataKey",
    "isTimeLetterDeliveryDisabledUntilProductDecision",
    "archiveBackendPayload",
    "payload[\"deliveryExecutionState\"]",
    "payload[\"deliveryDecisionState\"]",
    "payload[\"deliveryScheduleState\"]",
    "payload[\"deliveryProviderState\"]",
    "payload[\"deliveryNotificationScheduled\"]",
] {
    assertContains(item, required, "time-letter item should pin non-delivery policy contract \(required)")
}

for required in [
    "\"deliveryExecutionState\": \"not_delivering\"",
    "\"deliveryDecisionState\": \"waiting_product_decision\"",
    "\"deliveryScheduleState\": \"not_scheduled\"",
    "\"deliveryProviderState\": \"disabled_until_product_decision\"",
    "\"deliveryNotificationScheduled\": \"false\"",
] {
    assertContains(factory, required, "time-letter factory should emit non-delivery metadata \(required)")
    assertContains(item, required, "time-letter lifecycle updates should preserve non-delivery metadata \(required)")
}

for required in [
    "(\"投递状态\", \"暂不投递\")",
    "(\"决策状态\", \"等待产品决策\")",
    "(\"通知状态\", \"未调度通知\")",
] {
    assertContains(display, required, "time-letter metadata rows should expose delivery boundary \(required)")
}

for required in [
    "archive-time-letter-delivery-disabled-state",
    "archive-time-letter-product-decision-state",
    "archive-time-letter-notification-not-scheduled-state",
    "暂不投递",
    "等待产品决策",
    "不会调度本地通知或 APNs",
] {
    assertContains(detail, required, "time-letter detail UI should expose delivery policy shell \(required)")
}

for forbidden in [
    "UNUserNotificationCenter.current().add",
    "EchoDelayedReplyNotificationScheduler",
    "registerForRemoteNotifications",
] {
    assertNotContains(detail, forbidden, "time-letter detail must not schedule notification delivery")
}

for required in [
    "timeLetterDraftDeliveryPolicyPersisted",
    "timeLetterSealedDeliveryPolicyPersisted",
    "timeLetterBackendPayloadNonDelivering",
    "timeLetterDeliveryPolicyVisible",
    "archive-time-letter-delivery-disabled-state",
    "archive-time-letter-product-decision-state",
] {
    assertContains(appDelegate, required, "hidden shell UIQA should verify time-letter delivery policy \(required)")
}

for required in [
    "\"timeLetterDraftDeliveryPolicyPersisted\"",
    "\"timeLetterSealedDeliveryPolicyPersisted\"",
    "\"timeLetterBackendPayloadNonDelivering\"",
    "\"timeLetterDeliveryPolicyVisible\"",
] {
    assertContains(hiddenShellRunner, required, "hidden shell runner should assert delivery policy \(required)")
}

for required in [
    "\"deliveryExecutionState\": \"not_delivering\"",
    "\"deliveryDecisionState\": \"waiting_product_decision\"",
    "\"deliveryScheduleState\": \"not_scheduled\"",
    "\"deliveryProviderState\": \"disabled_until_product_decision\"",
    "\"deliveryNotificationScheduled\": \"false\"",
] {
    assertContains(backendSmoke, required, "backend time-letter smoke should send delivery policy \(required)")
}

assertContains(
    releaseRegression,
    "time-letter-delivery-policy-shell-check.swift",
    "release regression should run delivery policy shell guard"
)
assertContains(
    releaseQA,
    "time-letter-delivery-policy-shell-check.swift",
    "release QA package should include delivery policy shell guard"
)

for required in [
    "时间信件 Delivery Policy Shell",
    "暂不投递",
    "等待产品决策",
    "不做真实通知/投递",
    "RUN_ARCHIVE_HIDDEN_SHELL_SMOKE",
] {
    assertContains(statusDoc, required, "status doc should document time-letter delivery policy shell \(required)")
}

print("Time-letter delivery policy shell checks passed")
