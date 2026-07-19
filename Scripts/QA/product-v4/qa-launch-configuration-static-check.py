#!/usr/bin/env python3
"""Static boundary guard for WI-S1-03-10 QA launch configuration extraction."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> None:
    feature_flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
    app_delegate = read("DreamJourney/Sources/AppDelegate.swift")
    echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")

    for anchor in (
        "struct QALaunchConfiguration",
        "static let shared = QALaunchConfiguration()",
        "#if DEBUG || UI_QA_SIMULATOR",
        "arguments = ProcessInfo.processInfo.arguments",
        "arguments = []",
        "func contains(_ argument: String) -> Bool",
        "func contains(prefix: String) -> Bool",
        "func value(forPrefix prefix: String) -> String?",
        "var startupScenario: QALaunchScenario?",
        "enum QALaunchFeature: String, CaseIterable",
        "enum QALaunchScenario: String, CaseIterable",
        "static let startupOrder: [QALaunchScenario]",
        "static func resolve(in configuration: QALaunchConfiguration)",
        "enum QALaunchScenarioSessionPreparation",
    ):
        require(anchor in feature_flags, f"QALaunchConfiguration missing boundary anchor: {anchor}")

    require(
        feature_flags.count("ProcessInfo.processInfo.arguments") == 1,
        "only QALaunchConfiguration may read raw process arguments in FeatureFlagService",
    )
    require(
        "ProcessInfo.processInfo.arguments" not in app_delegate,
        "AppDelegate must consume QA args through QALaunchConfiguration",
    )
    require(
        "ProcessInfo.processInfo.arguments" not in echo,
        "EchoViewController must consume QA args through QALaunchConfiguration",
    )
    require(
        "let configuration = QALaunchConfiguration.shared" in app_delegate,
        "AppDelegate QA harness must acquire the centralized configuration",
    )
    require(
        "configuration.shouldSeedProfileCareFamilyMember" in app_delegate,
        "AppDelegate profile-care seed must use the centralized scenario policy",
    )
    require(
        "configuration.startupScenario" in app_delegate,
        "AppDelegate UIQA harness must resolve one typed startup scenario",
    )
    require(
        "switch scenario" in app_delegate,
        "AppDelegate UIQA harness must dispatch through the typed scenario registry",
    )
    require(
        "configuration.contains(" not in app_delegate,
        "AppDelegate must not retain per-scenario raw launch-argument checks",
    )
    require(
        "QALaunchConfiguration.shared.value(forPrefix: prefix)" in app_delegate,
        "AppDelegate keyed QA arguments must use centralized parsing",
    )
    require(
        "QALaunchConfiguration.shared.value(forPrefix: prefix)" in echo,
        "Echo keyed QA arguments must use centralized parsing",
    )

    for argument, scenario_case in {
        "DJRunDigitalHumanLivePanelSmoke": "digitalHumanLivePanelSmoke",
        "DJRunVoiceCloneSynthesisRuntimeSmoke": "voiceCloneSynthesisRuntimeSmoke",
        "DJRunArchiveFailedAnalysisRetrySmoke": "archiveFailedAnalysisRetrySmoke",
        "DJRunEchoDelayedReplyNotificationSmoke": "echoDelayedReplyNotificationSmoke",
        "DJRunOwnerTruthCandidateInboxSmoke": "ownerTruthCandidateInboxSmoke",
        "DJRunTimeLetterDispatchReminderSmoke": "timeLetterDispatchReminderSmoke",
        "DJShowEchoVoiceStatePreview": "echoVoiceStatePreview",
    }.items():
        require(
            f'"{argument}"' in feature_flags,
            f"scenario registry must retain the existing UIQA argument: {argument}",
        )
        require(
            f"case .{scenario_case}" in app_delegate,
            f"AppDelegate must retain the existing UIQA scenario dispatch: {argument}",
        )

    for argument in (
        "DJRunTencentDigitalHumanTextDriveSmoke",
        "DJRunTencentDigitalHumanPCMDriveSmoke",
        "DJRunTencentDigitalHumanBackendPCMDriveSmoke",
        "DJRunTencentBackendPCMDriveMockSmoke",
        "DJDisableDigitalHumanLivePanel",
        "DJDigitalHumanLipSyncProviderVisemeTimeline",
    ):
        require(
            f'QALaunchConfiguration.shared.contains("{argument}")' in echo
            or f'configuration.contains("{argument}")' in echo,
            f"Echo must retain the existing QA switch: {argument}",
        )

    print("PASS: WI-S1-03-10 QA launch configuration static boundary")


if __name__ == "__main__":
    main()
