#!/usr/bin/env python3
"""Guard the product guided-recommendation activation boundary.

The rendered assistant question may be shown as context, but it must never be
copied into the natural-input text view or sent as Owner narration.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
VIEW = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"


def require(content: str, needle: str, label: str) -> None:
    if needle not in content:
        raise AssertionError(f"{label}: missing {needle}")


def forbid(content: str, needle: str, label: str) -> None:
    if needle in content:
        raise AssertionError(f"{label}: forbidden {needle}")


def main() -> None:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    view = VIEW.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for needle in (
        "OwnerTruthGuidedRecommendationActivationCommand",
        "OwnerTruthGuidedRecommendationActivationReceipt",
        "awaitingOwnerNarrative",
        "activePrompt: OwnerTruthGuidedRecommendationPrompt?",
        "func activate(slot: OwnerTruthKnowledgeRecommendationSlot)",
        "activateOwnerTruthGuidedRecommendation",
    ):
        require(contracts, needle, "guided activation contract")

    for needle in (
        "/guided-recommendations/activate",
        "OwnerTruthGuidedRecommendationActivationReceipt(",
        ".echoGuidedRecommendations",
    ):
        require(client, needle, "guided activation client")

    require(
        view,
        "guidedRecommendationUseCase?.activate(slot: prompt.slot)",
        "guided activation UI",
    )
    require(
        view,
        "owner-truth-guided-recommendation-active-prompt",
        "guided activation active prompt UI",
    )
    forbid(
        view,
        "inputTextView.text = guidedRecommendationPrompts[sender.tag].question",
        "guided activation UI",
    )

    for needle in (
        "testGuidedRecommendationActivationContractKeepsOnlyAwaitingOwnerNarrativeState",
        "activationCommands.count",
        "XCTAssertNil(naturalInputClient.appendCommand)",
    ):
        require(tests, needle, "guided activation tests")

    print("Owner Truth guided recommendation activation static check passed")


if __name__ == "__main__":
    main()
