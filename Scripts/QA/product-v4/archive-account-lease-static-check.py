#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def compact(value: str) -> str:
    return "".join(value.split())


def body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {signature}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated function body: {signature}")


def includes(function: str, snippets: tuple[str, ...], label: str) -> None:
    normalized = compact(function)
    for snippet in snippets:
        require(compact(snippet) in normalized, f"{label} missing: {snippet}")


def main() -> None:
    require(SOURCE_PATH.is_file(), "MemoryArchiveRepository production file is missing")
    source = SOURCE_PATH.read_text()

    includes(
        source,
        (
            "let accountLease: AccountLease",
            "private let accountLeaseRuntime = AccountLeaseRuntime.shared",
            "accountLeaseRuntime.capture(forSubjectId: accountUserId)",
            "accountLeaseRuntime.validate(lease.accountLease, at: checkpoint).allowed",
        ),
        "archive lease adapter",
    )

    refresh = body(source, "func refreshFromBackend(")
    includes(
        refresh,
        (
            "isCurrentArchiveStorageLease(lease, at: .request)",
            "isCurrentArchiveStorageLease(lease, at: .commit)",
            "lease: lease.accountLease",
            "completion: completion",
        ),
        "archive refresh",
    )
    require(
        "currentArchiveStorageLease" not in refresh[refresh.find("listArchiveItems") :],
        "archive refresh callback must keep its original lease",
    )

    sync = body(source, "private func syncToBackend(_ item: MemoryArchiveItem)")
    includes(
        sync,
        (
            "isCurrentArchiveStorageLease(lease, at: .request)",
            "isCurrentArchiveStorageLease(lease, at: .commit)",
            "markBackendSyncState(",
            "lease: lease",
        ),
        "archive upload",
    )

    detail = body(source, "func resolveTimeLetterReminderDetail(")
    includes(
        detail,
        (
            "isCurrentArchiveStorageLease(lease, at: .request)",
            "isCurrentArchiveStorageLease(lease, at: .commit)",
            "deliver(",
            "lease: lease.accountLease",
        ),
        "time-letter detail",
    )

    for signature in (
        "func markTimeLetterMailboxReminderRead(",
        "func markTimeLetterMailboxReminderArchived(",
    ):
        operation = body(source, signature)
        includes(
            operation,
            (
                "let accountLease = captureCurrentAccountLease()",
                "isCurrentAccountLease(accountLease, at: .commit)",
                "userId: accountLease.subjectId",
                "deliver(",
                "lease: accountLease",
            ),
            signature,
        )
        require(
            "userId: currentUserId" not in operation,
            f"{signature} must not re-read the current account for its request",
        )

    mailbox = body(source, "func refreshTimeLetterMailboxReminders(")
    includes(
        mailbox,
        (
            "let accountLease = captureCurrentAccountLease()",
            "isCurrentAccountLease(accountLease, at: .request)",
            "isCurrentAccountLease(accountLease, at: .commit)",
            "userId: accountLease.subjectId",
            "saveTimeLetterMailboxReminders(reminders, accountLease: accountLease)",
            "lease: accountLease",
        ),
        "mailbox refresh",
    )

    delivery = body(source, "private func deliver<T>(")
    require("at: .ui" in delivery, "archive completion must validate UI checkpoint")

    scheduler = body(source, "func scheduleIfNeeded(_ item: MemoryArchiveItem)")
    includes(
        scheduler,
        (
            "let accountLease = accountLeaseRuntime.capture()",
            "validate(accountLease, at: .timer)",
            "validate(accountLease, at: .runtime)",
            "notificationCenter.add(request)",
        ),
        "time-letter notification scheduler",
    )

    print("Archive AccountLease static check passed")


if __name__ == "__main__":
    main()
