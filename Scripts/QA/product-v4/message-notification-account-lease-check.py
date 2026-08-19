#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    delayed_store = read("DreamJourney/Sources/Services/EchoDelayedReplyStore.swift")
    scheduler = read("DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift")
    push_store = read("DreamJourney/Sources/Services/PushDeviceTokenStore.swift")
    app_delegate = read("DreamJourney/Sources/AppDelegate.swift")
    echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
    message_repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
    message_view = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
    authoritative_messages = read(
        "DreamJourney/Sources/Modules/Archive/AuthoritativeInAppMessageCenter.swift"
    )

    for snippet in (
        "private let accountLeaseRuntime: AccountLeaseRuntimePort",
        "accountLeaseRuntime.capture(forSubjectId: nil)",
        "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
        "storageKey(for: accountLease.subjectId)",
    ):
        require(snippet in delayed_store, f"delayed reply store lease isolation missing: {snippet}")
    require(
        "defaults.data(forKey: storageKey)" not in delayed_store,
        "delayed reply load must not read the unscoped legacy key",
    )

    require("accountLease: AccountLease" in scheduler, "notification scheduler lease input missing")
    for checkpoint in ("timer", "runtime", "ui"):
        require(
            re.search(
                rf"validate\((?:scope\.)?accountLease,\s*at:\s*\.{checkpoint}\)\.allowed",
                scheduler,
            ) is not None,
            f"notification scheduler lease checkpoint missing: {checkpoint}",
        )

    for snippet in (
        "func saveRegistration(",
        "accountLease: AccountLease",
        "registration.userId == accountLease.subjectId",
        "validate(accountLease, at: .commit).allowed",
    ):
        require(snippet in push_store, f"push registration commit guard missing: {snippet}")

    for snippet in (
        "let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId)",
        "AccountLeaseRuntime.shared.validate(accountLease, at: .commit).allowed",
        "PushDeviceTokenStore.shared.saveRegistration(",
        "accountLease: accountLease",
    ):
        require(snippet in app_delegate, f"AppDelegate push callback lease guard missing: {snippet}")

    for snippet in (
        "EchoDelayedReplyCallsiteContext",
        "private func validateDelayedReplyCallsiteContext(",
        "submitDelayedReplyPush(",
        "callsiteContext: EchoDelayedReplyCallsiteContext",
    ):
        require(snippet in echo, f"Echo delayed reply operation scope missing: {snippet}")
    for pattern in (
        r"requestAuthorizationIfNeeded\([\s\S]{0,280}?"
        r"resourceOwnerId:\s*callsiteContext\.resourceOwnerId,[\s\S]{0,160}?"
        r"operationId:\s*callsiteContext\.operationId,[\s\S]{0,160}?"
        r"accountLease:\s*callsiteContext\.accountLease",
        r"schedule\(\s*delayedReply,[\s\S]{0,280}?"
        r"resourceOwnerId:\s*callsiteContext\.resourceOwnerId,[\s\S]{0,160}?"
        r"operationId:\s*callsiteContext\.operationId,[\s\S]{0,160}?"
        r"accountLease:\s*callsiteContext\.accountLease",
    ):
        require(re.search(pattern, echo) is not None, f"Echo delayed reply lease call missing: {pattern}")
    schedule_start = echo.find("private func scheduleDelayedReplyNotificationIfNeeded")
    schedule_end = echo.find("private func submitDelayedReplyPush", schedule_start)
    require(schedule_start >= 0 and schedule_end > schedule_start, "Echo delayed reply schedule body missing")
    require(
        "capture(forSubjectId:" not in echo[schedule_start:schedule_end],
        "Echo delayed reply schedule must reuse the originating lease instead of recapturing",
    )

    for snippet in (
        "accountLease: AccountLease,",
        "isCurrentAccountLease(accountLease, at: .request)",
        "guard updateLocalInAppMessageState(updatedMessage, accountLease: accountLease) else",
        "private func updateLocalInAppMessageState(",
        ") -> Bool",
        "scope.storageKey(for: .localState)",
        "InAppMessageSourceEnvelope<InAppMessageLocalState>",
        "resourceOwnerId: resourceOwnerId",
        "operationId: message.id",
    ):
        require(snippet in message_repository, f"message mutation lease isolation missing: {snippet}")

    for snippet in (
        "private let accountLease: AccountLease",
        "AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed",
        "store.markRead(message: message, accountLease: accountLease)",
        "store.deleteRead(accountLease: accountLease)",
    ):
        require(snippet in message_view, f"message page captured lease missing: {snippet}")

    for snippet in (
        "private struct LeaseScope: Equatable",
        "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
        "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
        "scope == LeaseScope(accountLease)",
        "teardownForAccountLifecycle(oldAccountLease:",
    ):
        require(
            snippet in authoritative_messages,
            f"authoritative message lease isolation missing: {snippet}",
        )

    for snippet in (
        "item.ownerUserId == accountLease.subjectId",
        '"account-lease"',
        '"accountLeaseIdentity"',
        "resourceOwnerIdentity",
        "operationIdentity",
        "validate(accountLease, at: .runtime).allowed",
    ):
        require(snippet in message_repository, f"time-letter notification scope missing: {snippet}")
    require(
        'let identifier = "time-letter-\\(item.id)"' not in message_repository,
        "time-letter notification must not use a global raw item identifier",
    )
    time_letter_scheduler = message_repository[message_repository.find("final class TimeLetterReminderScheduler"):]
    for raw_metadata in (
        '"archiveItemId": item.id',
        '"accountLeaseGenerationId": accountLease.generationId.uuidString',
        '"subjectId": accountLease.subjectId',
        '"resourceOwnerId": item.ownerUserId',
    ):
        require(
            raw_metadata not in time_letter_scheduler,
            f"time-letter notification must not expose raw scope metadata: {raw_metadata}",
        )

    for snippet in (
        "func inAppMessageCenterSnapshot(",
        "accountLease: AccountLease,",
        "isCurrentAccountLease(accountLease, at: .runtime)",
        "scope.storageKey(for: .timeLetterMailbox)",
        "InAppMessageSourceEnvelope<TimeLetterMailboxReminder>",
        "replaceCachedTimeLetterMailboxReminders(",
        "retireLegacyMailboxIfNeeded(accountLease: accountLease)",
        "retireLegacyInAppMessageStateIfNeeded(accountLease: accountLease)",
        "surface: .timeLetterMailbox",
        "surface: .localState",
    ):
        require(snippet in message_repository, f"message/mailbox generation scope missing: {snippet}")
    require(
        "timeLetterMailboxReminders(accountUserId:" not in message_repository,
        "time-letter mailbox must not read a subject-only cache",
    )
    update_start = message_repository.find("private func updateCachedTimeLetterMailboxReminder(")
    update_end = message_repository.find("private func localTimeLetterDetailItem(", update_start)
    require(
        update_start >= 0 and update_end > update_start,
        "time-letter mailbox update transaction is missing",
    )
    update_body = message_repository[update_start:update_end]
    require(
        "return withMessageStateLock" in update_body
        and update_body.find("return withMessageStateLock") < update_body.find("var reminders"),
        "time-letter mailbox read-modify-write must hold one lock for the full transaction",
    )

    print("Message/notification AccountLease check passed")


if __name__ == "__main__":
    main()
