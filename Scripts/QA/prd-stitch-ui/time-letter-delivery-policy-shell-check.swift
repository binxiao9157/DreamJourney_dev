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

let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let entry = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift")
let archiveRoot = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let backendSmoke = read("Scripts/QA/prd-stitch-ui/backend-time-letter-lifecycle-smoke.py")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let statusDoc = read("docs/superpowers/status/2026-06-21-time-letter-public-delivery.md")

assertContains(featureFlags, "case timeLetters", "time-letter feature should have an explicit feature flag")
assertContains(featureFlags, ".timeLetters", "time-letter should be public by default")
assertContains(featureFlags, "private static let currentStorageVersion", "feature-flag storage should keep a migration version without pinning a stale exact value")

for required in [
    "timeLetterOpenAtMetadataKey",
    "timeLetterRecipientIdsMetadataKey",
    "timeLetterRecipientNamesMetadataKey",
    "timeLetterSealedAtMetadataKey",
    "timeLetterDeliveryStatusMetadataKey",
    "archiveBackendPayload",
    "payload[\"openAt\"]",
    "payload[\"recipients\"]",
    "payload[\"sealedAt\"]",
    "payload[\"deliveryStatus\"]",
    "scheduled_local_and_in_app",
    "local_notification_and_in_app",
] {
    assertContains(item, required, "time-letter model should pin public delivery contract \(required)")
}

for required in [
    "makeTimeLetterDraft(",
    "makeTimeLetter(",
    "openAt: Date",
    "recipients: [TimeLetterRecipientSelection]",
    "imageLocalPath: String?",
    "scheduled_local_and_in_app",
] {
    assertContains(factory, required, "time-letter factory should create public delivery metadata \(required)")
}

for required in [
    "TimeLetterReminderScheduler",
    "UNUserNotificationCenter.current()",
    "UNNotificationRequest",
    "dueTimeLetters",
    "TimeLetterMailboxReminder",
    "refreshTimeLetterMailboxReminders",
    "resolveTimeLetterReminderDetail",
    "timeLetterReminderCount",
    "timeLetterDeliveryStatus != \"delivered\"",
    "if items.contains(where: { $0.id == id && $0.isSealedTimeLetter })",
] {
    assertContains(repository, required, "time-letter repository should schedule and protect sealed letters \(required)")
}

for required in [
    "TimeLetterEntryPayload",
    "UIDatePicker",
    "FamilyRepository.shared.getAll()",
    "UIImagePickerController",
    "time-letter-open-at-picker",
    "time-letter-image-picker-button",
    "封存后会按打开时间提醒本人和收件人。",
] {
    assertContains(entry, required, "time-letter entry UI should expose text/image/time/recipient controls \(required)")
}

for required in [
    "archive-time-letter-in-app-reminder",
    "timeLetterReminderCount()",
    "timeLetterReminderTapped",
    "openTimeLetterReminder",
    "MemoryArchiveDetailViewController(item:",
    "refreshTimeLetterMailboxReminders",
    "onSaveTimeLetter",
    "onSaveDraftTimeLetter",
] {
    assertContains(archiveRoot, required, "archive root should create and surface in-app time-letter reminders \(required)")
}

for required in [
    "已封存，不可删除或修改",
    "本地通知 + 应用内提醒",
    "这封信已封存，等待打开时间到来。",
    "MemoryArchiveTextEntryViewController(",
    "sealingTimeLetter(",
    "archive-time-letter-notification-state",
] {
    assertContains(detail, required, "time-letter detail should show sealed lock and reminder state \(required)")
}

for required in [
    "if kind == .timeLetter",
    "(\"信件状态\", \"已封存\")",
    "(\"打开时间\", openAt)",
    "(\"收件人\", metadataTimeLetterRecipientsDisplayName ?? \"我\")",
    "(\"提醒\", metadataTimeLetterDeliveryStatusDisplayName ?? \"草稿\")",
] {
    assertContains(display, required, "time-letter metadata should show only user-facing schedule fields \(required)")
}

for required in [
    "\"openAt\"",
    "\"recipients\"",
    "\"sealedAt\"",
    "\"deliveryStatus\"",
    "\"dispatchDue\"",
    "\"ownerMailbox\"",
    "\"recipientMailbox\"",
    "sealed timeLetter cannot be deleted",
] {
    assertContains(backendSmoke, required, "backend time-letter smoke should verify public delivery fields \(required)")
}

for required in [
    "func dispatchDueTimeLetters(",
    "/archive/time-letters/dispatch-due",
    "func listMailboxLetters(",
    "/mailbox/letters/",
    "func getTimeLetterDetail(",
    "/archive/time-letters/",
    "/detail",
] {
    assertContains(backendClient, required, "backend client should expose time-letter dispatch/mailbox contract \(required)")
}

assertContains(
    releaseRegression,
    "time-letter-delivery-policy-shell-check.swift",
    "release regression should run time-letter public delivery guard"
)

for forbidden in [
    "等待产品决策",
    "pending_product_decision",
    "disabled_until_product_decision",
    "不会调度本地通知或 APNs",
    "暂不支持视频和音频",
] {
    assertNotContains(entry, forbidden, "entry UI should not expose old non-delivery copy")
    assertNotContains(detail, forbidden, "detail UI should not expose old non-delivery copy")
}

for required in [
    "时间信件公开投递闭环",
    "openAt",
    "recipients",
    "sealedAt",
    "deliveryStatus",
] {
    assertContains(statusDoc, required, "status doc should document public time-letter delivery \(required)")
}

print("Time-letter public delivery checks passed")
