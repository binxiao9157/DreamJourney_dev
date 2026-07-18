#!/usr/bin/env python3
"""Guard the additive XCTest foundation for WI-S1-03-01."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
MODEL = ROOT / "DreamJourney/Sources/App/AudioOwnerLeaseModel.swift"
TEST_ROOT = ROOT / "DreamJourneyTests"
SCHEME = ROOT / "DreamJourney.xcodeproj/xcshareddata/xcschemes/DreamJourney.xcscheme"
PACKAGE = ROOT / "Package.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    project = read(PROJECT)
    model = read(MODEL)
    account_tests = read(TEST_ROOT / "AccountLeaseRuntimeTests.swift")
    audio_tests = read(TEST_ROOT / "AudioOwnerLeaseModelTests.swift")
    doubles = read(TEST_ROOT / "TestDoubles.swift")
    scheme = read(SCHEME)
    package = read(PACKAGE)

    for required in (
        'Build configuration list for PBXNativeTarget "DreamJourneyTests"',
        'productType = "com.apple.product-type.bundle.unit-test"',
        'DreamJourneyTests.xctest',
        'XCTest.framework',
        'TEST_HOST = "$(BUILT_PRODUCTS_DIR)/DreamJourney.app/DreamJourney"',
        'BUNDLE_LOADER = "$(TEST_HOST)"',
        'path = DreamJourneyTests;',
        'AccountLeaseRuntimeTests.swift',
        'AudioOwnerLeaseModelTests.swift',
        'TestDoubles.swift',
    ):
        require(required in project, f"XCTest target contract missing: {required}")

    for required in (
        'BlueprintName="DreamJourneyTests"',
        'BlueprintName="DreamJourney"',
        '<TestAction',
    ):
        require(required in scheme, f"shared XCTest scheme contract missing: {required}")

    for required in (
        'name: "DreamJourneyCore"',
        'name: "DreamJourneyCoreTests"',
        '"AccountSessionActor.swift"',
        '"AccountLease.swift"',
        '"AudioOwnerLeaseModel.swift"',
        'path: "DreamJourneyTests"',
    ):
        require(required in package, f"unhosted XCTest package contract missing: {required}")

    for required in (
        "@testable import DreamJourney",
        "@testable import DreamJourneyCore",
        "testStaleAccountCallbackIsRejectedAfterAccountSwitch",
    ):
        require(required in account_tests, f"AccountLease XCTest contract missing: {required}")
    for required in (
        "testDigitalHumanPlaybackPreemptsEchoCaptureAndStaleReleaseCannotClearIt",
        "testOlderRuntimeGenerationCannotPreemptCurrentAudioOwner",
    ):
        require(required in audio_tests, f"Audio owner XCTest contract missing: {required}")
    for required in (
        "ControllableClock",
        "SequenceUUIDGenerator",
        "StubHTTPTransport",
        "NotificationSpy",
        "AudioOwnerSpy",
    ):
        require(required in doubles, f"test double missing: {required}")

    for forbidden in ("UIKit", "AVFoundation", "URLSession", "UserDefaults", ".shared"):
        require(forbidden not in model, f"pure audio owner model must not depend on {forbidden}")

    for path in (ROOT / "DreamJourney/Sources/Modules").rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        require(
            "AudioOwnerLeaseModel(" not in text,
            f"Feature must not directly construct the new audio owner model: {path.relative_to(ROOT)}",
        )

    print(
        "Product V4 iOS XCTest foundation check passed: hosted and unhosted test targets, "
        "deterministic doubles, account stale callback, and audio owner model are guarded"
    )


if __name__ == "__main__":
    main()
