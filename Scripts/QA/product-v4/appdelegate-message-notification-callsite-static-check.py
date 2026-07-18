#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    require(start_index >= 0, f"missing function start: {start}")
    end_index = source.find(end, start_index)
    require(end_index >= 0, f"missing function end marker: {end}")
    return source[start_index:end_index]


def initializer_blocks(source: str, name: str) -> list[str]:
    blocks: list[str] = []
    cursor = 0
    marker = f"{name}("
    while True:
        start = source.find(marker, cursor)
        if start < 0:
            return blocks
        depth = 0
        index = start + len(name)
        while index < len(source):
            character = source[index]
            if character == "(":
                depth += 1
            elif character == ")":
                depth -= 1
                if depth == 0:
                    blocks.append(source[start : index + 1])
                    cursor = index + 1
                    break
            index += 1
        else:
            raise AssertionError(f"unterminated initializer: {name}")


def main() -> None:
    source = APP_DELEGATE.read_text()
    delayed = function_body(
        source,
        "func runEchoDelayedReplyNotificationSmoke()",
        "func selectProfileTabForCareEscalationSmoke",
    )
    messages = function_body(
        source,
        "func runTimeLetterDispatchReminderSmoke()",
        "func runArchiveFailedAnalysisRetrySmoke",
    )

    for snippet in (
        "AccountLeaseRuntime.shared.capture(forSubjectId: userId)",
        "let resourceOwnerId = accountLease.subjectId",
        'let roleContextKey = "uiqa-echo-delayed-reply-role"',
        "let notificationOperationId = callsiteContext.operationId",
        "callsiteContext.accountLease == accountLease",
        "callsiteContext.resourceOwnerId == resourceOwnerId",
        "callsiteContext.operationId == delayedReply.id",
        "callsiteContext.roleContextKey == roleContextKey",
        "EchoDelayedReplyNotificationScheduler.notificationIdentifier(",
        "resourceOwnerId: resourceOwnerId",
        "operationId: notificationOperationId",
        "accountLease: accountLease",
        "requests.first { $0.identifier == identifier }",
        "let pendingNotificationIdentifierMatched = expectedNotificationIdentifier.map {",
        "pendingRequest?.identifier == $0",
        'userInfo["accountSubjectIdentity"]',
        'userInfo["accountLeaseGeneration"]',
        'userInfo["accountLeaseGenerationIdentity"]',
        'userInfo["accountLeaseVaultIdentity"]',
        'userInfo["accountLeaseAuthorityEpochIdentity"]',
        'userInfo["resourceOwnerIdentity"]',
        'userInfo["operationIdentity"]',
        "let rawNotificationMetadataValues = [",
        "let expectedNotificationUserInfoKeys: Set<String> = [",
        "let rawNotificationMetadataKeys: Set<String> = [",
        "notificationUserInfoKeys == expectedNotificationUserInfoKeys",
        "rawNotificationFieldsAbsent",
        "!containsRawNotificationMetadata",
    ):
        require(snippet in delayed, f"delayed reply AppDelegate callsite missing: {snippet}")

    require(
        re.search(
            r"schedule\(\s*delayedReply,\s*resourceOwnerId:\s*resourceOwnerId,"
            r"\s*operationId:\s*notificationOperationId,\s*accountLease:\s*accountLease",
            delayed,
        )
        is not None,
        "delayed reply smoke must schedule with one captured owner scope",
    )
    require(
        "EchoDelayedReplyNotificationScheduler.notificationIdentifier ==" not in delayed,
        "delayed reply smoke must not assume the legacy global identifier",
    )
    require(
        "viewModel.finishUserVoice(text:" not in delayed,
        "delayed reply smoke must pass the originating account lease explicitly",
    )
    require(
        re.search(
            r"restoreStoredDelayedReplyIfAvailable\(\s*accountLease:\s*accountLease,"
            r"\s*resourceOwnerId:\s*resourceOwnerId,\s*roleContextKey:\s*roleContextKey,",
            delayed,
        )
        is not None,
        "delayed reply smoke restore must reuse the originating scope",
    )
    require(
        "EchoDelayedReplyStore.shared.load()" not in delayed,
        "delayed reply smoke must not verify cleanup through the legacy global wrapper",
    )
    require(
        "$0.identifier == EchoDelayedReplyNotificationScheduler.notificationIdentifier" not in delayed,
        "pending request lookup must use the derived scoped identifier",
    )
    require(
        "!rawNotificationMetadataValues.contains { identifier.contains($0) }" in delayed,
        "notification identifier smoke must reject every raw identity/operation value",
    )
    raw_values = re.search(
        r"let rawNotificationMetadataValues = \[([\s\S]*?)\]\.filter",
        delayed,
    )
    require(raw_values is not None, "notification smoke raw-value denylist is missing")
    for raw_value in (
        "accountLease.subjectId",
        "accountLease.vaultId",
        "accountLease.sessionId",
        "accountLease.authorityEpoch",
        "accountLease.generationId.uuidString",
        "resourceOwnerId",
        "delayedReply.id",
        "notificationOperationId",
    ):
        require(
            raw_value in raw_values.group(1),
            f"notification smoke raw-value denylist omits: {raw_value}",
        )
    raw_keys = re.search(
        r"let rawNotificationMetadataKeys: Set<String> = \[([\s\S]*?)\]",
        delayed,
    )
    require(raw_keys is not None, "notification smoke raw-key denylist is missing")
    for raw_key in (
        "subjectId",
        "vaultId",
        "sessionId",
        "authorityEpoch",
        "generationId",
        "accountLeaseGenerationId",
        "resourceOwnerId",
        "delayedReplyId",
        "operationId",
    ):
        require(
            f'"{raw_key}"' in raw_keys.group(1),
            f"notification smoke raw-key denylist omits: {raw_key}",
        )
    for raw_contract in (
        'userInfo["delayedReplyId"] as? String == delayedReply.id',
        'userInfo["accountLeaseGenerationId"] as? String',
    ):
        require(
            raw_contract not in delayed,
            f"notification smoke must reject the old raw metadata contract: {raw_contract}",
        )

    expired_save = re.search(
        r"EchoDelayedReplyStore\.shared\.save\(\s*expiredDelayedReply,"
        r"\s*resourceOwnerId:\s*callsiteContext\.resourceOwnerId,"
        r"\s*operationId:\s*callsiteContext\.operationId,"
        r"\s*accountLease:\s*callsiteContext\.accountLease",
        delayed,
    )
    require(expired_save is not None, "expired restore smoke must stage a real scoped expired reply")
    require(
        "id: delayedReply.id" in delayed,
        "expired restore smoke must replace the stored operation rather than use a fake wrapper key",
    )
    explicit_restores = re.findall(
        r"restoreStoredDelayedReplyIfAvailable\(\s*accountLease:\s*accountLease,"
        r"\s*resourceOwnerId:\s*resourceOwnerId,\s*roleContextKey:\s*roleContextKey,",
        delayed,
    )
    require(len(explicit_restores) == 2, "waiting and expired restore smokes must both use explicit scope")
    for compatibility_call in (
        "EchoDelayedReplyStore.shared.save(delayedReply)",
        "EchoDelayedReplyNotificationScheduler.shared.schedule(delayedReply)",
    ):
        require(
            compatibility_call not in delayed,
            f"delayed reply smoke must not restore a compatibility wrapper: {compatibility_call}",
        )

    for snippet in (
        "AccountLeaseRuntime.shared.capture(forSubjectId: userId)",
        "let resourceOwnerId = accountLease.subjectId",
        'let messageOperationId = "time-letter-dispatch-reminder-uiqa"',
        "EchoReplyMessageStore.shared.clear(",
        "EchoReplyMessageStore.shared.save(",
        "EchoReplyMessageStore.shared.sources(",
        ".replaceCachedTimeLetterMailboxReminders(",
        "mailboxFixtureInjectionSucceeded",
        "accountLease: accountLease",
        "resourceOwnerId: resourceOwnerId",
        "operationId: messageOperationId",
    ):
        require(snippet in messages, f"message UIQA callsite missing owner scope: {snippet}")

    system_sources = initializer_blocks(messages, "StaticSystemNoticeMessageSource")
    echo_sources = initializer_blocks(messages, "StaticEchoReplyMessageSource")
    require(len(system_sources) == 2, "expected two system notice UIQA fixtures")
    require(len(echo_sources) == 1, "expected one Echo reply UIQA fixture")
    for block in system_sources + echo_sources:
        require(
            "resourceOwnerId: resourceOwnerId" in block,
            "every system/Echo UIQA fixture must declare the authenticated resource owner",
        )

    for legacy_storage_key in (
        "dj.memoryArchive.timeLetterMailbox.",
        "dj.inAppMessage.localState.",
    ):
        require(
            legacy_storage_key not in messages,
            f"message smoke must not mutate legacy storage directly: {legacy_storage_key}",
        )
    require(
        re.search(
            r"replaceCachedTimeLetterMailboxReminders\(\s*\[reminder, secondReminder\],"
            r"\s*accountLease:\s*accountLease",
            messages,
        )
        is not None,
        "mailbox fixtures must be injected through the explicit generation-scoped repository API",
    )
    require(
        "&& mailboxFixtureInjectionSucceeded" in messages,
        "mailbox fixture injection result must gate smoke completion",
    )
    require(
        '"mailboxFixtureInjectionSucceeded": mailboxFixtureInjectionSucceeded' in messages,
        "mailbox fixture injection result must be written as smoke evidence",
    )
    snapshot_calls = initializer_blocks(messages, "inAppMessageCenterSnapshot")
    require(len(snapshot_calls) == 2, "expected two in-app message snapshot calls")
    for block in snapshot_calls:
        require(
            "accountLease: accountLease" in block,
            "in-app message snapshot calls must reuse the captured account lease explicitly",
        )

    print("AppDelegate message/notification callsite static check passed")


if __name__ == "__main__":
    main()
