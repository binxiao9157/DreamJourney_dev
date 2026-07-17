#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ACTOR = ROOT / "DreamJourney/Sources/App/AccountSessionActor.swift"
COORDINATOR = ROOT / "DreamJourney/Sources/App/AppCoordinator.swift"
USER_MANAGER = ROOT / "DreamJourney/Sources/Services/UserManager.swift"
BACKEND_CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
INVENTORY = ROOT / "Scripts/QA/product-v4/account-store-inventory-v1.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


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


def main() -> None:
    actor = ACTOR.read_text()
    coordinator = COORDINATOR.read_text()
    user_manager = USER_MANAGER.read_text()
    backend_client = BACKEND_CLIENT.read_text()
    app_delegate = APP_DELEGATE.read_text()
    project = PROJECT.read_text()
    inventory = json.loads(INVENTORY.read_text())

    for snippet in (
        "actor AccountSessionActor",
        "struct AccountSession:",
        "let subjectId:",
        "let vaultId:",
        "let sessionId:",
        "let tokenFamilyId:",
        "let generation:",
        "let generationId:",
        "let state:",
        "let activatedAt:",
        "case signedOut",
        "case activating",
        "case active",
        "case switching",
        "case suspended",
        "case deleting",
        "enum AccountSessionActivationPhase",
        "case prepared",
        "case sessionSaved",
        "case storesMounted",
        "case profileCached",
        "case committed",
        "func bootstrap(",
        "func recordActivationPhase(",
        "func activateValidatedCredential(",
        "expectedGeneration:",
        "func activateVerifiedLogin(",
        "func beginSwitch(",
        "func beginDeleting(",
        "func signOut(",
        "accountSignOutRejectedAsStale",
        'storageKey = "dj.accountSession.activationJournal.v1"',
        "generation = priorEntry?.generation ?? 0",
        "generationId = UUID()",
        "rotateGeneration: false",
    ):
        require(snippet in actor, f"AccountSessionActor contract missing: {snippet}")
    require("accessToken" not in actor, "AccountSessionActor must not retain access tokens")
    require("refreshToken" not in actor, "AccountSessionActor must not retain refresh tokens")
    require("subjectId:" not in function_body(actor, "func record("), "activation journal must not persist subject id")
    require("sessionId:" not in function_body(actor, "func record("), "activation journal must not persist session id")

    start_body = function_body(coordinator, "func start()")
    require("bootstrapAccountSession()" in start_body, "root start must bootstrap AccountSessionActor")
    require("UserManager.shared.canEnterPrivateUI" not in start_body, "cached UserManager state must not choose root route")
    for snippet in (
        "private let accountSessionActor: AccountSessionActor",
        "AccountSessionTransitionReceipt",
        "accountSessionActor.bootstrap(",
        "recordActivationPhase(",
        "validateCachedPrivateAccess(expectedGeneration:",
        "activateValidatedCredential(",
        "accountSessionActor.activateVerifiedLogin(",
        "accountSessionReceipt?.state == .active",
        "accountSessionReceipt?.rootRoute == .privateUI",
        "accountSessionActor.signOut(",
        "accountSessionActor.suspend(",
    ):
        require(snippet in coordinator, f"root composition is missing actor boundary: {snippet}")

    require(
        "func accountSessionCredentialSnapshot() -> AccountSessionCredentialSnapshot?" in user_manager,
        "UserManager must project display cache and Keychain lineage into a value-only actor credential",
    )
    require("BackendAuthSessionStore.shared.currentSession" in user_manager, "actor credential must come from Keychain session")
    require(".prevalidatedTestOnly" in user_manager, "UIQA bypass must be explicit and test-only")
    require("#if UI_QA_SIMULATOR" in user_manager, "UIQA credential must not exist in release composition")

    reconcile_body = function_body(user_manager, "func reconcilePrivateAccessSession()")
    require(
        "session.isPrivateAccessEligible" in reconcile_body,
        "cold-start reconciliation must treat a valid Keychain session as recoverable authority",
    )
    require(
        "session.isPrivateAccessEligible(for:" not in reconcile_body,
        "cached profile mismatch must not invalidate an otherwise valid Keychain session",
    )
    mismatch_start = reconcile_body.index("if capturedUser?.id != session.userId")
    mismatch_body = reconcile_body[mismatch_start:]
    require(
        "storedCurrentUser = nil" in mismatch_body
        and "removeObject(forKey: kUserKey)" in mismatch_body,
        "mismatched display profile must be quarantined before online validation",
    )
    require(
        "BackendAuthSessionStore.shared.clear()" not in mismatch_body,
        "profile quarantine must preserve the valid Keychain session for online recovery",
    )

    resume_body = function_body(backend_client, "func resumePrivateAccessSession(")
    prepare_offset = resume_body.index("prepareCachedProfileForValidatedSession")
    activate_offset = resume_body.index("markPrivateAccessValidated")
    require(
        prepare_offset < activate_offset,
        "validated session subject must rebuild the display profile before private UI activation",
    )

    reconcile_offset = app_delegate.index("UserManager.shared.reconcilePrivateAccessSession()")
    private_store_offset = app_delegate.index("let currentKnowledgeUserId = UserManager.shared.canEnterPrivateUI")
    require(reconcile_offset < private_store_offset, "session reconciliation must precede private store mount")

    require("AccountSessionActor.swift in Sources" in project, "AccountSessionActor must belong to the app target")
    actor_inventory = next(
        surface
        for surface in inventory["surfaces"]
        if surface["surfaceId"] == "S02.profile-display-cache"
    )
    require(
        "DreamJourney/Sources/App/AccountSessionActor.swift" in actor_inventory["sourcePaths"],
        "activation journal must be registered in AccountStoreInventory",
    )
    require(
        "dj.accountSession.activationJournal.v1" in actor_inventory["pathOrKey"],
        "activation journal key must be registered in AccountStoreInventory",
    )

    print("Product V4 AccountSessionActor static check passed")


if __name__ == "__main__":
    main()
