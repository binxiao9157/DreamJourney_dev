#!/usr/bin/env python3
"""Guard the default-off iOS Owner Truth answer-correction boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
MODULES = ROOT / "DreamJourney/Sources/Modules"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.find(marker)
    require(start >= 0, f"missing function: {name}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {name}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def type_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing type: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing type body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated type: {marker}")


def main() -> None:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "enum OwnerTruthCorrectionRequestQAGate",
        'static let launchArgument = "DJEnableOwnerTruthCorrectionRequestQA"',
        "enum OwnerTruthCorrectionRequestOutcome",
        "enum OwnerTruthCorrectionRequestStatus",
        "struct OwnerTruthCorrectionRequestCommand",
        "struct OwnerTruthCorrectionRequestReceipt",
        "final class OwnerTruthCorrectionRequestUseCase",
        "protocol OwnerTruthCorrectionRequestClient",
        "owner-truth-correction-request-response-v1",
        "owner-truth-correction-request-v1",
        "pendingReview",
        "citationId must belong to the verified answer receipt",
        "correctionRequest identity does not match the submitted citation command",
        "correctionRequest correction text integrity does not match the submitted command",
    ):
        require(required in contracts, f"Owner Truth answer-correction contract missing: {required}")

    require(
        "#if DEBUG || UI_QA_SIMULATOR" in contracts,
        "answer correction QA gate must remain unavailable in release builds",
    )
    receipt_body = type_body(contracts, "struct OwnerTruthCorrectionRequestReceipt")
    for prohibited in (
        "let correctionText:",
        "let commandIDHash:",
        "let reasonCodeHash:",
    ):
        require(
            prohibited not in receipt_body,
            f"correction receipt must not retain unsupported or raw content: {prohibited}",
        )

    request_body = function_body(client, "requestOwnerTruthCorrection")
    for required in (
        "OwnerTruthCorrectionRequestQAGate.isEnabled",
        'feature: "ownerTruthCorrectionRequest"',
        "command.vaultID == vaultID",
        'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/memories/\\(pathComponent(command.memoryID.rawValue.uuidString))/corrections"',
        "payload: command.backendPayload",
        "authPolicy: .userRequired",
        "sessionUserId: expectedOwnerSubjectID",
        '"X-DreamJourney-QA-Owner-Truth": "1"',
        "OwnerTruthCorrectionRequestReceipt(",
    ):
        require(required in request_body, f"correction client boundary missing: {required}")

    require(
        "var isOwnerTruthCorrectionRequestQAConfigured: Bool" in client,
        "runtime capability must expose only the QA-gated correction state",
    )
    require(
        "extension DreamJourneyBackendClient: OwnerTruthCorrectionRequestClient {}" in client,
        "backend client must conform to the correction-request port",
    )

    for module in MODULES.rglob("*.swift"):
        require(
            "OwnerTruthCorrectionRequest" not in module.read_text(encoding="utf-8"),
            f"default-public module must not expose answer correction: {module.relative_to(ROOT)}",
        )

    for test_name in (
        "func testCorrectionRequestCommandBindsVerifiedCitationAndReceiptIsValueFree()",
        "func testCorrectionRequestReceiptRejectsRawCorrectionAnswerAndContent()",
        "func testCorrectionRequestReceiptRejectsMismatchedIdentityAndIntegrity()",
        "func testCorrectionRequestCommandRejectsInvalidInputAndUnknownCitation()",
        "func testCorrectionRequestUseCaseSubmitsPendingCandidateWithoutMutatingLegacyState()",
    ):
        require(test_name in tests, f"answer-correction contract test missing: {test_name}")

    print(
        "Product V4 iOS Owner Truth answer-correction check passed: default-off, "
        "owner-authenticated, citation-bound, value-free, and absent from public modules"
    )


if __name__ == "__main__":
    main()
