#!/usr/bin/env python3
"""Guard the closed-pilot generic Candidate review transport and surface."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
ARCHIVE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
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
    client = CLIENT.read_text(encoding="utf-8")
    archive = ARCHIVE.read_text(encoding="utf-8")
    echo = ECHO.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "serverPolicyManagedClosedPilotFeatures",
        ".echoTextInput",
        ".echoGuidedRecommendations",
        ".ownerTruthLifeMap",
        ".ownerTextCaptureV1",
        ".ownerTruthCandidateReview",
        "captureServerPolicyManagedClosedPilotRoute",
        "requestServerPolicyManagedClosedPilotDecision",
        "revalidateServerPolicyManagedClosedPilotRequest",
        "isServerPolicyManagedClosedPilotRouteAllowed",
    ):
        require(required in client, f"server-managed closed-pilot guard missing: {required}")

    require(
        "localEnabled: Self.serverPolicyManagedClosedPilotFeatures.contains(feature) ? true : nil" in client,
        "only the explicit closed-pilot allowlist may override local default-off state",
    )
    require(
        "localEnabled: Self.serverPolicyManagedClosedPilotFeatures.contains(captured.feature) ? true : nil" in client,
        "request revalidation must retain the same narrow closed-pilot rule",
    )

    natural_input_transport = function_body(client, "ownerTruthInterviewNaturalInputTransport")
    require(
        "requestServerPolicyManagedClosedPilotDecision(for: .echoTextInput)" in natural_input_transport,
        "natural interview writes must use the server-managed closed-pilot decision",
    )
    require(
        "requestDecision(for: .echoTextInput)" not in natural_input_transport,
        "natural interview writes must not be blocked by a local Echo flag",
    )
    product_entry_refresh = function_body(echo, "refreshOwnerTruthInterviewNaturalInputProductEntryPolicy")
    require(
        "captureServerPolicyManagedClosedPilotRoute(" in product_entry_refresh
        and ".echoTextInput" in product_entry_refresh,
        "Echo product entry must capture a server-managed route decision",
    )
    require(
        "requestServerPolicyManagedClosedPilotDecision(for: .echoTextInput)" in product_entry_refresh,
        "Echo product entry must revalidate the same server-managed decision before display",
    )
    echo_view_did_load = function_body(echo, "viewDidLoad")
    require(
        "captureServerPolicyManagedClosedPilotRoute(" in echo_view_did_load,
        "Echo must not seed its product route capture from a local flag",
    )

    inbox = function_body(client, "fetchOwnerTruthCandidateInbox")
    decision = function_body(client, "reviewOwnerTruthCandidate")
    for body, operation in ((inbox, "inbox"), (decision, "decision")):
        require("let isQALane = OwnerTruthCandidateReviewQAGate.isEnabled" in body, f"{operation} must keep QA isolated")
        require("requestFeatureDecision(for: .ownerTruthCandidateReview)" in body, f"{operation} must capture server policy")
        require("featureDecision: decision" in body, f"{operation} must bind its captured policy")
        require("authPolicy: .userRequired" in body, f"{operation} must require an owner session")

    require(
        'pathComponents[3] == "candidates"' in client
        and 'pathComponents[5] == "decisions"' in client
        and "return .ownerTruthCandidateReview" in client,
        "generic Candidate routes must map to ownerTruthCandidateReview",
    )
    require(
        "isExplicitOwnerTruthQARequest" in client
        and "OwnerTruthCandidateReviewQAGate.isEnabled || qaFeatureDecisionProvider != nil" in client,
        "QA header bypass must remain restricted to the QA gate or test seam",
    )

    require(
        "isServerPolicyManagedClosedPilotRouteAllowed(.ownerTruthCandidateReview)" in archive,
        "Archive entry must rely on closed-pilot server policy",
    )
    natural_input_start = archive.find("final class OwnerTruthInterviewNaturalInputViewController")
    require(natural_input_start >= 0, "natural interview product surface missing")
    natural_input_surface = archive[natural_input_start:]
    for feature in (
        ".echoGuidedRecommendations",
        ".ownerTruthLifeMap",
        ".echoTextInput",
        ".ownerTruthCandidateReview",
    ):
        require(
            f"requestServerPolicyManagedClosedPilotDecision(for: {feature})" in natural_input_surface,
            f"natural interview product surface must use server policy for {feature}",
        )
        require(
            f"FeatureFlagService.shared.isEnabled({feature})" not in natural_input_surface,
            f"natural interview product surface must not require a local flag for {feature}",
        )
    require(
        'candidateReviewQAButton.setTitle(isVisible ? title : nil, for: .normal)' in archive,
        "Archive entry must use product wording when the formal policy is allowed",
    )
    require(
        "确认后才会形成正式记忆" in archive,
        "Candidate page must not claim it is QA-only in the formal path",
    )

    require("case ownerTruthCandidateReview" in feature_flags, "feature enum missing Candidate review")
    nonpersistent_start = feature_flags.find("private static let nonPersistentFeatures")
    require(nonpersistent_start >= 0, "nonpersistent policy missing")
    nonpersistent_end = feature_flags.find("]", nonpersistent_start)
    require(
        ".ownerTruthCandidateReview" in feature_flags[nonpersistent_start:nonpersistent_end],
        "Candidate review must remain default-off locally",
    )
    require(
        "func testGenericCandidateReviewPathsUseClosedPilotFeatureGate()" in tests,
        "generic Candidate route mapping XCTest missing",
    )

    print("Owner Truth closed-pilot Candidate review iOS contract check passed")


if __name__ == "__main__":
    main()
