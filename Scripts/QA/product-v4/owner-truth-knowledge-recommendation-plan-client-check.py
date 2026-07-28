#!/usr/bin/env python3
"""Guard the QA-only, value-minimized M0-B recommendation plan client."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
SMOKE_SURFACE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
RUNNER = ROOT / "Scripts/QA/prd-stitch-ui/run-owner-truth-knowledge-recommendation-plan-smoke.sh"


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
        require(path.is_file(), f"missing M0-B recommendation client artifact: {path}")

    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    flags = FLAGS.read_text(encoding="utf-8")
    delegate = DELEGATE.read_text(encoding="utf-8")
    smoke_surface = SMOKE_SURFACE.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")

    for snippet in (
        "enum OwnerTruthKnowledgeRecommendationSlot",
        "case continuity",
        "case breadth",
        "enum OwnerTruthKnowledgeRecommendationDimension",
        "case lifeStage",
        "case importantPeople",
        "case keyDecisions",
        "case professionalExperience",
        "case values",
        "case aspirationsAndBoundaries",
        "struct OwnerTruthKnowledgeRecommendationPlan",
        'static let schemaVersion = "owner-truth-knowledge-recommendation-plan-response-v1"',
        'static let plannerSchemaVersion = "owner-truth-knowledge-recommendation-plan-v1"',
        '== "serverPlanned"',
        "plan must not select more than two recommendations",
        "selected recommendations must not duplicate a slot or knowledge gap",
        "protocol OwnerTruthKnowledgeRecommendationPlanClient",
        "final class OwnerTruthKnowledgeRecommendationPlanUseCase",
        "struct OwnerTruthKnowledgeRecommendationPlanViewState",
        "func refresh()",
        "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
        "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
        "resetForUnavailable(.staleAccountLease)",
    ):
        require(snippet in contracts, f"M0-B recommendation contract missing: {snippet}")

    recommendation_model = section(
        contracts,
        "struct OwnerTruthKnowledgeRecommendation: Equatable, Sendable",
        "/// Typed, value-minimized read model",
    )
    for forbidden in ("candidateId", "questionTemplateId", "memoryVersion", "checkpoint"):
        require(
            forbidden not in recommendation_model,
            f"typed recommendation model must not retain {forbidden}",
        )
    plan_model = section(
        contracts,
        "struct OwnerTruthKnowledgeRecommendationPlan: Equatable, Sendable",
        "protocol OwnerTruthKnowledgeRecommendationPlanClient",
    )
    for forbidden in ("includedMemoryVersionIds", "excludedMemoryVersionIds", "ownerSubjectId"):
        require(
            forbidden not in plan_model,
            f"typed recommendation plan must not retain {forbidden}",
        )
    use_case_state = section(
        contracts,
        "struct OwnerTruthKnowledgeRecommendationPlanViewState: Equatable, Sendable",
        "/// QA-only lease-fenced reader",
    )
    for forbidden in ("vaultID", "candidateId", "questionTemplateId", "memoryVersion", "checkpoint"):
        require(
            forbidden not in use_case_state,
            f"recommendation use-case state must not retain {forbidden}",
        )

    for snippet in (
        "func fetchOwnerTruthKnowledgeRecommendationPlan(",
        "/knowledge-recommendations/plan\"",
        "OwnerTruthCandidateReviewQAGate.isEnabled",
        'feature: "ownerTruthKnowledgeRecommendationPlan"',
        '"X-DreamJourney-QA-Owner-Truth": "1"',
        "OwnerTruthKnowledgeRecommendationPlan(",
        "extension DreamJourneyBackendClient: OwnerTruthKnowledgeRecommendationPlanClient {}",
    ):
        require(snippet in client, f"M0-B QA transport missing: {snippet}")

    for snippet in (
        'case ownerTruthKnowledgeRecommendationPlanSmoke = "DJRunOwnerTruthKnowledgeRecommendationPlanSmoke"',
        ".ownerTruthKnowledgeRecommendationPlanSmoke,",
    ):
        require(snippet in flags, f"M0-B QA scenario registry missing: {snippet}")

    for snippet in (
        "case .ownerTruthKnowledgeRecommendationPlanSmoke:",
        "runOwnerTruthKnowledgeRecommendationPlanSmoke()",
        "func runOwnerTruthKnowledgeRecommendationPlanSmoke(",
        "OwnerTruthKnowledgeRecommendationPlanUIQASmoke.run(accountLease: accountLease)",
    ):
        require(snippet in delegate, f"M0-B QA dispatcher missing: {snippet}")

    for snippet in (
        "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
        "struct OwnerTruthKnowledgeRecommendationPlanUIQASmokeResult",
        "candidateIdentifierExposed: false",
        "candidate-continuity-opaque",
        "includedMemoryVersionIds",
        "OwnerTruthKnowledgeRecommendationPlanUIQAClient",
        "verifyContractVariants(",
        "singleRecommendationAccepted",
        "emptyRecommendationAccepted",
        "nonReadyPlanAccepted",
        "malformedPlanRejected",
        "verifyUseCaseVariants",
        "OwnerTruthKnowledgeRecommendationPlanUseCase",
        "OwnerTruthKnowledgeRecommendationPlanDeferredUIQAClient",
        "OwnerTruthKnowledgeRecommendationPlanUIQALeaseRuntime",
        "useCaseOpaqueIdentifiersExposed",
        "useCaseStaleCompletionRejected",
        "planInvariantMismatch",
    ):
        require(snippet in smoke_surface, f"M0-B value-minimized smoke missing: {snippet}")

    for snippet in (
        "DJRunOwnerTruthKnowledgeRecommendationPlanSmoke",
        "DJEnableOwnerTruthCandidateReviewQA",
        '"selectedCount"',
        '"coverageDimensionCount"',
        '"candidateIdentifierExposed"',
        '"useCasePhase"',
        '"useCaseSelectedCount"',
        '"useCaseCoverageDimensionCount"',
        '"useCaseOpaqueIdentifiersExposed"',
        '"useCaseStaleCompletionRejected"',
    ):
        require(snippet in runner, f"M0-B smoke runner missing: {snippet}")

    print("Owner Truth knowledge recommendation plan client check passed")


if __name__ == "__main__":
    main()
