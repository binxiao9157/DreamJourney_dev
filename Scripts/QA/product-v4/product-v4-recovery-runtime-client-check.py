#!/usr/bin/env python3
"""Guard the iOS recovery runtime fence and its central request integration."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
STORE = ROOT / "DreamJourney/Sources/Services/ReleasePolicyStore.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    store = STORE.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")

    for token in (
        "enum BackendRecoveryRuntimeMode",
        "struct BackendRecoveryRuntimePolicy",
        "final class RecoveryRuntimePolicyStore",
        "static let unresolved",
        "func requestDecision(method:",
        "djRecoveryAuthorityEpochDidChange",
    ):
        require(token in store, f"missing recovery runtime model: {token}")

    for token in (
        "let recovery: BackendRecoveryRuntimePolicy",
        "BackendRecoveryRuntimePolicy(json:",
        "recoveryRuntimePolicyStore.update",
        "case recoveryAccessDenied",
        "allowsRecoveryRefresh:",
        "recoveryRuntimePolicy(from:",
    ):
        require(token in client, f"missing recovery client integration: {token}")

    gate = client.index("RecoveryRuntimePolicyStore.shared.requestDecision")
    request = client.index("AF.request(url")
    require(gate < request, "recovery decision must run before the network request")
    require(
        "RuntimeCapabilitySnapshotStore.shared.invalidate()" in client,
        "authority epoch change must invalidate runtime capability snapshots",
    )
    require(
        "authSessionStore.clear()" in client,
        "signedOut recovery mode must clear the backend auth session",
    )
    runtime_request = client[client.index("func fetchRuntimeConfig"):client.index("func fetchReleasePolicy")]
    require("authPolicy: .anonymous" in runtime_request, "runtime config must remain readable with a stale token")
    require("allowsRefresh: false" in runtime_request, "runtime config must not enter auth refresh recursion")

    print("Product V4 recovery runtime client check passed")


if __name__ == "__main__":
    main()
