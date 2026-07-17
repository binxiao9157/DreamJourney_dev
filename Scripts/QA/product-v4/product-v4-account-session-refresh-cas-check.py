#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ACTOR = ROOT / "DreamJourney/Sources/App/AccountSessionActor.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
STORE = ROOT / "DreamJourney/Sources/Services/BackendAuthSessionStore.swift"
MODEL = ROOT / "Scripts/QA/product-v4/account-session-refresh-cas-model-smoke.swift"
RUNNER = ROOT / "Scripts/QA/product-v4/run-account-session-refresh-cas-gate.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    actor = ACTOR.read_text()
    client = CLIENT.read_text()
    store = STORE.read_text()
    model = MODEL.read_text()
    runner = RUNNER.read_text()

    for snippet in (
        "struct AccountSessionRefreshLease",
        "let sessionVersion:",
        "func captureRefreshLease(",
        "func isCurrentRefreshLease(",
        "func commitRefreshedCredential(",
        "func invalidateRefreshLease(",
        "writer: @Sendable",
        "clear: @Sendable",
        "generationId == lease.generationId",
        "sessionVersion == lease.sessionVersion + 1",
    ):
        require(snippet in actor, f"AccountSessionActor refresh CAS contract missing: {snippet}")

    for snippet in (
        "let accountSessionActor = AccountSessionActor.shared",
        "let accountLease: AccountSessionRefreshLease",
        "captureRefreshLease(for:",
        "isCurrentRefreshLease(",
        "commitRefreshedCredential(",
        "invalidateRefreshLease(",
        "accountCredentialSnapshot(for:",
        "mutatesAuthenticatedSessionForRecoveryPolicy: Bool = true",
        "mutatesAuthenticatedSessionForRecoveryPolicy: false",
        "mutateAuthenticatedSession: mutatesAuthenticatedSessionForRecoveryPolicy",
    ):
        require(snippet in client, f"backend client generation binding missing: {snippet}")

    require(
        "guard mutateAuthenticatedSession else { return }" in client,
        "refresh recovery policy must update runtime authority without bypassing actor session CAS",
    )

    require(
        "store.replace" in client and "ifCurrentMatches: capturedSession" in client,
        "refresh writer must preserve Keychain session CAS",
    )
    require(
        "matchesCASIdentity" in store,
        "Keychain store must preserve session/family/version CAS",
    )

    for scenario in (
        "refresh must not rotate account generation",
        "refresh response after logout must be rejected",
        "account-A refresh must not overwrite account B",
        "refresh must not change token family",
        "terminal refresh error must invalidate the matching generation",
    ):
        require(scenario in model, f"refresh CAS model scenario missing: {scenario}")

    require("AccountSessionActor.swift" in runner, "runner must compile the production actor")
    require("account-session-refresh-cas-model-smoke.swift" in runner, "runner must execute the refresh CAS model")

    print("Product V4 AccountSession refresh CAS static check passed")


if __name__ == "__main__":
    main()
