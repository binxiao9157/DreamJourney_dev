#!/usr/bin/env python3
"""Guard WI-S0-05-06 G0: truthful, owner-scoped local Data Rights receipts."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
PROFILE = ROOT / "DreamJourney/Sources/Modules/Profile/ProfileViewController.swift"
LIFECYCLE = ROOT / "DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift"
INVENTORY = ROOT / "Scripts/QA/product-v4/account-store-inventory-v1.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    client = CLIENT.read_text(encoding="utf-8")
    profile = PROFILE.read_text(encoding="utf-8")
    lifecycle = LIFECYCLE.read_text(encoding="utf-8")
    inventory = INVENTORY.read_text(encoding="utf-8")

    for marker in (
        "struct AccountDataRightsStatusSnapshot: Codable, Equatable",
        'let rights = json["rights"] as? [String: Any]',
        'let policy = json["policy"] as? [String: Any]',
        'let requestId = rights["requestId"] as? String',
        'let retentionDays = Self.intValue(policy["retentionDays"])',
        'let dataExportSupported = policy["dataExportSupported"] as? Bool',
        'let dataExportState = policy["dataExportState"] as? String',
        "externalCleanupState",
        "case pendingExternalEvidence",
        'externalCleanup?["verifiedComplete"] as? Bool == true',
        'externalCleanup?["accessState"] as? String == "revoked"',
        "self.externalCleanupState = verifiedExternalCleanup",
        "externalCleanupVerified = verifiedExternalCleanup",
        "dataRightsStatusSnapshot = AccountDataRightsStatusSnapshot(json: json)",
    ):
        require(marker in client, f"data rights client contract marker missing: {marker}")

    require(
        "case completed" in client[client.index("enum AccountDataRightsExternalCleanupState"):client.index("struct AccountDataRightsStatusSnapshot")],
        "client must expose completed only for verified external cleanup evidence",
    )
    require(
        'case "pending", "dispatched", "accepted", "completed":\n            return .pendingExternalEvidence' in client,
        "completed rights request must remain pending external evidence",
    )

    for marker in (
        "enum AccountLeaseScopeDigest",
        "enum AccountDataRightsReceiptStore",
        "dj.accountDataRightsReceipt.v1.",
        "AccountLeaseRuntime.shared.validate(accountLease, at: .request).allowed",
        "AccountLeaseRuntime.shared.validate(accountLease, at: .commit).allowed",
        "AccountLeaseRuntime.shared.validate(accountLease, at: .ui).allowed",
        "!snapshot.externalCleanupVerified",
        "try AccountDataRightsReceiptStore.write(",
        "deletionAcceptance.dataRightsStatusSnapshot",
    ):
        require(marker in profile, f"owner-scoped data rights receipt marker missing: {marker}")

    require(
        "AccountDataRightsReceiptStore.teardownForAccountLifecycle" in lifecycle,
        "account lifecycle must retire the data rights receipt with its old lease",
    )
    require(
        "accountDataRightsReceiptTeardownFailed" in lifecycle,
        "receipt teardown failure must remain observable to lifecycle cleanup",
    )
    require(
        "S14.account-data-rights-receipt-cache" in inventory,
        "account store inventory must register the data rights receipt cache",
    )
    require(
        "account-data-rights-status-owner-scope-check.py" in inventory,
        "inventory must own the data rights receipt gate",
    )
    require(
        'path: "/auth/data-rights' not in client,
        "G0 must not add a new unauthenticated data-rights status route",
    )

    print("Account data rights status owner-scope check passed")


if __name__ == "__main__":
    main()
