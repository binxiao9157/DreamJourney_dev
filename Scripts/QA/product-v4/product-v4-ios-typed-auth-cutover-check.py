#!/usr/bin/env python3
"""Static and model gate for WI-S0-02-06 typed auth cutover."""

from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[3]
AUTH_STORE = ROOT / "DreamJourney/Sources/Services/BackendAuthSessionStore.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
USER_MANAGER = ROOT / "DreamJourney/Sources/Services/UserManager.swift"
APP_COORDINATOR = ROOT / "DreamJourney/Sources/App/AppCoordinator.swift"
ACCOUNT_SESSION_ACTOR = ROOT / "DreamJourney/Sources/App/AccountSessionActor.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"

BUSINESS_FALLBACK_FILES = (
    ROOT / "DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift",
    ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift",
    ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift",
    ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    brace = source.find("{", start)
    require(brace >= 0, f"missing function body: {signature}")
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError(f"unterminated function: {signature}")


def private_session_eligible(
    *,
    contract_version: int,
    user_id: str,
    expected_user_id: str,
    token_family_id: Optional[str],
    session_version: Optional[int],
) -> bool:
    return (
        contract_version == 2
        and user_id == expected_user_id
        and bool((token_family_id or "").strip())
        and (session_version or 0) > 0
    )


def main() -> None:
    auth_store = read(AUTH_STORE)
    client = read(CLIENT)
    user_manager = read(USER_MANAGER)
    app_coordinator = read(APP_COORDINATOR)
    account_session_actor = read(ACCOUNT_SESSION_ACTOR)
    app_delegate = read(APP_DELEGATE)

    require(
        "var isPrivateAccessEligible: Bool" in auth_store,
        "auth session must expose a fail-closed private-access eligibility contract",
    )
    for snippet in (
        "contractVersion == 2",
        "tokenFamilyId",
        "sessionVersion",
        "var isRefreshCredentialUsable: Bool",
        "func isPrivateAccessEligible(for userId: String)",
        "guard session.isPrivateAccessEligible else",
    ):
        require(snippet in auth_store, f"private-session lineage guard is missing: {snippet}")

    require(
        "func reconcilePrivateAccessSession() -> Bool" in user_manager,
        "launch must reconcile the local user with the Keychain auth session",
    )
    require(
        "BackendAuthSessionStore.shared.currentSession" in user_manager,
        "local account reconciliation must read the backend auth session",
    )
    require(
        "session.isPrivateAccessEligible(for: user.id)" in user_manager,
        "local account reconciliation must require matching v2 lineage",
    )
    for snippet in (
        "enum PrivateAccessState",
        "case validating",
        "case authenticated",
        "case suspended",
        "var requiresPrivateAccessValidation: Bool",
        "func markPrivateAccessValidated(",
        "func suspendPrivateAccess(",
    ):
        require(snippet in user_manager, f"private-access state transition is missing: {snippet}")
    require(
        "UserManager.shared.reconcilePrivateAccessSession()" in app_delegate,
        "App launch must reconcile auth before loading private owner state",
    )
    reconcile_offset = app_delegate.index("UserManager.shared.reconcilePrivateAccessSession()")
    private_load_offset = app_delegate.index("let currentKnowledgeUserId = UserManager.shared.canEnterPrivateUI")
    require(
        reconcile_offset < private_load_offset,
        "auth reconciliation must precede private knowledge loading",
    )
    require(
        "? UserManager.shared.currentUser?.id" in app_delegate,
        "private knowledge must stay detached until this process validates the session",
    )
    require(
        "UserManager.shared.canEnterPrivateUI" in app_coordinator,
        "root routing must use authenticated private-UI eligibility",
    )
    for snippet in (
        "actor AccountSessionActor",
        "func bootstrap(",
        "coldStartOnlineValidationRequired",
        "coldStartProfileRecoveryRequired",
        "coldStartProfileMismatchQuarantined",
    ):
        require(snippet in account_session_actor, f"cold-start actor contract is missing: {snippet}")
    require(
        "accountSessionActor.bootstrap(" in app_coordinator,
        "root routing must consume the AccountSessionActor bootstrap receipt",
    )
    require(
        "AccountSessionTransitionReceipt" in app_coordinator,
        "root routing must retain an actor transition receipt",
    )
    require(
        "resumePrivateAccessSession" in app_coordinator,
        "cold start must validate the cached session before showing private tabs",
    )
    require(
        "if UserManager.shared.isLoggedIn" not in app_coordinator,
        "local UserDefaults login state must not authorize the private three-tab UI",
    )
    start_body = function_body(app_coordinator, "func start()")
    require(
        "UserManager.shared.canEnterPrivateUI" not in start_body,
        "cached profile state must not choose the cold-start root route",
    )

    for snippet in (
        "case sessionUpgradeRequired",
        "authenticatedSession.isPrivateAccessEligible",
        "EndpointDescriptor",
        '"X-DreamJourney-Client-Build"',
        '"X-DreamJourney-Auth-Contract-Version"',
        "UserManager.shared.canEnterPrivateUI",
        "UserManager.shared.suspendPrivateAccess(",
        "func resumePrivateAccessSession(",
        "guard session.isPrivateAccessEligible else",
        "sessionUserAssertions",
        "allSatisfy",
    ):
        require(snippet in client, f"typed request cutover contract is missing: {snippet}")
    preflight = client.index("authenticatedSession.isPrivateAccessEligible")
    network = client.index("AF.request(", preflight)
    require(preflight < network, "legacy sessions must fail before network I/O")

    for signature, assertion in (
        ("func listArchiveItems(", "sessionUserId: userId"),
        ("func listMailboxLetters(", "sessionUserId: userId"),
        ("func fetchVoiceCloneProfiles(", "sessionUserId: userId"),
        ("func listFamilyMembers(", "sessionUserId: userId"),
        ("func latestCareSnapshot(", "sessionUserId: userId"),
        ("func getTimeLetterDetail(", "sessionUserId: viewerUserId"),
    ):
        require(
            assertion in function_body(client, signature),
            f"typed self/viewer owner assertion is missing from {signature}",
        )

    for path in BUSINESS_FALLBACK_FILES:
        source = read(path)
        require(
            '?? "user_001"' not in source,
            f"private business owner fallback remains in {path.relative_to(ROOT)}",
        )

    require(
        private_session_eligible(
            contract_version=2,
            user_id="account-a",
            expected_user_id="account-a",
            token_family_id="family-a",
            session_version=2,
        ),
        "valid v2 session model must be eligible",
    )
    require(
        not private_session_eligible(
            contract_version=1,
            user_id="account-a",
            expected_user_id="account-a",
            token_family_id=None,
            session_version=None,
        ),
        "legacy v1 session model must be denied",
    )
    require(
        not private_session_eligible(
            contract_version=2,
            user_id="account-a",
            expected_user_id="account-b",
            token_family_id="family-a",
            session_version=2,
        ),
        "owner mismatch model must be denied",
    )
    require(
        not private_session_eligible(
            contract_version=2,
            user_id="account-a",
            expected_user_id="account-a",
            token_family_id="",
            session_version=0,
        ),
        "incomplete v2 lineage model must be denied",
    )

    print("Product V4 iOS typed auth cutover check passed")


if __name__ == "__main__":
    main()
