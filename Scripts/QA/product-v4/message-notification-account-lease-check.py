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

    for snippet in (
        "accountLease: AccountLease",
        "validate(accountLease, at: .timer).allowed",
        "validate(accountLease, at: .runtime).allowed",
        "validate(accountLease, at: .ui).allowed",
    ):
        require(snippet in scheduler, f"notification scheduler lease checkpoint missing: {snippet}")

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
        "let accountLease = AccountLeaseRuntime.shared.capture(forSubjectId: userId)",
        "submitDelayedReplyPush(",
        "accountLease: accountLease",
    ):
        require(snippet in echo, f"Echo delayed reply operation lease missing: {snippet}")
    for pattern in (
        r"requestAuthorizationIfNeeded\(\s*accountLease:\s*accountLease",
        r"schedule\(\s*delayedReply,\s*accountLease:\s*accountLease",
    ):
        require(re.search(pattern, echo) is not None, f"Echo delayed reply lease call missing: {pattern}")

    print("Message/notification AccountLease check passed")


if __name__ == "__main__":
    main()
