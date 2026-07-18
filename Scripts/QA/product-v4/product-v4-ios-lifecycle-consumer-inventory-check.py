#!/usr/bin/env python3
"""Keep the WI-S1-03-03 lifecycle consumer inventory aligned with source."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
INVENTORY = ROOT / "Scripts/QA/product-v4/app-lifecycle-consumer-inventory-v1.json"
SCENE_DELEGATE = ROOT / "DreamJourney/Sources/SceneDelegate.swift"
APP_COORDINATOR = ROOT / "DreamJourney/Sources/App/AppCoordinator.swift"
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
AI_RECORDING = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
FAMILY = ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift"
KNOWLEDGE = ROOT / "DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift"
DIALOG = ROOT / "DreamJourney/Sources/Services/DialogEngineManager.swift"
NOTIFICATIONS = ROOT / "DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift"
ACCOUNT_LIFECYCLE = ROOT / "DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    inventory = json.loads(read(INVENTORY))
    require(inventory["schemaVersion"] == 1, "unsupported lifecycle inventory schema")
    require(
        inventory["rootForwarder"]["events"] == [
            "sceneConnected",
            "didBecomeActive",
            "willResignActive",
            "willEnterForeground",
            "didEnterBackground",
            "didDisconnect",
        ],
        "root lifecycle event inventory drifted",
    )
    root_event_consumers = inventory["rootEventConsumers"]
    require(
        [item["id"] for item in root_event_consumers] == ["echo-runtime"],
        "root lifecycle event consumer allowlist drifted",
    )
    require(
        root_event_consumers[0]["eventSource"] == "djAppLifecycleEventForwarded",
        "Echo root lifecycle event source drifted",
    )
    direct_consumers = inventory["directUIKitConsumers"]
    require(
        [item["id"] for item in direct_consumers] == ["ai-recording-runtime"],
        "direct UIKit lifecycle consumer allowlist drifted",
    )

    scene_delegate = read(SCENE_DELEGATE)
    app_coordinator = read(APP_COORDINATOR)
    echo = read(ECHO)
    ai_recording = read(AI_RECORDING)
    family = read(FAMILY)
    knowledge = read(KNOWLEDGE)
    dialog = read(DIALOG)
    notifications = read(NOTIFICATIONS)
    account_lifecycle = read(ACCOUNT_LIFECYCLE)

    require("handleSceneLifecycleEvent" in scene_delegate, "SceneDelegate must forward lifecycle events")
    require("final class AppLifecycleEventForwarder" in app_coordinator, "root forwarder missing")
    require("AccountLeaseRuntime.shared.validate(" in app_coordinator, "foreground effect lease fence missing")
    require("observeEchoAppLifecycle" in echo, "Echo lifecycle consumer missing from source")
    require("djAppLifecycleEventForwarded" in echo, "Echo must consume root lifecycle event")
    for direct_notification in (
        "UIApplication.willResignActiveNotification",
        "UIApplication.didEnterBackgroundNotification",
        "UIApplication.willEnterForegroundNotification",
        "UIApplication.didBecomeActiveNotification",
    ):
        require(
            direct_notification not in echo,
            f"Echo must not retain direct UIKit lifecycle observer: {direct_notification}",
        )
    require("scheduleCloudDigitalHumanRuntimeReleaseForBackgroundIfNeeded" in echo, "Echo background release inventory drifted")
    require("setupNotifications" in ai_recording, "AI recording lifecycle consumer missing from source")
    require("handleDidEnterBackground" in ai_recording, "AI recording background handler missing")
    require("handleWillEnterForeground" in ai_recording, "AI recording foreground handler missing")
    require("startupWorkItem" in family and "AccountLeaseRuntime" in family, "Family async lease fence inventory drifted")
    require("debounceWorkItem" in knowledge and "KnowledgeSyncLeaseContext" in knowledge, "Knowledge async lease fence inventory drifted")
    require("silenceTimer" in dialog and "activeDialogAccountLease" in dialog, "Dialog timer fence inventory drifted")
    require("EchoDelayedReplyOperationScope" in notifications, "notification scope fence inventory drifted")
    require("actor AccountLifecycleTransitionController" in account_lifecycle, "serialized account teardown authority missing")

    print(
        "Product V4 lifecycle consumer inventory check passed: 1 root-event consumer, "
        "1 direct UIKit consumer, and 4 lease-fenced async consumers are accounted for"
    )


if __name__ == "__main__":
    main()
