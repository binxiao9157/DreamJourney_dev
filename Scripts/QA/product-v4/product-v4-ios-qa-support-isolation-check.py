#!/usr/bin/env python3
"""Guard the first WI-S1-03-10 QA-support extraction boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
COORDINATOR = ROOT / "DreamJourney/Sources/App/AudioOwnerLeaseCoordinator.swift"
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    coordinator = read(COORDINATOR)
    echo = read(ECHO)
    project = read(PROJECT)

    for required in (
        "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
        "enum AudioOwnerLeaseQASupport",
        "enum EchoAudioOwnerDriverError: Error",
        "final class EchoAudioOwnerDriver: AudioSessionDriving",
        "never configures `AVAudioSession` or opens a provider",
    ):
        require(required in coordinator, f"QA support boundary missing: {required}")

    for required in (
        "enum QAScenarioResultWriter",
        "static func writeAndLog(",
        "This remains compile-isolated from release builds.",
    ):
        require(required in read(ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"), f"QA result writer boundary missing: {required}")

    require(
        "AudioOwnerLeaseQASupport.EchoAudioOwnerDriver()" in echo,
        "Echo must consume the simulator driver through AudioOwnerLeaseQASupport",
    )
    for removed in (
        "private enum UIQAEchoAudioOwnerDriverError",
        "private final class UIQAEchoAudioOwnerDriver",
    ):
        require(removed not in echo, f"Echo must not retain inline QA fixture: {removed}")

    app_delegate = read(ROOT / "DreamJourney/Sources/AppDelegate.swift")
    require(
        "QAScenarioResultWriter.writeAndLog(" in app_delegate,
        "AppDelegate must delegate Echo QA result persistence to QA support",
    )
    require(
        "func writeEchoAudioOwnerCoordinatorSmokeResult" not in app_delegate,
        "AppDelegate must not retain the Echo audio-owner result writer",
    )

    require(
        "AudioOwnerLeaseCoordinator.swift in Sources" in project,
        "QA support host must remain in the DreamJourney target",
    )

    print("product-v4 iOS QA support isolation check passed")


if __name__ == "__main__":
    main()
