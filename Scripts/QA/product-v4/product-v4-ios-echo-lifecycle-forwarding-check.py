#!/usr/bin/env python3
"""Guard Echo's migration to the root App/Scene lifecycle event boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ACCOUNT_LEASE = ROOT / "DreamJourney/Sources/App/AccountLease.swift"
APP_COORDINATOR = ROOT / "DreamJourney/Sources/App/AppCoordinator.swift"
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
ACCOUNT_LEASE_TESTS = ROOT / "DreamJourneyTests/AccountLeaseRuntimeTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def source_slice(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    require(start_index >= 0, f"missing source slice start: {start}")
    end_index = source.find(end, start_index + len(start))
    require(end_index >= 0, f"missing source slice end: {end}")
    return source[start_index:end_index]


def main() -> None:
    account_lease = read(ACCOUNT_LEASE)
    app_coordinator = read(APP_COORDINATOR)
    echo = read(ECHO)
    account_lease_tests = read(ACCOUNT_LEASE_TESTS)

    for required in (
        "enum AppLifecycleEventNotification",
        'static let eventKey = "event"',
        'static let sequenceKey = "sequence"',
        'static let runtimeDispositionKey = "runtimeDisposition"',
        "static func userInfo(",
        "static func event(from userInfo:",
        "static let djAppLifecycleEventForwarded",
    ):
        require(required in account_lease, f"root lifecycle notification contract missing: {required}")

    notification_contract = source_slice(
        account_lease,
        "enum AppLifecycleEventNotification",
        "struct AccountLeaseValidationDecision",
    )
    for forbidden in ("subjectId", "vaultId", "sessionId", "authorityEpoch"):
        require(
            f'"{forbidden}"' not in notification_contract,
            f"root lifecycle notification must not carry private authority field: {forbidden}",
        )

    forward_body = source_slice(
        app_coordinator,
        "func forward(\n        event: AppLifecycleEvent,",
        "    private static func refreshPrivateForegroundRuntime",
    )
    require(
        "NotificationCenter.default.post(" in forward_body
        and "name: .djAppLifecycleEventForwarded" in forward_body
        and "AppLifecycleEventNotification.userInfo(for: receipt)" in forward_body,
        "root forwarder must publish the value-minimized lifecycle event receipt",
    )

    observer_body = source_slice(
        echo,
        "private func observeEchoAppLifecycle()",
        "@objc private func echoAppLifecycleEventForwarded",
    )
    require(
        "name: .djAppLifecycleEventForwarded" in observer_body,
        "Echo must subscribe only to the root lifecycle event",
    )
    for forbidden in (
        "UIApplication.willResignActiveNotification",
        "UIApplication.didEnterBackgroundNotification",
        "UIApplication.willEnterForegroundNotification",
        "UIApplication.didBecomeActiveNotification",
    ):
        require(forbidden not in observer_body, f"Echo retained direct UIKit observer: {forbidden}")

    handler_body = source_slice(
        echo,
        "@objc private func echoAppLifecycleEventForwarded",
        "@objc private func echoAppWillResignActive()",
    )
    for required in (
        "AppLifecycleEventNotification.event(from: notification.userInfo)",
        "case .willResignActive:",
        "echoAppWillResignActive()",
        "case .didEnterBackground:",
        "echoAppDidEnterBackground()",
        "case .willEnterForeground:",
        "echoAppWillEnterForeground()",
        "case .didBecomeActive:",
        "echoAppDidBecomeActive()",
    ):
        require(required in handler_body, f"Echo root lifecycle mapping missing: {required}")

    require(
        "testLifecycleEventNotificationOnlyCarriesRoutingMetadata" in account_lease_tests,
        "missing value-minimized root lifecycle notification test",
    )
    print(
        "Product V4 Echo lifecycle forwarding check passed: Echo consumes the root event "
        "without retaining direct UIKit lifecycle observers"
    )


if __name__ == "__main__":
    main()
