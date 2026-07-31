#!/usr/bin/env python3
"""Static boundary guard for centralized QA launch configuration."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def method_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"AppDelegate method is missing: {signature}")
    end = source.find("\n    func ", start + len(signature))
    return source[start:] if end < 0 else source[start:end]


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
        "struct QAScenarioLaunchPlan",
        "enum QAScenarioRunner",
        "static func makeLaunchPlan(from configuration: QALaunchConfiguration)",
        "static func prepareSession(",
        "var startupDelay: TimeInterval?",
        "static func schedule(",
        "enum QAScenarioResultWriter",
        "static func write(",
        "enum QAEchoScenarioRunner",
        "private static let maximumRootRetries = 20",
        "result[\"selectedTabIndex\"] = tabBarController.selectedIndex",
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
        "QAScenarioRunner.makeLaunchPlan(" in app_delegate,
        "AppDelegate UIQA harness must obtain its orchestration plan from QAScenarioRunner",
    )
    require(
        "launchPlan.shouldSeedProfileCareFamilyMember" in app_delegate,
        "AppDelegate profile-care seed must use the centralized scenario plan",
    )
    require(
        "launchPlan.scenario" in app_delegate,
        "AppDelegate UIQA harness must resolve one typed startup scenario from the plan",
    )
    require(
        "QAScenarioRunner.prepareSession(" in app_delegate,
        "AppDelegate UIQA harness must delegate session preparation to QAScenarioRunner",
    )
    require(
        "QAScenarioRunner.schedule(" in app_delegate,
        "AppDelegate UIQA harness must delegate startup timing to QAScenarioRunner",
    )
    require(
        "func prepareUIQASession(" not in app_delegate,
        "AppDelegate must not retain the pre-runner session-preparation helper",
    )
    require(
        "QAScenarioResultWriter.writeAndLog(" in method_body(
            app_delegate,
            "func runEchoTraceExportSmoke(",
        ),
        "Echo QA exports must use the compile-isolated result writer",
    )
    require(
        "echo-trace-export-smoke-result.json" in method_body(
            app_delegate,
            "func runEchoTraceExportSmoke(",
        ),
        "Echo trace export must retain its stable result file",
    )
    require(
        app_delegate.count("QAEchoScenarioRunner.run(") >= 8,
        "Echo scenario runner must own five evidence exports, lifecycle, runtime-stub, and PCM-drive scenarios",
    )
    for smoke_name in (
        "EchoTraceExportSmoke",
        "EchoRuntimeDiagnosticsExportSmoke",
        "EchoTraceEvidencePackageExportSmoke",
        "EchoTraceEvidencePackagePanelExportSmoke",
        "EchoQAEvidenceBundleExportSmoke",
        "EchoDigitalHumanLifecycleSmoke",
        "DigitalHumanRuntimeStubSmoke",
    ):
        require(
            f'smokeName: "{smoke_name}"' in app_delegate,
            f"{smoke_name} must retain its stable result label through the shared writer",
        )
    require(
        "switch scenario" in app_delegate,
        "AppDelegate UIQA harness must dispatch through the typed scenario registry",
    )
    require(
        "scheduleUIQAScenario(after:" not in app_delegate,
        "AppDelegate must not retain per-scenario magic startup delays",
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
        "DJRunNotificationRuntimeRouteSmoke": "notificationRuntimeRouteSmoke",
        "DJRunOwnerTruthCandidateInboxSmoke": "ownerTruthCandidateInboxSmoke",
        "DJRunOwnerTruthInterviewCandidateReviewSmoke": "ownerTruthInterviewCandidateReviewSmoke",
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

    print("PASS: QA launch configuration static boundary")


if __name__ == "__main__":
    main()
