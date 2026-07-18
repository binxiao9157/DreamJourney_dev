#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
VIEW_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
MODEL_SMOKE = ROOT / "Scripts/QA/product-v4/in-app-message-page-account-lease-model-smoke.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def compact(value: str) -> str:
    return "".join(value.split())


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    normalized = compact(source)
    for snippet in snippets:
        require(compact(snippet) in normalized, f"{label} missing: {snippet}")


def function_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing function: {marker}")
    opening = source.find("{", start + len(marker))
    require(opening >= 0, f"missing function body: {marker}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated function: {marker}")


def require_order(source: str, snippets: tuple[str, ...], label: str) -> None:
    cursor = -1
    for snippet in snippets:
        next_cursor = source.find(snippet, cursor + 1)
        require(next_cursor >= 0, f"{label} missing ordered step: {snippet}")
        cursor = next_cursor


def main() -> None:
    require(VIEW_CONTROLLER.is_file(), "MemoryArchiveViewController.swift is missing")
    require(MODEL_SMOKE.is_file(), "AccountLease page model smoke is missing")
    source = VIEW_CONTROLLER.read_text()
    model = MODEL_SMOKE.read_text()

    center_start = source.find("private final class InAppMessageCenterViewController")
    center_end = source.find("private final class InAppMessageCell", center_start)
    require(center_start >= 0 and center_end > center_start, "message center declaration is missing")
    center = source[center_start:center_end]
    require_all(
        center,
        (
            "private let accountLease: AccountLease",
            "private let snapshotProvider: (AccountLease) -> InAppMessageCenterSnapshot?",
            "self.accountLease = accountLease",
            "self.snapshotProvider = snapshotProvider",
            "failClosedForStaleAccountLease()",
        ),
        "message center fixed lease",
    )
    require(
        "repository.inAppMessageCenterSnapshot" not in center,
        "message center must refresh only through its complete snapshot provider",
    )
    require("replaceLocalMessage" not in center, "message page must not apply optimistic local rows")

    view_will_appear = function_body(center, "override func viewWillAppear")
    require(
        "refreshMessagesFromRepository()" in view_will_appear,
        "viewWillAppear must reload through the fixed-lease provider",
    )
    refresh = function_body(center, "private func refreshMessagesFromRepository")
    require_all(
        refresh,
        (
            "validate(accountLease, at: .ui).allowed",
            "let snapshot = snapshotProvider(accountLease)",
            "messages = snapshot.messages",
            "failClosedForStaleAccountLease()",
        ),
        "complete message refresh",
    )
    require(
        refresh.count("validate(accountLease, at: .ui).allowed") >= 2,
        "message refresh must validate the lease before and after snapshot evaluation",
    )

    read = function_body(center, "private func markMessageReadAndOpen")
    require_order(
        read,
        (
            "repository.markInAppMessageRead(message, accountLease: accountLease)",
            "case .success(let updated):",
            "refreshMessagesFromRepository()",
            "onMessageStateChanged(self.accountLease)",
            "onOpenMessage(updated, self.accountLease)",
        ),
        "read success flow",
    )
    require("markingRead" not in read, "message page must not optimistically mark rows read")

    archive = function_body(center, "private func archiveMessage")
    require_order(
        archive,
        (
            "repository.archiveInAppMessage(message, accountLease: accountLease)",
            "case .success:",
            "refreshMessagesFromRepository()",
            "onMessageStateChanged(self.accountLease)",
            "completion?(true)",
        ),
        "archive success flow",
    )
    require("markingArchived" not in archive, "message page must not optimistically archive rows")

    tap = function_body(source, "@objc private func timeLetterReminderTapped")
    require_order(
        tap,
        (
            "captureInAppMessageCenterAccountLease(at: .request)",
            "let snapshotProvider",
            "snapshotProvider(accountLease)",
            "presentInAppMessageCenter(",
            "accountLease: accountLease",
            "snapshotProvider: snapshotProvider",
        ),
        "parent capture/snapshot/present flow",
    )

    snapshot = function_body(source, "private func currentInAppMessageCenterSnapshot")
    require_all(
        snapshot,
        (
            "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
            "let familyInvitationSources = FamilyRepository.shared.getAll()",
            "let careSignalSources = currentCareSignalMessageSources(accountLease: accountLease)",
            "let echoReplySources = EchoReplyMessageStore.shared.inboxSources(",
            "accountLease: accountLease",
            "let systemNoticeSources = SystemNoticeMessageStore.shared.sources(",
            "accountLeaseRuntime.validate(accountLease, at: .runtime).allowed",
            "repository.inAppMessageCenterSnapshot(",
            "accountLease: accountLease",
            "familyInvitationSources: familyInvitationSources",
            "careSignalSources: careSignalSources",
            "echoReplySources: echoReplySources",
            "systemNoticeSources: systemNoticeSources",
            "accountLeaseRuntime.validate(accountLease, at: .ui).allowed",
        ),
        "fixed-lease complete snapshot provider",
    )
    require(
        "EchoReplyMessageStore.shared.sources()" not in snapshot
        and "SystemNoticeMessageStore.shared.sources()" not in snapshot,
        "snapshot provider must not recapture a lease through no-argument source wrappers",
    )

    present = function_body(source, "private func presentInAppMessageCenter")
    require_all(
        present,
        (
            "accountLeaseRuntime.validate(accountLease, at: .ui).allowed",
            "accountLease: accountLease",
            "snapshotProvider: snapshotProvider",
        ),
        "fixed-lease presentation",
    )
    require("capture(" not in present, "presentation must retain, not recapture, its account lease")

    require(
        source.count("repository.markInAppMessageRead(") == 1,
        "only the message page may submit the read mutation",
    )
    require(
        "repository.markTimeLetterMailboxReminderRead(" not in source,
        "time-letter opening must not duplicate the page read mutation",
    )
    require(
        "repository.inAppMessageCenterSnapshot()" not in source,
        "no-argument message snapshots can erase non-time-letter sources",
    )

    require_all(
        model,
        (
            "let leaseB = Lease(",
            "let leaseANextGeneration = Lease(",
            "let leaseASameGenerationNewIdentity = Lease(",
            "let leaseASessionRefreshed = Lease(",
            "Set(MessageKind.allCases)",
            "runtime.active = leaseB",
            "runtime.active = leaseANextGeneration",
            "runtime.active = leaseASessionRefreshed",
            "precondition(pageA.messages.isEmpty)",
            "precondition(Set(pageA.messages.map(\\.id)) == expectedAIds)",
        ),
        "AccountLease model coverage",
    )

    print("In-app message page AccountLease static check passed")


if __name__ == "__main__":
    main()
