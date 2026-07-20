#!/usr/bin/env python3
"""Verify that TimeLetter local notifications are retired by old lease only."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
REPOSITORY = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift"
LIFECYCLE = ROOT / "DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift"
INVENTORY = ROOT / "Scripts/QA/product-v4/legacy-timer-callback-inventory-v1.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing signature: {signature}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing body: {signature}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1:index]
    raise AssertionError(f"unterminated body: {signature}")


def main() -> None:
    repository = read(REPOSITORY)
    lifecycle = read(LIFECYCLE)
    inventory = read(INVENTORY)

    for snippet in (
        "protocol TimeLetterReminderNotificationRequestCenter",
        "extension UNUserNotificationCenter: TimeLetterReminderNotificationRequestCenter {}",
        "private let requestCenter: TimeLetterReminderNotificationRequestCenter",
        "init(\n        requestCenter: TimeLetterReminderNotificationRequestCenter,",
        "func teardownForAccountLifecycle(\n        oldAccountLease: AccountLease?",
    ):
        require(snippet in repository, f"TimeLetter notification lifecycle seam missing: {snippet}")

    teardown = body(repository, "func teardownForAccountLifecycle(\n        oldAccountLease: AccountLease?")
    require("accountLeaseRuntime" not in teardown, "old lease teardown must not consult current runtime")
    require(
        teardown.count("getPendingNotificationRequests") >= 2,
        "TimeLetter teardown must verify pending-request removal before success",
    )
    require("requestIsOwned(request, byLifecycleLease: oldAccountLease)" in teardown, "TimeLetter teardown must filter only the old lease")
    require("completion(false)" in teardown, "TimeLetter teardown must expose failure")

    schedule = body(repository, "func scheduleIfNeeded(_ item: MemoryArchiveItem)")
    require(
        "accountLeaseRuntime.capture(forSubjectId: nil)" in schedule,
        "TimeLetter scheduling must capture its lease through the injected runtime port",
    )

    ownership = body(repository, "private func requestIsOwned(\n        _ request: UNNotificationRequest,\n        byLifecycleLease")
    for snippet in (
        'request.identifier.hasPrefix("dj.timeLetter.reminder.")',
        'userInfo["kind"] as? String == "timeLetter"',
        'userInfo["accountLeaseIdentity"] as? String == Self.accountLeaseIdentity(for: accountLease)',
        'userInfo["resourceOwnerIdentity"] as? String',
        'userInfo["operationIdentity"] as? String',
    ):
        require(snippet in ownership, f"TimeLetter teardown ownership proof missing: {snippet}")

    lifecycle_teardown = body(lifecycle, "private static func teardownMessageNotificationEffects(")
    require(
        "TimeLetterReminderScheduler.shared.teardownForAccountLifecycle" in lifecycle_teardown,
        "account lifecycle must request TimeLetter notification teardown",
    )
    require(
        "timeLetterNotificationsCompleted" in lifecycle_teardown
        and "timeLetterNotificationsCleared" in lifecycle_teardown,
        "lifecycle result must fail closed when TimeLetter notification teardown is incomplete",
    )
    require(
        "known gap: no dedicated account-lifecycle cancellation" not in inventory
        and "account-lifecycle teardown is implemented" in inventory,
        "timer inventory must record the implemented TimeLetter lifecycle teardown",
    )
    print("TimeLetter notification lifecycle static check passed")


if __name__ == "__main__":
    main()
