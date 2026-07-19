#!/usr/bin/env python3
"""Static contract guard for WI-S1-03-09 notification/deeplink routing."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {signature}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def main() -> None:
    lease = read("DreamJourney/Sources/App/AccountLease.swift")
    app_delegate = read("DreamJourney/Sources/AppDelegate.swift")
    scene_delegate = read("DreamJourney/Sources/SceneDelegate.swift")
    app_coordinator = read("DreamJourney/Sources/App/AppCoordinator.swift")
    tab_coordinator = read("DreamJourney/Sources/App/TabCoordinator.swift")
    lifecycle = read("DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift")
    scheduler = read(
        "DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift"
    )

    for declaration in (
        "enum NotificationRuntimeRouteKind",
        "enum NotificationRuntimeRouteAction",
        "enum NotificationRuntimeRouteSource",
        "struct NotificationRuntimeRoutePayload",
        "struct NotificationRuntimeRoute",
        "final class NotificationRuntimeRouteInbox",
    ):
        require(declaration in lease, f"missing runtime route declaration: {declaration}")

    payload_body = function_body(lease, "func matches(_ accountLease: AccountLease)")
    for field in (
        "generation == accountLease.generation",
        'values: ["subject", accountLease.subjectId]',
        'values: ["generation-id", accountLease.generationId.uuidString]',
        'values: ["vault", accountLease.vaultId]',
        'values: ["authority-epoch", accountLease.authorityEpoch]',
        'values: ["resource-owner", accountLease.subjectId]',
    ):
        require(field in payload_body, f"route ownership match omits: {field}")
    require(
        "UserDefaults" not in lease[lease.find("final class NotificationRuntimeRouteInbox") :],
        "runtime route inbox must not persist notification/deeplink payloads",
    )
    consume = function_body(lease, "func consumeRoutes(accountLease: AccountLease)")
    for checkpoint in (".request", ".runtime", ".ui"):
        require(checkpoint in consume, f"route consumption must validate lease at {checkpoint}")
    require(
        "pendingRoutes.removeAll()" in consume,
        "consumed or rejected routes must not remain queued",
    )
    teardown = function_body(lease, "func teardownForAccountLifecycle(oldAccountLease: AccountLease?)")
    require(
        "pendingRoutes.removeAll" in teardown and "payload.matches(oldAccountLease)" in teardown,
        "account lifecycle must remove only the old lease's queued routes",
    )

    make_request = function_body(scheduler, "private func makeRequest(")
    for value in (
        "NotificationRuntimeRoutePayload.Key.schemaVersion",
        "NotificationRuntimeRoutePayload.Key.action",
        "NotificationRuntimeRouteAction.open.rawValue",
    ):
        require(value in make_request, f"delayed notification must emit runtime route metadata: {value}")

    require(
        "UNUserNotificationCenter.current().delegate = self" in app_delegate,
        "AppDelegate must own UNUserNotificationCenter ingress",
    )
    for signature in (
        "didReceiveRemoteNotification userInfo:",
        "willPresent notification:",
        "didReceive response:",
    ):
        require(signature in app_delegate, f"AppDelegate missing notification ingress: {signature}")
    ingress = function_body(app_delegate, "private func enqueueNotificationRuntimeRoute(")
    require(
        "NotificationRuntimeRouteInbox.shared.ingest" in ingress,
        "AppDelegate must queue notification payload through the owner router",
    )
    require(
        ".djNotificationRuntimeRouteQueued" in ingress,
        "AppDelegate must wake the root router only after a payload queues",
    )
    will_present = function_body(app_delegate, "willPresent notification:")
    require(
        "NotificationRuntimeRouteInbox.shared.canPresent" in will_present,
        "foreground notification display must fail closed on owner mismatch",
    )

    for signature in (
        "connectionOptions.notificationResponse",
        "connectionOptions.urlContexts.forEach",
        "func scene(_ scene: UIScene, openURLContexts",
        "func scene(_ scene: UIScene, continue userActivity:",
    ):
        require(signature in scene_delegate, f"SceneDelegate missing deferred ingress: {signature}")

    for declaration in (
        "notificationRuntimeRouteInbox: NotificationRuntimeRouteInbox",
        ".djNotificationRuntimeRouteQueued",
        "func receiveNotificationRuntimeRoute(",
        "func receiveNotificationRuntimeDeepLink(",
        "private func routePendingNotificationRuntimeRoutesIfPossible()",
    ):
        require(declaration in app_coordinator, f"AppCoordinator missing route boundary: {declaration}")
    app_route = function_body(
        app_coordinator, "private func routePendingNotificationRuntimeRoutesIfPossible()"
    )
    for checkpoint in (".request", ".runtime", ".ui"):
        require(checkpoint in app_route, f"AppCoordinator route must validate at {checkpoint}")
    require(
        "notificationRuntimeRouteInbox.consumeRoutes" in app_route,
        "AppCoordinator must consume only after private runtime is ready",
    )
    require(
        "selectNotificationRuntimeRoute" in app_route,
        "AppCoordinator must delegate neutral destination selection to TabCoordinator",
    )
    for forbidden in ("startDialog", "DigitalHuman", "VoiceClone", "MemoirTTS"):
        require(forbidden not in app_route, f"notification route must not activate runtime: {forbidden}")

    tab_route = function_body(tab_coordinator, "func selectNotificationRuntimeRoute(")
    require(
        "route.accountLease == runtimeContext.accountLease" in tab_route,
        "Tab selection must retain the exact validated lease",
    )
    require(
        "route.payload.kind.selectedTabIndex" in tab_route,
        "Tab selection must use the route kind's neutral destination",
    )
    for forbidden in ("EchoViewController", "DigitalHuman", "VoiceClone", "DialogEngine"):
        require(forbidden not in tab_route, f"Tab route must not activate runtime: {forbidden}")

    lifecycle_teardown = function_body(
        lifecycle, "private static func teardownMessageNotificationEffects("
    )
    require(
        "NotificationRuntimeRouteInbox.shared.teardownForAccountLifecycle" in lifecycle_teardown,
        "message lifecycle teardown must clear old account route inbox entries",
    )

    print("PASS: WI-S1-03-09 notification/deeplink runtime route static check")


if __name__ == "__main__":
    main()
