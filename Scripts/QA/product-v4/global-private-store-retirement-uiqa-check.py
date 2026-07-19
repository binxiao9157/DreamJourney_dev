#!/usr/bin/env python3

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
SMOKE_SOURCE = ROOT / "DreamJourney/Sources/Services/ProductV4GlobalPrivateStoreRetirementUIQASmoke.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
RUNNER = ROOT / "Scripts/QA/product-v4/run-global-private-store-retirement-uiqa-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"ERROR: {message}", file=sys.stderr)
        raise SystemExit(1)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


app_delegate = read(APP_DELEGATE)
smoke_source = read(SMOKE_SOURCE)
project = read(PROJECT)
runner = read(RUNNER)

require(
    'configuration.contains("DJRunGlobalPrivateStoreRetirementSmoke")' in app_delegate,
    "AppDelegate must route the dedicated WI-S0-01-06 UIQA launch argument through QALaunchConfiguration",
)
require(
    "runGlobalPrivateStoreRetirementSmoke()" in app_delegate,
    "AppDelegate must launch the WI-S0-01-06 runtime smoke",
)

required_source_snippets = (
    "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
    "ConversationLocalStorage",
    "MemoirRepository",
    "MemoryRepository",
    "MemoryMapPresentationStore",
    "AccountPrivateMediaStore",
    "accountA",
    "accountB",
    "legacyGlobalConversationQuarantined",
    "global-private-store-retirement-uiqa-result.json",
)
for snippet in required_source_snippets:
    require(snippet in smoke_source, f"UIQA source is missing contract anchor: {snippet}")

require(
    "ProductV4GlobalPrivateStoreRetirementUIQASmoke.swift in Sources" in project,
    "UIQA source must be included in the DreamJourney target",
)

required_runner_snippets = (
    "run-installable-simulator-uiqa.sh",
    "DJRunGlobalPrivateStoreRetirementSmoke",
    "global-private-store-retirement-uiqa-result.json",
    "xcrun simctl io",
)
for snippet in required_runner_snippets:
    require(snippet in runner, f"UIQA runner is missing contract anchor: {snippet}")

print("Global private store retirement UIQA static check passed")
