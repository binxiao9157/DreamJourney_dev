#!/usr/bin/env python3
"""Guard WI-S0-01-08B account lifecycle entry-point ordering."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
USER_MANAGER = ROOT / "DreamJourney/Sources/Services/UserManager.swift"
APP_COORDINATOR = ROOT / "DreamJourney/Sources/App/AppCoordinator.swift"
RUNTIME = ROOT / "DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift"
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    brace = source.find("{", start)
    require(brace >= 0, f"function has no body: {signature}")
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError(f"unterminated function: {signature}")


def require_order(body: str, snippets: tuple[str, ...], contract: str) -> None:
    cursor = -1
    for snippet in snippets:
        index = body.find(snippet, cursor + 1)
        require(index >= 0, f"{contract} missing ordered step: {snippet}")
        cursor = index


def main() -> None:
    for path in (USER_MANAGER, APP_COORDINATOR, RUNTIME, ECHO):
        require(path.is_file(), f"missing production file: {path.relative_to(ROOT)}")

    user_manager = USER_MANAGER.read_text(encoding="utf-8")
    app_coordinator = APP_COORDINATOR.read_text(encoding="utf-8")
    runtime = RUNTIME.read_text(encoding="utf-8")
    echo = ECHO.read_text(encoding="utf-8")

    require(
        "actor AccountLifecycleTransitionController" in runtime,
        "lifecycle transitions must have one serialized controller",
    )
    require(
        "AccountLifecycleRuntimeRegistry.registrations" in runtime,
        "transition controller must install the production module registry",
    )
    require(
        "oldAccountLease" in runtime and "oldGeneration" in runtime,
        "transition controller must retain the pre-fence account scope",
    )
    require(
        "coordinator.perform" in runtime,
        "transition controller must execute the receipt-producing coordinator",
    )
    for module_index in range(1, 14):
        require(
            f'"LM-{module_index:02d}-' in runtime,
            f"production runtime registry missing LM-{module_index:02d}",
        )
    require(
        "teardownForAccountLifecycle" in runtime
        and "handleAccountLifecycle" in runtime,
        "production registry must call the scoped module teardown adapters",
    )

    logout = function_body(user_manager, "func logout()")
    require_order(
        logout,
        (
            "capture(forSubjectId:",
            "logoutAuthSession()",
            "AccountLifecycleTransitionController.shared.perform",
            "finalizeLogout",
        ),
        "logout lifecycle",
    )
    require(
        "NotificationCenter.default.post(name: .djUserDidLogout" not in logout,
        "logout request must not broadcast completion before teardown receipts are terminal",
    )
    finalize_logout = function_body(user_manager, "private func finalizeLogout(")
    require(
        "NotificationCenter.default.post(name: .djUserDidLogout" in finalize_logout,
        "logout completion must be broadcast only by the finalizer",
    )

    handle_logout = function_body(app_coordinator, "private func handleLogout()")
    require(
        "accountSessionActor.signOut" not in handle_logout,
        "AppCoordinator must not rotate the session generation a second time",
    )
    require(
        "AccountLeaseRuntime.shared.publish(session: nil)" not in handle_logout,
        "AppCoordinator must not independently fence the lifecycle transition",
    )
    require("transitionToAuth()" in handle_logout, "logout completion must route to auth")

    handle_suspension = function_body(
        app_coordinator,
        "private func handlePrivateAccessSuspended()",
    )
    require(
        "accountSessionActor.suspend" not in handle_suspension,
        "AppCoordinator must not suspend the actor a second time",
    )

    bootstrap = function_body(app_coordinator, "private func bootstrapAccountSession()")
    require(
        "performAfterExistingFence" in bootstrap,
        "cold-start authentication fallback must run lifecycle teardown before routing",
    )
    suspension = function_body(app_coordinator, "private func suspendActorAndShowAuth(")
    require(
        "AccountLifecycleTransitionController.shared.perform" in suspension,
        "private suspension must use the shared lifecycle controller",
    )
    require(
        ".djAccountLifecycleWillTeardown" in echo,
        "Echo must release provider/audio runtime after the account fence and before teardown",
    )

    print("PASS: Product V4 account lifecycle entry-point static check")


if __name__ == "__main__":
    main()
