#!/usr/bin/env python3
"""Guard the default-off iOS Owner Truth Candidate review transport seam."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"
ARCHIVE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"


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
    archive = ARCHIVE.read_text(encoding="utf-8")
    app_delegate = APP_DELEGATE.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")

    for required in (
        "enum OwnerTruthCandidateReviewAction",
        "indirect enum OwnerTruthJSONValue",
        "struct OwnerTruthCandidateInboxItem",
        "struct OwnerTruthCandidateInbox",
        "struct OwnerTruthCandidateReviewHistory",
        "struct OwnerTruthCandidateReviewHistoryItem",
        "enum OwnerTruthCandidateMemoryActivationStatus",
        "struct OwnerTruthMemoryVersionHistory",
        "struct OwnerTruthMemoryVersionHistoryItem",
        "enum OwnerTruthMemoryVersionHistoryStatus",
        "struct OwnerTruthCandidateReviewCommand",
        "struct OwnerTruthCandidateDecisionResult",
        "enum OwnerTruthCandidateReviewQAGate",
        "protocol OwnerTruthCandidateReviewClient",
        "enum OwnerTruthCandidateReviewIntent",
        "struct OwnerTruthCandidateInboxViewState",
        "final class OwnerTruthCandidateReviewUseCase",
        "final class OwnerTruthCandidateReviewHistoryUseCase",
        "final class OwnerTruthMemoryVersionHistoryUseCase",
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
    require(
        "guard generation == operationGeneration else { return }" in contracts,
        "Candidate Inbox must reject stale async callbacks",
    )
    require(
        "accountLeaseRuntime.validate(accountLease, at: .request).allowed" in contracts,
        "Candidate Inbox must fence request work with AccountLease",
    )
    require(
        "accountLeaseRuntime.validate(accountLease, at: .commit).allowed" in contracts,
        "Candidate Inbox must fence completion work with AccountLease",
    )
    require(
        "decision.receipt.decision == expectedAction.terminalDecision" in contracts,
        "Candidate Inbox must reject a terminal receipt that mismatches the requested action",
    )

    inbox_body = function_body(client, "fetchOwnerTruthCandidateInbox")
    history_body = function_body(client, "fetchOwnerTruthCandidateReviewHistory")
    memory_history_body = function_body(client, "fetchOwnerTruthMemoryVersionHistory")
    decision_body = function_body(client, "reviewOwnerTruthCandidate")
    for body, path in (
        (inbox_body, 'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/candidates"'),
        (
            history_body,
            'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/candidate-review-history"',
        ),
        (
            memory_history_body,
            'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/memories/\\(pathComponent(memoryID.rawValue.uuidString))/versions"',
        ),
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
        "extension DreamJourneyBackendClient: OwnerTruthCandidateReviewClient {}" in client,
        "Concrete backend client must conform to the typed Candidate review port",
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
    require(
        "func testCandidateReviewHistoryDecodesTerminalAuditAndMemoryState()" in tests,
        "Candidate terminal review history parsing test missing",
    )
    require(
        "func testCandidateReviewHistoryUseCaseMapsOwnerAuditAndFencesAccountSwitch()" in tests,
        "Candidate review history lease-fencing test missing",
    )
    require(
        "func testMemoryVersionHistoryMapsCurrentAndSupersededVersionsWithLeaseFence()" in tests,
        "MemoryVersion history parser and lease-fencing test missing",
    )
    for test_name in (
        "func testCandidateReviewUseCaseMapsInboxAndAcceptsThroughTypedReceipt()",
        "func testCandidateReviewUseCasePreservesCandidateContentForCorrection()",
        "func testCandidateReviewUseCaseRejectsStaleCompletionAfterAccountSwitch()",
        "func testCandidateReviewUseCaseRejectsMismatchedTerminalDecision()",
        "func testCandidateReviewUseCaseAcceptsOnlySelectedBatchCandidatesIndividually()",
        "func testCandidateReviewUseCaseStopsPartialBatchOnConflictAndRetainsStableRetryCommand()",
        "func testCandidateReviewUseCaseRejectsSingleCandidateBatchSelectionAndClassifiesInactiveSource()",
    ):
        require(test_name in tests, f"Candidate review use-case test missing: {test_name}")

    for required in (
        "private let candidateReviewQAButton = UIButton(type: .system)",
        "configureCandidateReviewQAButton()",
        "updateCandidateReviewQAButton()",
        "@objc private func ownerTruthCandidateReviewQATapped()",
        "OwnerTruthCandidateInboxViewController(accountLease: accountLease)",
        "final class OwnerTruthCandidateInboxViewController",
        "OwnerTruthCandidateReviewUseCase",
        "owner-truth-candidate-inbox-list",
        "owner-truth-candidate-inbox-item",
        "OwnerTruthCandidateInboxUIQASmoke",
        "runUIQAAcceptFirstCandidate",
        "runUIQAAcceptAllBatchCandidates",
        "CandidateInboxUIQAScenario",
        "reviewSubmitted",
        "candidateRemovedAfterReview",
        "supportsBatchAcceptance",
        "batchSequenceCompleted",
        "final class OwnerTruthCandidateReviewHistoryViewController",
        "owner-truth-candidate-review-history-open",
        "owner-truth-candidate-review-history-list",
        "reviewHistoryVisible",
        "reviewHistoryTerminalStatesVisible",
        "reviewHistoryMemoryStateVisible",
        "final class OwnerTruthMemoryVersionHistoryViewController",
        "owner-truth-memory-version-history-list",
        "当前版本",
        "历史版本",
        "memoryVersionHistoryVisible",
        "memoryVersionHistoryCurrentStateVisible",
    ):
        require(required in archive, f"Candidate Inbox QA UI missing: {required}")
    require(
        "let isVisible = isSelfAutobiographyMode && (" in archive
        and "isServerPolicyManagedClosedPilotRouteAllowed(.ownerTruthCandidateReview)" in archive,
        "Candidate Inbox must require self mode plus QA or server-granted closed-pilot policy",
    )
    require(
        "candidateReviewQAButton.isHidden = !isVisible" in archive,
        "Candidate Inbox must remain default-hidden",
    )
    require(
        "OwnerTruthCandidateReviewQAGate.isEnabled\n                    || FeatureGateService.shared" in archive,
        "Candidate Inbox route must enforce QA or server-granted closed-pilot policy at the tap boundary",
    )
    for required in (
        "case acceptBatch(candidateIDs: [OwnerTruthRecordID])",
        "case submittingBatch(completedCount: Int, totalCount: Int)",
        "struct OwnerTruthCandidateBatchReviewSummary",
        "candidate.sensitivity == .standard && candidate.reviewMode == \"batch\"",
        "ownerTruthCandidateSourceInactive",
        "ownerTruthCandidateVersionConflict",
    ):
        require(required in contracts, f"Candidate batch safety contract missing: {required}")
    for required in (
        "private lazy var batchSelectionButton",
        "private lazy var batchConfirmButton",
        "@objc private func batchSelectionTapped()",
        "@objc private func batchConfirmTapped()",
        "每条候选会分别提交并生成可追溯的正式记忆版本",
        "owner-truth-candidate-inbox-batch-select",
        "owner-truth-candidate-inbox-batch-confirm",
    ):
        require(required in archive, f"Candidate Inbox batch UI missing: {required}")
    require(
        '"DJRunOwnerTruthCandidateInboxSmoke"' in feature_flags,
        "Candidate Inbox UIQA smoke launch route must stay in the QA scenario registry",
    )
    require(
        "case .ownerTruthCandidateInboxSmoke" in app_delegate,
        "Candidate Inbox UIQA smoke must route through the typed scenario registry",
    )
    require(
        "OwnerTruthCandidateInboxUIQASmoke.makeViewController(accountLease: accountLease)" in app_delegate,
        "Candidate Inbox UIQA smoke must render the typed inbox page",
    )

    # M0-A interview-review composition is intentionally a different lane from
    # the generic Candidate Inbox: accepting a review only consumes a
    # DecisionReceipt and must never activate a MemoryVersion.
    for required in (
        "enum OwnerTruthInterviewCandidateReviewPath",
        "struct OwnerTruthInterviewCandidateReviewBatch",
        "struct OwnerTruthInterviewCandidateBatchAcceptCommand",
        "struct OwnerTruthInterviewCandidateSingleReviewCommand",
        "protocol OwnerTruthInterviewCandidateReviewClient",
        "enum OwnerTruthInterviewCandidateReviewIntent",
        "final class OwnerTruthInterviewCandidateReviewUseCase",
        "interview review must not activate a MemoryVersion",
        "self.memoryVersionCreated = false",
    ):
        require(required in contracts, f"Interview Candidate review contract missing: {required}")

    for function_name, route_suffix in (
        (
            "fetchOwnerTruthInterviewCandidateReview",
            "/interview-review-batches/",
        ),
        (
            "acceptOwnerTruthInterviewCandidateBatch",
            "/candidate-review/batch-accept",
        ),
        (
            "reviewOwnerTruthInterviewCandidateSingle",
            "/candidate-review/candidates/",
        ),
    ):
        body = function_body(client, function_name)
        require("OwnerTruthCandidateReviewQAGate.isEnabled" in body, f"QA gate missing from {function_name}")
        require('"X-DreamJourney-QA-Owner-Truth": "1"' in body, f"QA header missing from {function_name}")
        require("authPolicy: .userRequired" in body, f"user session required for {function_name}")
        require("let path = \"/v2/vaults/" in body, f"interview review vault route missing: {function_name}")
        require(route_suffix in body, f"interview review route drifted: {function_name}")

    for required in (
        "extension DreamJourneyBackendClient: OwnerTruthInterviewCandidateReviewClient {}",
    ):
        require(required in client, f"Interview Candidate review backend client missing: {required}")

    for test_name in (
        "func testInterviewCandidateReviewDecodesSeparatedPathsAndNonActivationReceipt()",
        "func testInterviewCandidateReviewRejectsMemoryVersionActivationClaim()",
        "func testInterviewCandidateReviewUseCaseKeepsBatchAndSingleReceiptsSeparated()",
        "func testInterviewCandidateReviewUseCaseRejectsSingleCandidateFromBatchRoute()",
        "func testInterviewCandidateReviewUseCaseDiscardsDeferredReadAfterAccountChange()",
    ):
        require(test_name in tests, f"Interview Candidate review test missing: {test_name}")

    for required in (
        "final class OwnerTruthInterviewCandidateReviewViewController",
        "OwnerTruthInterviewCandidateReviewUseCase",
        "owner-truth-interview-candidate-review-list",
        "OwnerTruthInterviewCandidateReviewUIQASmoke",
        "runUIQAAcceptFirstBatchCandidate",
        "runUIQARejectFirstSingleCandidate",
        "InterviewCandidateReviewUIQAScenario",
        "allCandidatesRemoved",
    ):
        require(required in archive, f"Interview Candidate review QA UI missing: {required}")
    require(
        "memoryVersionCreated: false" in archive,
        "Interview Candidate UIQA receipt must stay non-activating",
    )
    require(
        '"DJRunOwnerTruthInterviewCandidateReviewSmoke"' in feature_flags,
        "Interview Candidate UIQA smoke launch route must stay in the QA scenario registry",
    )
    require(
        "case .ownerTruthInterviewCandidateReviewSmoke" in app_delegate,
        "Interview Candidate UIQA smoke must route through the typed scenario registry",
    )
    require(
        "OwnerTruthInterviewCandidateReviewUIQASmoke.makeViewController(" in app_delegate
        and "accountLease: accountLease" in app_delegate,
        "Interview Candidate UIQA smoke must render the typed review page",
    )

    print(
        "Product V4 iOS Owner Truth candidate client check passed: typed inbox/decision "
        "contracts plus the hidden lease-fenced Archive Inbox and non-activating interview review remain "
        "owner-authenticated, server-policy-gated, and default-off"
    )


if __name__ == "__main__":
    main()
