#!/usr/bin/env python3
"""Guard the closed-pilot owner-authored text Source capture transport."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
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


def main() -> None:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "struct OwnerTruthTextSourceCaptureCommand",
        "struct OwnerTruthTextSourceCaptureReceipt",
        "enum OwnerTruthTextSourceCaptureOutcome",
        "protocol OwnerTruthTextSourceCaptureClient",
        "private enum OwnerTruthTextSourceCaptureContract",
        'static let schemaVersion = "owner-truth-text-capture-response-v1"',
        'static let sourceReceiptSchemaVersion = "owner-truth-create-source-v1"',
        "static let maximumCharacterCount = 20_000",
        '"expectedAuthorityEpoch"',
        '"candidateExtraction"',
        '"content"',
    ):
        require(required in contracts, f"text Source contract missing: {required}")

    capture_body = function_body(client, "captureOwnerTruthTextSource")
    require(
        "requestFeatureDecision(for: .ownerTextCaptureV1)" in capture_body,
        "text Source write must use the separately captured release policy",
    )
    require(
        'path = "/v2/vaults/\\(pathComponent(vaultID.rawValue))/sources"' in capture_body,
        "text Source route drifted",
    )
    require("authPolicy: .userRequired" in capture_body, "text Source must require an owner session")
    require("featureDecision: decision" in capture_body, "captured policy must bind the request")
    require(
        "X-DreamJourney-QA-Owner-Truth" not in capture_body,
        "text Source write must not gain a QA-header bypass",
    )
    require(
        "extension DreamJourneyBackendClient: OwnerTruthTextSourceCaptureClient {}" in client,
        "backend client must conform to the typed text Source port",
    )
    require(
        "pathComponents.count == 4" in client
        and 'pathComponents[3] == "sources"' in client
        and "return .ownerTextCaptureV1" in client,
        "request feature mapping must classify only the exact vault Source route",
    )

    require("case ownerTextCaptureV1" in feature_flags, "feature enum missing owner text capture")
    nonpersistent_start = feature_flags.find("private static let nonPersistentFeatures")
    require(nonpersistent_start >= 0, "nonpersistent feature policy missing")
    nonpersistent_end = feature_flags.find("]", nonpersistent_start)
    require(
        ".ownerTextCaptureV1" in feature_flags[nonpersistent_start:nonpersistent_end],
        "text Source feature must remain nonpersistent/default-off",
    )

    for test_name in (
        "func testTextSourceCaptureCommandProducesExactClosedPilotPayload()",
        "func testTextSourceCaptureCommandRejectsInvalidAuthorityTextAndPurpose()",
        "func testTextSourceCaptureReceiptIsValueMinimizedAndRejectsLeakedContent()",
    ):
        require(test_name in tests, f"text Source test missing: {test_name}")

    print("Owner Truth text Source capture iOS contract check passed")


if __name__ == "__main__":
    main()
