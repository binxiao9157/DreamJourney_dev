#!/usr/bin/env python3
"""Guard the default-off iOS Owner Truth Context/Citation QA boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
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
        "enum OwnerTruthContextCitationQAGate",
        'static let launchArgument = "DJEnableOwnerTruthContextCitationQA"',
        "enum OwnerTruthContextShadowState",
        "enum OwnerTruthAnswerCitationOutcome",
        "struct OwnerTruthContextCitation",
        "struct OwnerTruthContextSourceReference",
        "struct OwnerTruthContextShadowItem",
        "struct OwnerTruthContextRankingTrace",
        "struct OwnerTruthContextCitationProof",
        "struct OwnerTruthContextShadowBuild",
        "struct OwnerTruthAnswerCitationReceipt",
        "struct OwnerTruthContextCitationTraceSummary",
        "struct OwnerTruthContextCitationQAEvidenceReadout",
        "protocol OwnerTruthContextCitationClient",
        "owner-truth-context-shadow-build-response-v1",
        "owner-truth-context-shadow-build-v1",
        "owner-truth-answer-citation-receipt-response-v1",
        "owner-truth-answer-citation-v1",
        "owner_truth_context_unavailable_no_personal_memory",
        "legacyContextRead",
        "rawContentKeys",
        "SHA256.hash(data: Data(text.utf8))",
        "owner-truth-context-citation-readout-v1",
        "contextHashDigest",
        "projectionCheckpointDigest",
        "selectedContextRefDigests",
        ):
        require(required in contracts, f"Owner Truth Context/Citation contract missing: {required}")

    require(
        "#if DEBUG || UI_QA_SIMULATOR" in contracts,
        "Context/Citation QA gate must remain unavailable in release builds",
    )
    require(
        "OwnerTruthContextCitationTraceSummary(context: self, receipt: receipt)" in contracts,
        "typed Context must export a value-free trace summary",
    )
    require(
        "legacyContextUnchanged, !legacyContextRead" in contracts,
        "Context QA response must reject legacy Context reads",
    )
    require(
        "selected and filtered Context refs must be disjoint" in contracts,
        "Context QA response must reject ambiguous selected/filtered evidence",
    )
    require(
        "answerCitation.contextHash does not match the selected Context" in contracts,
        "Answer receipt must bind the exact selected Context hash",
    )
    require(
        "answerCitation.answerHash does not match the submitted answer" in contracts,
        "Answer receipt must bind the submitted answer hash without storing text",
    )

    build_body = function_body(client, "buildOwnerTruthContextShadow")
    for required in (
        "OwnerTruthContextCitationQAGate.isEnabled",
        'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/context-shadow/build"',
        '"X-DreamJourney-QA-Owner-Truth": "1"',
        "authPolicy: .userRequired",
        "sessionUserId: expectedOwnerSubjectID",
        "OwnerTruthContextShadowBuild(",
    ):
        require(required in build_body, f"context shadow build boundary missing: {required}")

    receipt_body = function_body(client, "recordOwnerTruthAnswerCitationReceipt")
    for required in (
        "OwnerTruthContextCitationQAGate.isEnabled",
        'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/answer-citation-receipts"',
        '"X-DreamJourney-QA-Owner-Truth": "1"',
        "authPolicy: .userRequired",
        "sessionUserId: expectedOwnerSubjectID",
        "expectedContext.authority.vaultID == vaultID",
        "OwnerTruthAnswerCitationReceipt(",
    ):
        require(required in receipt_body, f"answer citation receipt boundary missing: {required}")

    require(
        "var isOwnerTruthContextCitationQAConfigured: Bool" in client,
        "runtime capability must expose only the QA-gated Context/Citation state",
    )
    require(
        "extension DreamJourneyBackendClient: OwnerTruthContextCitationClient {}" in client,
        "backend client must conform to the typed Context/Citation port",
    )
    require(
        "init(ownerTruthContextCitation summary: OwnerTruthContextCitationTraceSummary)" in client,
        "Echo evidence must have a value-free typed Context/Citation mapper",
    )

    readout_body = type_body(
        contracts,
        "struct OwnerTruthContextCitationQAEvidenceReadout",
    )
    for prohibited in (
        "let query:",
        "let answer:",
        "let memoryContent:",
        "let selectedContextRefs:",
        "let projectionCheckpoint:",
        "let contextHash:",
    ):
        require(
            prohibited not in readout_body,
            f"QA readout must not retain raw Context material: {prohibited}",
        )

    for test_name in (
        "func testContextShadowBuildAcceptsTypedProjectionCitationsWithoutRawContent()",
        "func testContextShadowBuildAcceptsJSONRoundTripNumberValues()",
        "func testContextShadowBuildRejectsBooleanAndFractionalJSONNumbers()",
        "func testContextShadowBuildRejectsRawMemoryValueAndCrossVaultCitation()",
        "func testAnswerCitationReceiptBindsExactContextWithoutStoringAnswerText()",
        "func testAnswerCitationReceiptRejectsChangedContextHash()",
        "func testContextCitationQAEvidenceReadoutHashesReferencesWithoutRawText()",
    ):
        require(test_name in tests, f"Context/Citation contract test missing: {test_name}")

    print(
        "Product V4 iOS Owner Truth Context/Citation check passed: QA-only, "
        "owner-authenticated typed citations reject raw values, cross-vault data, "
        "legacy reads, and changed Context hashes"
    )


if __name__ == "__main__":
    main()
