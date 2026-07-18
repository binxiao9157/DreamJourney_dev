#!/usr/bin/env python3
"""Guard the default-off iOS Owner Truth Candidate review transport seam."""

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


def main() -> None:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "enum OwnerTruthCandidateReviewAction",
        "indirect enum OwnerTruthJSONValue",
        "struct OwnerTruthCandidateInboxItem",
        "struct OwnerTruthCandidateInbox",
        "struct OwnerTruthCandidateReviewCommand",
        "struct OwnerTruthCandidateDecisionResult",
        "enum OwnerTruthCandidateReviewQAGate",
        'static let launchArgument = "DJEnableOwnerTruthCandidateReviewQA"',
        "#if DEBUG || UI_QA_SIMULATOR",
        'return ProcessInfo.processInfo.arguments.contains(launchArgument)',
    ):
        require(required in contracts, f"Owner Truth candidate contract missing: {required}")

    require(
        "correct requires correctedValue and correctedValueSchemaVersion" in contracts,
        "correct action must fail closed without an immutable owner value",
    )
    require(
        "only correct may carry a corrected value" in contracts,
        "accept/reject must not leak a corrected owner value",
    )
    require(
        "accepted or corrected decisions require a MemoryVersion activation" in contracts,
        "candidate decision response must require MemoryVersion activation for owner acceptance",
    )
    require(
        "rejected or invalidated decisions must not activate memory" in contracts,
        "rejected candidate response must remain non-authoritative",
    )

    inbox_body = function_body(client, "fetchOwnerTruthCandidateInbox")
    decision_body = function_body(client, "reviewOwnerTruthCandidate")
    for body, path in (
        (inbox_body, 'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/candidates"'),
        (
            decision_body,
            'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/candidates/\\(pathComponent(candidateID.rawValue.uuidString))/decisions"',
        ),
    ):
        require("OwnerTruthCandidateReviewQAGate.isEnabled" in body, "QA gate missing from candidate request")
        require('"X-DreamJourney-QA-Owner-Truth": "1"' in body, "QA request header missing")
        require("authPolicy: .userRequired" in body, "candidate request must require a user session")
        require(path in body, f"candidate route drifted: {path}")

    require(
        'if normalizedPath.hasPrefix("/v2/vaults/") { return "ownerTruth" }' in client,
        "Owner Truth routes must retain a dedicated request purpose",
    )
    require(
        "func testCandidateInboxDecodesTypedProposalAndEvidence()" in tests,
        "typed Candidate Inbox parsing test missing",
    )
    require(
        "func testCandidateInboxRejectsMismatchedVault()" in tests,
        "Candidate Inbox vault-binding negative test missing",
    )
    require(
        "func testCorrectReviewCommandRequiresValueAndProducesOnlyCorrectPayload()" in tests,
        "corrected value command test missing",
    )
    require(
        "func testRejectDecisionDoesNotCreateMemoryVersion()" in tests,
        "rejected Candidate activation boundary test missing",
    )
    require(
        "func testAcceptedDecisionRejectsMissingMemoryVersionActivation()" in tests,
        "accepted Candidate activation negative test missing",
    )

    print(
        "Product V4 iOS Owner Truth candidate client check passed: typed inbox/decision "
        "contracts remain QA-only, owner-authenticated, and default-off"
    )


if __name__ == "__main__":
    main()
