#!/usr/bin/env python3
"""Guard AIRecording's migration to the root App/Scene lifecycle event."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
INVENTORY = ROOT / "Scripts/QA/product-v4/app-lifecycle-consumer-inventory-v1.json"


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
    source = SOURCE.read_text(encoding="utf-8")
    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))

    root_consumers = inventory["rootEventConsumers"]
    require(
        [item["id"] for item in root_consumers] == [
            "echo-runtime",
            "ai-recording-runtime",
        ],
        "root lifecycle consumer inventory drifted",
    )
    ai_consumer = root_consumers[1]
    require(
        ai_consumer["eventSource"] == "djAppLifecycleEventForwarded",
        "AIRecording root lifecycle event source drifted",
    )
    require(
        inventory["directUIKitConsumers"] == [],
        "AIRecording must not remain a direct UIKit lifecycle consumer",
    )

    setup_body = function_body(source, "setupNotifications")
    require(
        "name: .djAppLifecycleEventForwarded" in setup_body,
        "AIRecording must subscribe to the root lifecycle event",
    )
    for direct_notification in (
        "UIApplication.didEnterBackgroundNotification",
        "UIApplication.willEnterForegroundNotification",
    ):
        require(
            direct_notification not in setup_body,
            f"AIRecording retained direct UIKit lifecycle observer: {direct_notification}",
        )

    bridge_body = function_body(source, "handleAppLifecycleEventForwarded")
    for required in (
        "AppLifecycleEventNotification.event(from: notification.userInfo)",
        "case .didEnterBackground:",
        "handleDidEnterBackground()",
        "case .willEnterForeground:",
        "handleWillEnterForeground()",
        "case .sceneConnected, .didBecomeActive, .willResignActive, .didDisconnect:",
    ):
        require(required in bridge_body, f"AIRecording root lifecycle mapping missing: {required}")

    background_body = function_body(source, "handleDidEnterBackground")
    for required in (
        "validateDialogEngineBinding(accountLease: accountLease, at: .runtime)",
        "DialogEngineManager.shared.stopDialog()",
        "stopSessionRecording(accountLease: accountLease)",
        "discardStaleSessionRecording()",
    ):
        require(required in background_body, f"AIRecording background behavior regressed: {required}")

    foreground_body = function_body(source, "handleWillEnterForeground")
    for required in (
        "view.window != nil",
        "validateDialogAccountLease(accountLease, at: .runtime)",
        "bindDialogEngine(accountLease: accountLease)",
        "DialogEngineManager.shared.delegate = self",
        "VoiceCloneService.shared.checkPendingTraining()",
        "discardStaleSessionRecording()",
    ):
        require(required in foreground_body, f"AIRecording foreground behavior regressed: {required}")

    print(
        "Product V4 AIRecording lifecycle forwarding check passed: root event mapping "
        "preserves lease-fenced recording stop and foreground rebind behavior"
    )


if __name__ == "__main__":
    main()
