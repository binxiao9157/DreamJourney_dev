#!/usr/bin/env python3
"""Keep the remaining UIQA AppDelegate dispatch boundary intentionally classified.

This guard records the current non-Echo dispatch inventory so a later
extraction cannot silently treat authenticated, seeded, or
account-lease-sensitive flows as ordinary scheduled UI actions.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def scenario_cases(feature_flags: str) -> set[str]:
    match = re.search(
        r"enum QALaunchScenario: String, CaseIterable \{(.*?)\n    static let startupOrder:",
        feature_flags,
        re.DOTALL,
    )
    require(match is not None, "QALaunchScenario enum boundary is missing")
    return set(re.findall(r"^    case (\w+) = ", match.group(1), re.MULTILINE))


def require_dispatch_case(app_delegate: str, scenario: str) -> None:
    require(
        f"case .{scenario}:" in app_delegate,
        f"AppDelegate dispatch is missing scenario case: {scenario}",
    )


def main() -> None:
    feature_flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
    app_delegate = read("DreamJourney/Sources/AppDelegate.swift")
    cases = scenario_cases(feature_flags)

    # These scenarios already use the shared root/Echo route helper. The
    # authenticated runtime-stub remains separate because its identity
    # challenge must finish before the route is attempted.
    shared_echo_route = {
        "digitalHumanLivePanelSmoke",
        "echoDigitalHumanLifecycleSmoke",
        "echoAudioOwnerCoordinatorSmoke",
        "echoContinuousTurnSmoke",
        "tencentBackendPCMDriveMockSmoke",
        "echoTraceExportSmoke",
        "echoRuntimeDiagnosticsExportSmoke",
        "echoTraceEvidencePackageExportSmoke",
        "echoTraceEvidencePackagePanelExportSmoke",
        "echoQAEvidenceBundleExportSmoke",
    }
    authenticated_echo_route = {"digitalHumanRuntimeStubSmoke"}

    # These scenarios deliberately retain setup in AppDelegate because their
    # result depends on a deterministic local archive seed or AccountLease.
    seed_then_schedule = {
        "archiveFailedAnalysisRetrySmoke",
        "backendEnvironmentSmoke",
        "archiveToEchoSmoke",
    }
    account_lease_custom_route = {
        "archiveMediaEchoContextSmoke",
        "notificationRuntimeRouteSmoke",
        "ownerTruthInterviewCandidateConfirmationFailClosedSmoke",
        "ownerTruthInterviewCandidateConfirmationSourceInactiveSmoke",
    }
    seed_only = {
        "seedEchoArchiveContext",
        "seedArchiveAnalysisInsights",
        "seedPendingArchiveAnalysis",
    }
    standard_scheduled = {
        "voiceCloneProfileSelectionSmoke",
        "voiceCloneSynthesisRuntimeSmoke",
        "voiceCloneOwnerScopeSmoke",
        "profileCareBackendFailureRetrySmoke",
        "profileCareBackendStateSmoke",
        "profileCareStateSmoke",
        "profileCareEscalationBoundarySmoke",
        "profileFamilyPersonaReleaseSmoke",
        "globalPrivateStoreRetirementSmoke",
        "archiveMediaEntriesSmoke",
        "archiveAudioLifecycleSmoke",
        "archiveHiddenShellSmoke",
        "ownerTruthCandidateInboxSmoke",
        "ownerTruthInterviewCandidateReviewSmoke",
        "ownerTruthInterviewSessionStateSmoke",
        "ownerTruthInterviewOrchestrationSmoke",
        "ownerTruthInterviewTopicSwitchSmoke",
        "ownerTruthInterviewPacingSmoke",
        "ownerTruthInterviewNaturalInputSmoke",
        "ownerTruthKnowledgeDimensionConfirmationSmoke",
        "ownerTruthKnowledgeRecommendationPlanSmoke",
        "ownerTruthInterviewBoundarySmoke",
        "ownerTruthInterviewNaturalInputEchoSurfaceSmoke",
        "ownerTruthInterviewNaturalInputProductSurfaceSmoke",
        "ownerTruthInterviewCandidateProposalReviewReadySmoke",
        "ownerTruthLifeMapPresentationSmoke",
        "ownerTruthMemorySearchPresentationSmoke",
        "ownerTruthInterviewOutcomePresentationSmoke",
        "echoDelayedReplyNotificationSmoke",
        "timeLetterDispatchReminderSmoke",
        "echoListeningStatePreview",
        "echoSpeakingStatePreview",
        "voiceSDKReadinessPreview",
        "voiceCloneStatusFeedbackPreview",
        "echoVoiceStatePreview",
    }

    categories = (
        shared_echo_route,
        authenticated_echo_route,
        seed_then_schedule,
        account_lease_custom_route,
        seed_only,
        standard_scheduled,
    )
    classified = set().union(*categories)
    require(classified == cases, "UIQA scenario inventory must classify every registry case exactly once")
    total_count = sum(len(category) for category in categories)
    require(total_count == len(classified), "UIQA scenario inventory categories must not overlap")

    for scenario in classified:
        require_dispatch_case(app_delegate, scenario)

    for anchor in (
        "prepareUIQADigitalHumanRuntimeStubBackendSession",
        "seedFailedArchiveAnalysisRetryContext()",
        "seedEchoArchiveContext()",
        "seedPendingArchiveAnalysisContext()",
        "prepareArchiveMediaEchoContextSmoke()",
        "seedArchiveAnalysisInsightsContext()",
    ):
        require(anchor in app_delegate, f"non-Echo dispatch inventory lost required preparation: {anchor}")

    # This is the next intentionally small migration target: it has no
    # authenticated provider call, no archive seed, and no AccountLease retry.
    candidate = "globalPrivateStoreRetirementSmoke"
    require(candidate in standard_scheduled, "next non-Echo migration target must remain low risk")
    require(
        "case .globalPrivateStoreRetirementSmoke:\n            scheduleUIQAScenario(scenario) { _ in\n                ProductV4GlobalPrivateStoreRetirementUIQASmoke.runAndPresent()\n            }"
        in app_delegate,
        "global private store smoke must dispatch through its isolated QA runner",
    )

    print(
        "PASS: QA non-Echo dispatch inventory "
        f"scenarios={len(cases)} sharedEcho={len(shared_echo_route)} "
        f"authenticatedEcho={len(authenticated_echo_route)} seeded={len(seed_then_schedule) + len(seed_only)} "
        f"leaseSensitive={len(account_lease_custom_route)} standardScheduled={len(standard_scheduled)} "
        f"nextCandidate={candidate}"
    )


if __name__ == "__main__":
    main()
