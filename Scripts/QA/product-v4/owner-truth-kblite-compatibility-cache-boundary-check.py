#!/usr/bin/env python3
"""Guard the default-off Owner Truth compatibility cache boundary."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
INVENTORY = ROOT / "Scripts/QA/product-v4/account-store-inventory-v1.json"
RELATIVE_SOURCE = str(SOURCE.relative_to(ROOT))
RELATIVE_GUARD = "Scripts/QA/product-v4/owner-truth-kblite-compatibility-cache-boundary-check.py"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))

    for marker in (
        "enum OwnerTruthKBLiteCompatibilityQAGate",
        "#if DEBUG || UI_QA_SIMULATOR",
        "return ProcessInfo.processInfo.arguments.contains(launchArgument)",
        "return false",
        "final class OwnerTruthKBLiteCompatibilityStore",
        "subjectID = accountLease.subjectId",
        "vaultID = accountLease.vaultId",
        "sessionID = accountLease.sessionId",
        "generation = accountLease.generation",
        "generationID = accountLease.generationId",
        "leaseAuthorityEpoch = accountLease.authorityEpoch",
        "func matches(_ accountLease: AccountLease)",
        "validate(accountLease, at: .request)",
        "validate(accountLease, at: .commit)",
        "validate(accountLease, at: .runtime)",
        "discardCachedProjection()",
    ):
        require(marker in source, f"Owner Truth compatibility cache marker missing: {marker}")

    instantiations = []
    for candidate in (ROOT / "DreamJourney/Sources").rglob("*.swift"):
        if candidate == SOURCE:
            continue
        if "OwnerTruthKBLiteCompatibilityStore(" in candidate.read_text(encoding="utf-8", errors="ignore"):
            instantiations.append(str(candidate.relative_to(ROOT)))
    require(
        not instantiations,
        "default-off compatibility cache has runtime instantiation(s): " + ", ".join(instantiations),
    )

    exclusions = (inventory.get("discovery") or {}).get("exclusions") or []
    exclusion = next((item for item in exclusions if item.get("path") == RELATIVE_SOURCE), None)
    require(exclusion is not None, "Owner Truth compatibility cache is not an explicit inventory exclusion")
    require(exclusion.get("guard") == RELATIVE_GUARD, "Owner Truth compatibility exclusion guard drifted")
    require("Default-off" in exclusion.get("reason", ""), "Owner Truth compatibility exclusion reason drifted")

    print("Owner Truth KBLite compatibility cache boundary check passed")


if __name__ == "__main__":
    main()
