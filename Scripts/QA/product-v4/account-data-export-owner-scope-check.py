#!/usr/bin/env python3
"""Keep temporary account exports bound to the captured account lease."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PROFILE = ROOT / "DreamJourney/Sources/Modules/Profile/ProfileViewController.swift"
BACKEND_CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
LIFECYCLE_REGISTRY = ROOT / "DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift"
INVENTORY = ROOT / "Scripts/QA/product-v4/account-store-inventory-v1.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    profile = PROFILE.read_text(encoding="utf-8")
    backend_client = BACKEND_CLIENT.read_text(encoding="utf-8")
    lifecycle_registry = LIFECYCLE_REGISTRY.read_text(encoding="utf-8")
    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))

    for marker in (
        "import CryptoKit",
        "enum AccountDataExportTemporaryStore",
        "AccountDataExportTemporaryStore.write(export, accountLease: accountLease)",
        "AccountDataExportTemporaryStore.remove(fileURL, accountLease: accountLease)",
        "DreamJourneyDataExports",
        "SHA256.hash",
        "accountLease.subjectId",
        "accountLease.vaultId",
        "accountLease.sessionId",
        "accountLease.generation",
        "accountLease.generationId",
        "accountLease.authorityEpoch",
        "FileProtectionType.complete",
        "options: .atomic",
        "retireLegacyUnscopedExports",
        "issueAccountDataExportDownloadCredential(",
        "credential.downloadToken",
    ):
        require(marker in profile, f"account export owner-scope marker missing: {marker}")

    for marker in (
        "struct AccountDataExportDownloadCredentialContract",
        'path: "/auth/data-export/jobs/\\(jobId)/download-credential"',
        'additionalHeaders: ["X-DreamJourney-Export-Token": normalizedToken]',
    ):
        require(marker in backend_client, f"account export credential marker missing: {marker}")
    status_snapshot = profile[
        profile.index("struct AccountDataExportJobStatusSnapshot"):
        profile.index("enum AccountDataExportJobStatusStore")
    ]
    require(
        "downloadToken" not in status_snapshot,
        "plaintext export credentials must never persist in the resumable status snapshot",
    )

    require(
        "writeAccountDataExport(\n        _ export: AccountDataExportContract,\n        accountLease: AccountLease" in profile,
        "Profile export write must require a captured AccountLease",
    )
    require(
        "presentAccountDataExportShareSheet(\n        fileURL: URL,\n        accountLease: AccountLease" in profile,
        "Profile share sheet must retain the captured AccountLease",
    )
    require(
        "AccountDataExportTemporaryStore.teardownForAccountLifecycle" in lifecycle_registry,
        "account lifecycle teardown must remove owner-scoped temporary exports",
    )

    surfaces = inventory.get("surfaces") or []
    surface = next(
        (
            candidate
            for candidate in surfaces
            if candidate.get("surfaceId") == "S05.temporary-knowledge-share-exports"
        ),
        None,
    )
    require(surface is not None, "temporary export inventory surface is missing")
    require(
        "DreamJourney/Sources/Modules/Profile/ProfileViewController.swift"
        in (surface.get("sourcePaths") or []),
        "Profile export source is not registered in the temporary export inventory",
    )
    require(
        "Scripts/QA/product-v4/account-data-export-owner-scope-check.py"
        in (surface.get("currentChecks") or []),
        "temporary export inventory does not own this static check",
    )

    print("Account data export owner-scope check passed")


if __name__ == "__main__":
    main()
