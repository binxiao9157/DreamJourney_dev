#!/usr/bin/env python3
"""Guard the hidden, value-minimized M0-B dimension confirmation client."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
SMOKE_SURFACE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
RUNNER = ROOT / "Scripts/QA/prd-stitch-ui/run-owner-truth-knowledge-dimension-confirmation-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def section(source: str, marker: str, next_marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing section: {marker}")
    end = source.find(next_marker, start)
    require(end >= 0, f"missing section terminator: {next_marker}")
    return source[start:end]


def main() -> None:
    for path in (CONTRACTS, CLIENT, FLAGS, DELEGATE, SMOKE_SURFACE, RUNNER):
        require(path.is_file(), f"missing M0-B dimension confirmation artifact: {path}")

    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    flags = FLAGS.read_text(encoding="utf-8")
    delegate = DELEGATE.read_text(encoding="utf-8")
    smoke_surface = SMOKE_SURFACE.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")

    for snippet in (
        "enum OwnerTruthKnowledgeDimensionConfirmationOutcome",
        "case created",
        "case deduplicated",
        "struct OwnerTruthKnowledgeDimensionConfirmationCommand",
        'static let confirmationMethod = "ownerExplicitSelection"',
        'static let uiSchemaVersion = "knowledge-dimension-review-v1"',
        "expectedContentHash",
        "coveredFacets = dimension.facetOrder.filter",
        "struct OwnerTruthKnowledgeDimensionConfirmationReceipt",
        'static let responseSchemaVersion = "owner-truth-knowledge-dimension-confirmation-response-v1"',
        'static let confirmationSchemaVersion = "owner-truth-knowledge-dimension-confirmation-v1"',
        "boundContentHash",
        "coveredFacets == expectedCommand.coveredFacets",
        "protocol OwnerTruthKnowledgeDimensionConfirmationClient",
        "private enum OwnerTruthKnowledgeDimensionConfirmationContract",
        "isOpaqueCommandID",
        "isSHA256Digest",
    ):
        require(snippet in contracts, f"M0-B dimension confirmation contract missing: {snippet}")

    receipt_properties = section(
        contracts,
        "struct OwnerTruthKnowledgeDimensionConfirmationReceipt: Equatable, Sendable",
        "    init(\n        backendJSONObject",
    )
    for forbidden in (
        "confirmationID",
        "memoryID",
        "memoryVersionID",
        "boundContentHash",
        "expectedContentHash",
        "content:",
        "narrative",
    ):
        require(
            forbidden not in receipt_properties,
            f"value-minimized confirmation receipt must not retain {forbidden}",
        )

    for snippet in (
        "func confirmOwnerTruthKnowledgeDimension(",
        "/knowledge-dimension-confirmations\"",
        "OwnerTruthCandidateReviewQAGate.isEnabled",
        'feature: "ownerTruthKnowledgeDimensionConfirmation"',
        '"X-DreamJourney-QA-Owner-Truth": "1"',
        "OwnerTruthKnowledgeDimensionConfirmationReceipt(",
        "extension DreamJourneyBackendClient: OwnerTruthKnowledgeDimensionConfirmationClient {}",
    ):
        require(snippet in client, f"M0-B QA confirmation transport missing: {snippet}")

    for snippet in (
        'case ownerTruthKnowledgeDimensionConfirmationSmoke = "DJRunOwnerTruthKnowledgeDimensionConfirmationSmoke"',
        ".ownerTruthKnowledgeDimensionConfirmationSmoke,",
    ):
        require(snippet in flags, f"M0-B confirmation scenario registry missing: {snippet}")

    for snippet in (
        "case .ownerTruthKnowledgeDimensionConfirmationSmoke:",
        "runOwnerTruthKnowledgeDimensionConfirmationSmoke()",
        "func runOwnerTruthKnowledgeDimensionConfirmationSmoke(",
        "OwnerTruthKnowledgeDimensionConfirmationUIQASmoke.run(accountLease: accountLease)",
    ):
        require(snippet in delegate, f"M0-B confirmation dispatcher missing: {snippet}")

    for snippet in (
        "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
        "struct OwnerTruthKnowledgeDimensionConfirmationUIQASmokeResult",
        "OwnerTruthKnowledgeDimensionConfirmationUIQAClient",
        "receiptRetainsOpaqueIdentifiers",
        "boundHashMismatchRejected",
        "malformedReceiptRejected",
        "qa-dimension-confirm-001",
        "replayReceipt.outcome == .deduplicated",
    ):
        require(snippet in smoke_surface, f"M0-B confirmation smoke missing: {snippet}")

    for snippet in (
        "DJRunOwnerTruthKnowledgeDimensionConfirmationSmoke",
        "DJEnableOwnerTruthCandidateReviewQA",
        '"createdOutcome"',
        '"replayOutcome"',
        '"receiptRetainsOpaqueIdentifiers"',
        '"boundHashMismatchRejected"',
        '"malformedReceiptRejected"',
    ):
        require(snippet in runner, f"M0-B confirmation smoke runner missing: {snippet}")

    print("Owner Truth knowledge dimension confirmation client check passed")


if __name__ == "__main__":
    main()
