#!/usr/bin/env python3
"""Guard the no-behavior UIKit AppComposition seam for WI-S1-03-02."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
APP_COORDINATOR = ROOT / "DreamJourney/Sources/App/AppCoordinator.swift"
TAB_COORDINATOR = ROOT / "DreamJourney/Sources/App/TabCoordinator.swift"
ACCOUNT_LEASE = ROOT / "DreamJourney/Sources/App/AccountLease.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
SCENE_DELEGATE = ROOT / "DreamJourney/Sources/SceneDelegate.swift"
ACCOUNT_LEASE_TESTS = ROOT / "DreamJourneyTests/AccountLeaseRuntimeTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    app_coordinator = read(APP_COORDINATOR)
    tab_coordinator = read(TAB_COORDINATOR)
    account_lease = read(ACCOUNT_LEASE)
    app_delegate = read(APP_DELEGATE)
    scene_delegate = read(SCENE_DELEGATE)
    account_lease_tests = read(ACCOUNT_LEASE_TESTS)

    for required in (
        "struct AppFeatureRuntimeContext",
        "lifecycleGeneration == accountLease.generation",
        "normalizedAuthorityEpoch == accountLease.authorityEpoch",
    ):
        require(required in account_lease, f"runtime context contract missing: {required}")

    for required in (
        "final class AppComposition",
        "final class AppFeatureFactory",
        "private let appComposition: AppComposition",
        "appComposition.makeTabCoordinator(",
        "AccountLeaseRuntimePort",
        "releasePolicyAuthorityEpochProvider",
        "AppFeatureRuntimeContext(",
        "accountLeaseRuntime.validate(accountLease, at: .ui).allowed",
        "featureFactory.makeTabCoordinator(runtimeContext: runtimeContext)",
        "protocol AppLaunchPreparing",
        "final class AppLaunchPreparer",
        "func prepareForProcessLaunch()",
        "appComposition.prepareForProcessLaunch()",
    ):
        require(required in app_coordinator, f"app composition contract missing: {required}")
    require(
        "let tabCoordinator = TabCoordinator()" not in app_coordinator,
        "AppCoordinator must not bypass AppComposition with direct TabCoordinator construction",
    )

    for required in (
        "private let runtimeContext: AppFeatureRuntimeContext",
        "private let featureFactory: AppFeatureFactory",
        "featureFactory.makeArchiveNavigationController(",
        "featureFactory.makeEchoNavigationController(",
        "featureFactory.makeProfileNavigationController(",
    ):
        require(required in tab_coordinator, f"tab composition propagation missing: {required}")
    for forbidden in (
        "UINavigationController(rootViewController: MemoryArchiveViewController())",
        "UINavigationController(rootViewController: EchoViewController())",
        "let profileVC = ProfileViewController()",
    ):
        require(forbidden not in tab_coordinator, f"TabCoordinator bypasses feature factory: {forbidden}")

    for required in (
        "let appComposition = AppComposition()",
        "appComposition.prepareForProcessLaunch()",
    ):
        require(required in app_delegate, f"AppDelegate composition boundary missing: {required}")
    for forbidden in (
        "UserManager.shared.reconcilePrivateAccessSession()",
        "KnowledgeSyncCoordinator.shared.userDidChange(to:",
        "KBLiteManager.shared.switchUser(to:",
    ):
        require(
            forbidden not in app_delegate,
            f"AppDelegate must not own private startup side effect: {forbidden}",
        )
    require(
        "AppCoordinator(window: window, appComposition: appComposition)" in scene_delegate,
        "SceneDelegate must pass the root AppComposition into AppCoordinator",
    )

    require(
        "testFeatureRuntimeContextRejectsMismatchedLifecycleOrPolicyAuthority" in account_lease_tests,
        "missing deterministic AppFeatureRuntimeContext contract test",
    )
    for required in (
        "testAppLaunchPreparerReconcilesBeforeResolvingPrivateKnowledgeScope",
        "testAppCompositionPreparesLaunchOnlyOnce",
    ):
        require(required in account_lease_tests, f"missing composition launch test: {required}")
    print(
        "Product V4 iOS composition seam check passed: AppCoordinator captures a coherent "
        "runtime context, AppDelegate/SceneDelegate share one AppComposition, and "
        "TabCoordinator builds all root tabs through AppFeatureFactory"
    )


if __name__ == "__main__":
    main()
