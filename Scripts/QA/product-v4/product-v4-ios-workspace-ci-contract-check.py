#!/usr/bin/env python3
"""Guard the canonical workspace-based iOS CI and signing override boundary."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
WORKSPACE = ROOT / "DreamJourney.xcworkspace"
TEST_GATE = ROOT / "Scripts/QA/product-v4/run-ios-test-foundation-gate.sh"
SIMULATOR_GATE = ROOT / "Scripts/QA/product-v4/run-ios-simulator-runtime-gate.sh"
M0_GATE = ROOT / "Scripts/QA/product-v4/run-v4-m0-non-device-release-gate.sh"
GENERIC_BUILD = ROOT / "Scripts/QA/prd-stitch-ui/run-iphoneos-generic-build.sh"
BUNDLE_GUARD = ROOT / "Scripts/QA/prd-stitch-ui/installable-simulator-uiqa-bundle-guard-check.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def require_workspace_build(script: Path, *markers: str) -> None:
    content = read(script)
    require("xcodebuild" in content, f"missing xcodebuild entry: {script.relative_to(ROOT)}")
    require("DreamJourney.xcworkspace" in content, f"workspace missing: {script.relative_to(ROOT)}")
    require(
        re.search(r"(?<![A-Za-z])-project(?:\s|$)", content) is None,
        f"project build is forbidden: {script.relative_to(ROOT)}",
    )
    for marker in markers:
        require(marker in content, f"missing {marker}: {script.relative_to(ROOT)}")


def main() -> None:
    require(WORKSPACE.is_dir(), "DreamJourney.xcworkspace is required for CocoaPods/SDK linkage")

    require_workspace_build(
        TEST_GATE,
        "-only-testing:DreamJourneyTests",
        "CODE_SIGNING_ALLOWED=NO",
    )
    require_workspace_build(
        SIMULATOR_GATE,
        "-only-testing:DreamJourneyTests",
        "DJ_IOS_TEST_DESTINATION",
    )
    require_workspace_build(
        M0_GATE,
        "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER",
        "DREAMJOURNEY_DEVELOPMENT_TEAM",
    )
    require_workspace_build(
        GENERIC_BUILD,
        "-destination 'generic/platform=iOS'",
        "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER",
        "DREAMJOURNEY_DEVELOPMENT_TEAM",
    )

    bundle_guard = read(BUNDLE_GUARD)
    for marker in (
        "com.yxj.dreamjourney.app",
        "2BTR77V3R8",
        "must not use global PRODUCT_BUNDLE_IDENTIFIER",
    ):
        require(marker in bundle_guard, f"bundle/team guard missing: {marker}")

    for script in (ROOT / "Scripts").rglob("*.sh"):
        content = script.read_text(encoding="utf-8")
        if "xcodebuild" not in content:
            continue
        require(
            re.search(r"(?<![A-Za-z])-project(?:\s|$)", content) is None,
            f"xcodebuild must use the workspace, not -project: {script.relative_to(ROOT)}",
        )

    print(
        "Product V4 iOS workspace CI contract check passed: hosted XCTest, simulator, "
        "generic iPhoneOS, bundle and team guards use the workspace boundary"
    )


if __name__ == "__main__":
    main()
