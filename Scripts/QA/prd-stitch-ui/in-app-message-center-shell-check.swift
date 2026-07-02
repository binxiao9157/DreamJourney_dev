#!/usr/bin/env swift

import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let url = URL(fileURLWithPath: root).appendingPathComponent(relativePath)
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fputs("Missing required file: \(relativePath)\n", stderr)
        exit(1)
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fputs("In-app message center shell check failed: \(message) (\(needle))\n", stderr)
        exit(1)
    }
}

let messageCenter = read("DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let archiveView = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let docs = read("docs/superpowers/status/2026-06-21-time-letter-public-delivery.md")

[
    "struct InAppMessage",
    "enum InAppMessageKind",
    "case timeLetter",
    "case familyInvitation",
    "case careSignal",
    "case systemNotice",
    "case echoReply",
    "enum InAppMessageStatus",
    "case unread",
    "case read",
    "case archived",
    "struct InAppMessageCenterSnapshot",
    "timeLetterReminder",
    "sourceArchiveItemId",
    "ownerUserId",
    "contentRedacted",
    "metadataOnly",
    "protocol FamilyInvitationMessageSource",
    "static func fromFamilyInvitation",
    "familyMemberId",
    "invitationStatus",
    "accessStatus",
    "protocol CareSignalMessageSource",
    "static func fromCareSignal",
    "careSignalId",
    "careSignalStatus",
    "careSignalSeverity",
    "protocol SystemNoticeMessageSource",
    "static func fromSystemNotice",
    "systemNoticeId",
    "systemNoticeCategory",
    "systemNoticeSeverity",
    "protocol EchoReplyMessageSource",
    "static func fromEchoReply",
    "echoReplyId",
    "echoReplyTrigger",
    "EchoReplyMessageStore",
].forEach {
    assertContains(messageCenter, $0, "unified model should include \($0)")
}

assertContains(
    messageCenter,
    "static func fromTimeLetterReminder",
    "time-letter mailbox reminder should map into unified in-app messages"
)
assertContains(
    messageCenter,
    "static func unavailableCandidate",
    "future family/care/system message types should have hidden candidate placeholders"
)
assertContains(
    messageCenter,
    "func entryButtonTitle(",
    "unified message center should own the Archive entry badge title"
)
assertContains(
    messageCenter,
    "isFamilyInvitationVisibleInMessageCenter",
    "accepted family members should not become noisy message-center invitations"
)
assertContains(
    messageCenter,
    "isCareSignalVisibleInMessageCenter",
    "only failed/stale/attention care states should become care-signal messages"
)
assertContains(
    messageCenter,
    "isSystemNoticeVisibleInMessageCenter",
    "only published system notices should become message-center notices"
)
assertContains(
    repository,
    "func inAppMessageCenterSnapshot(",
    "repository should expose a unified message center snapshot"
)
assertContains(
    repository,
    "familyInvitationMessages",
    "repository should aggregate real family invitation messages"
)
assertContains(
    repository,
    "careSignalMessages",
    "repository should aggregate care signal messages"
)
assertContains(
    repository,
    "systemNoticeMessages",
    "repository should aggregate system notice messages"
)
assertContains(
    repository,
    "echoReplyMessages",
    "repository should aggregate echo reply messages"
)
assertContains(
    repository,
    "func markInAppMessageRead",
    "repository should expose unified read mutation"
)
assertContains(
    repository,
    "func archiveInAppMessage",
    "repository should expose unified archive mutation"
)
assertContains(
    archiveView,
    "InAppMessageCenterViewController",
    "Archive UI should present the unified message center"
)
assertContains(
    archiveView,
    "archive-in-app-message-center",
    "Archive entry should use a unified message-center accessibility id"
)
assertContains(
    archiveView,
    "inAppMessageCenterSnapshot",
    "Archive UI should use the unified message snapshot"
)
assertContains(
    archiveView,
    "entryButtonTitle(",
    "Archive entry should render the unified unread badge from the snapshot"
)
assertContains(
    archiveView,
    "openInAppMessage",
    "Archive UI should route opened messages by type"
)
assertContains(
    archiveView,
    "familyInvitation",
    "family invitation message kind should route through the unified message center"
)
assertContains(
    archiveView,
    "openFamilyInvitationMessage",
    "family invitation messages should open family management context"
)
assertContains(
    archiveView,
    "careSignal",
    "care signal message kind should remain guarded in UI routing"
)
assertContains(
    archiveView,
    "openCareSignalMessage",
    "care signal messages should open care context instead of showing a placeholder toast"
)
assertContains(
    archiveView,
    "systemNotice",
    "system notice message kind should remain guarded in UI routing"
)
assertContains(
    archiveView,
    "openSystemNoticeMessage",
    "system notice messages should route through a minimal system notice handler"
)
assertContains(
    archiveView,
    "openEchoReplyMessage",
    "echo reply messages should open Echo and mark the reply read"
)
assertContains(
    archiveView,
    "EchoReplyMessageStore.shared.sources()",
    "Archive message center snapshot should include arrived Echo delayed replies"
)
assertContains(
    appDelegate,
    "inAppMessageCenterSnapshot",
    "UIQA smoke should assert the unified message center snapshot"
)
assertContains(
    appDelegate,
    "inAppMessageCenterKindCounts",
    "UIQA smoke should export message kind counts"
)
assertContains(
    appDelegate,
    "inAppMessageCenterEntryTitle",
    "UIQA smoke should export the unified entry badge title"
)
assertContains(
    appDelegate,
    "familyInvitationMessageCount",
    "UIQA smoke should export family invitation message count"
)
assertContains(
    appDelegate,
    "careSignalMessageCount",
    "UIQA smoke should export care signal message count"
)
assertContains(
    appDelegate,
    "systemNoticeMessageCount",
    "UIQA smoke should export system notice message count"
)
assertContains(
    appDelegate,
    "echoReplyMessageCount",
    "UIQA smoke should export echo reply message count"
)
assertContains(
    project,
    "InAppMessageCenter.swift",
    "new model should be included in the Xcode target"
)
assertContains(
    docs,
    "家庭邀请接入 InAppMessage",
    "time-letter status doc should document the family invitation provider"
)
assertContains(
    docs,
    "关怀提醒接入 InAppMessage",
    "time-letter status doc should document the care signal provider"
)
assertContains(
    docs,
    "系统通知接入 InAppMessage",
    "time-letter status doc should document the system notice provider"
)
assertContains(
    docs,
    "回响回信接入 InAppMessage",
    "time-letter status doc should document the echo reply provider"
)

print("In-app message center shell checks passed")
