#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
INBOX = ROOT / "DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
VIEW = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
VIEW_MODEL = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift"
REPOSITORY = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift"
TESTS = ROOT / "DreamJourneyTests/AudioOwnerLeaseModelTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def body_after(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing declaration: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated body: {marker}")


def main() -> None:
    inbox = INBOX.read_text()
    client = CLIENT.read_text()
    view = VIEW.read_text()
    view_model = VIEW_MODEL.read_text()
    repository = REPOSITORY.read_text()
    tests = TESTS.read_text()

    protocol = body_after(inbox, "protocol EchoReplyMessageSource")
    require(
        "var echoReplySourceAnswerID: String? { get }" in protocol,
        "Echo Inbox source must retain only a private Answer pointer",
    )
    echo_mapping = body_after(inbox, "static func fromEchoReply(")
    require("metadataOnly: true" in echo_mapping, "Echo Inbox must remain metadata-only")
    require("contentRedacted: true" in echo_mapping, "Echo Inbox must declare Answer content redacted")
    require("answer.body" not in echo_mapping, "Echo Inbox mapping must never contain private Answer body")

    require(
        "func saveArrivedReply(\n        id: String,\n        sourceAnswerID: String," in inbox,
        "Echo arrived pointer API must require a source Answer ID",
    )
    arrived = body_after(inbox, "func saveArrivedReply(\n        id: String,")
    for snippet in (
        "normalizedSourceAnswerID",
        "!normalizedSourceAnswerID.isEmpty",
        "echoReplySourceAnswerID: normalizedSourceAnswerID",
    ):
        require(snippet in arrived, f"Echo arrived pointer is incomplete: {snippet}")
    require("answer.body" not in arrived, "Echo arrived pointer must not persist private Answer body")

    reference = body_after(inbox, "func inboxAnswerReference(")
    for snippet in (
        "message.kind == .echoReply",
        "accountLease.subjectId == normalizedOwnerId",
        "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
        "declaredOwner == normalizedOwnerId",
        "echoReplySourceAnswerID",
        "accountLeaseRuntime.validate(accountLease, at: .runtime).allowed",
    ):
        require(snippet in reference, f"Echo Inbox reference must fail closed: {snippet}")

    reader = body_after(client, "final class EchoDelayedReplyInboxAnswerReader")
    for snippet in (
        "isEnabled()",
        "ownerID == accountLease.subjectId",
        "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
        "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
        "contract.answer.answerID == sourceAnswerID",
        "contract.receipt.sourceAnswerID == sourceAnswerID",
        "EchoDelayedReplyInboxAnswerReadError.inboxPointerMismatch",
    ):
        require(snippet in reader, f"private Answer reader is incomplete: {snippet}")

    open_reply = body_after(view, "private func openEchoReplyMessage(\n        _ message: InAppMessage,")
    for snippet in (
        "EchoDelayedReplyAnswerReconciliationQAGate.isEnabled",
        "isEchoDelayedReplyAnswerReconciliationQAConfigured",
        "inboxAnswerReference(",
        "delayedReplyInboxAnswerReader.read",
        "presentQADelayedReplyAnswer",
    ):
        require(snippet in open_reply, f"QA-only Echo Answer opening missing: {snippet}")
    require(
        "openEchoReplyMessage()" in open_reply,
        "non-QA or legacy Echo pointers must retain ordinary Echo fallback",
    )

    reconciliation = body_after(view_model, "func reconcilePendingDelayedReplyAnswerIfQAGated(")
    require(
        "sourceAnswerID: answerContract.answer.answerID" in reconciliation,
        "reconciliation must persist the Answer pointer before retiring local pending state",
    )

    read_path = body_after(
        repository,
        "func markInAppMessageRead(\n        _ message: InAppMessage,\n        accountLease: AccountLease,",
    )
    archive_path = body_after(
        repository,
        "func archiveInAppMessage(\n        _ message: InAppMessage,\n        accountLease: AccountLease,",
    )
    for body, label, state_method in (
        (read_path, "read", "markingRead"),
        (archive_path, "archive", "markingArchived"),
    ):
        require("guard message.kind == .timeLetter else" in body, f"Echo {label} must use local scoped state")
        require(state_method in body, f"Echo {label} state transition missing")
        require("updateLocalInAppMessageState" in body, f"Echo {label} must persist across restart")

    for test_name in (
        "EchoDelayedReplyInboxAnswerReferenceTests",
        "EchoDelayedReplyInboxAnswerReaderTests",
        "testAnswerPointerSurvivesStoreRecreationAndInboxRemainsRedacted",
        "testReaderRejectsAnswerThatDoesNotMatchPersistedInboxPointer",
    ):
        require(test_name in tests, f"missing answer Inbox regression test: {test_name}")

    print("Echo delayed reply Answer Inbox static check passed")


if __name__ == "__main__":
    main()
