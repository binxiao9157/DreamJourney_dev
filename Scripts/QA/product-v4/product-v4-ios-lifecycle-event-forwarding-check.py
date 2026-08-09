#!/usr/bin/env python3
"""Guard the first App/Scene lifecycle forwarding seam for WI-S1-03-03."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ACCOUNT_LEASE = ROOT / "DreamJourney/Sources/App/AccountLease.swift"
APP_COORDINATOR = ROOT / "DreamJourney/Sources/App/AppCoordinator.swift"
SCENE_DELEGATE = ROOT / "DreamJourney/Sources/SceneDelegate.swift"
ACCOUNT_LEASE_TESTS = ROOT / "DreamJourneyTests/AccountLeaseRuntimeTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    account_lease = read(ACCOUNT_LEASE)
    app_coordinator = read(APP_COORDINATOR)
    scene_delegate = read(SCENE_DELEGATE)
    account_lease_tests = read(ACCOUNT_LEASE_TESTS)

    for required in (
        "enum AppLifecycleEvent",
        "case sceneConnected",
        "case willEnterForeground",
        "case didEnterBackground",
        "struct AppLifecycleEventReceipt",
        "var canRunPrivateForegroundRefresh",
    ):
        require(required in account_lease, f"lifecycle event model missing: {required}")

    for required in (
        "final class AppLifecycleEventForwarder",
        "typealias PrivateForegroundRefresh = @MainActor (AppFeatureRuntimeContext) -> Void",
        "func handleSceneLifecycleEvent(_ event: AppLifecycleEvent)",
        "private func currentFeatureRuntimeContext()",
        "AccountLeaseRuntime.shared.validate(",
        "at: .runtime",
        "at: .commit",
        "FamilyRepository.shared.bootstrapCurrentUserFromBackend",
        'reason: "foregroundAfterFamilyRefresh"',
    ):
        require(required in app_coordinator, f"lifecycle forwarding contract missing: {required}")

    for event in (
        ".sceneConnected",
        ".didBecomeActive",
        ".willResignActive",
        ".willEnterForeground",
        ".didEnterBackground",
        ".didDisconnect",
    ):
        require(
            f"handleSceneLifecycleEvent({event})" in scene_delegate,
            f"SceneDelegate does not forward {event}",
        )

    for forbidden in (
        "FamilyRepository.shared.bootstrapCurrentUserFromBackend",
        "KnowledgeSyncCoordinator.shared.synchronizeCurrentUser",
    ):
        require(
            forbidden not in scene_delegate,
            f"SceneDelegate must not own private lifecycle effect: {forbidden}",
        )

    require(
        "testLifecycleEventReceiptMinimizesActiveRuntimeContext" in account_lease_tests,
        "missing deterministic lifecycle event receipt test",
    )
    print(
        "Product V4 iOS lifecycle event forwarding check passed: SceneDelegate forwards "
        "only, while AppCoordinator preserves MainActor and validates the active lease "
        "before foreground effects"
    )


if __name__ == "__main__":
    main()
