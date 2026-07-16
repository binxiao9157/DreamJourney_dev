#!/usr/bin/env python3
"""Validate the value-free WI-S0-03-07 credential rotation receipt."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
RECEIPT_PATH = ROOT / "docs/superpowers/status/2026-07-16-wi-s0-03-07-credential-rotation-receipt.json"
STATUS_PATH = ROOT / "docs/superpowers/status/2026-07-16-wi-s0-03-07-credential-rotation-revoke-drain.md"
FORBIDDEN_KEYS = {
    "value",
    "rawValue",
    "context",
    "authorization",
    "headers",
    "credential",
    "appKey",
    "accessToken",
    "appToken",
    "apiKey",
    "secretKey",
    "backendAPIToken",
    "fingerprint",
}
ROTATION_FAMILIES = {
    "BACKEND_SHARED_TOKEN",
    "BEARER_TOKEN",
    "DEEPSEEK_API_KEY",
    "TENCENT_CLOUD_SECRET_KEY",
    "TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN",
    "VOLCENGINE_ACCESS_TOKEN",
    "VOLCENGINE_APP_TOKEN",
    "VOLCENGINE_SECRET_KEY",
}
REQUIRED_CONTAINMENT = {
    "responseCredentialBoundary",
    "mobileCredentialInjection",
    "qaCredentialArtifacts",
    "realtimeDirectMobile",
    "digitalHumanDirectMobile",
    "digitalHumanLeaseDrain",
    "currentSourceCredentialLiterals",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def assert_value_free(value: Any, path: str = "receipt") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            require(key not in FORBIDDEN_KEYS, f"{path} contains forbidden key {key}")
            assert_value_free(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            assert_value_free(child, f"{path}[{index}]")


def main() -> None:
    receipt = json.loads(RECEIPT_PATH.read_text(encoding="utf-8"))
    status = STATUS_PATH.read_text(encoding="utf-8")
    assert_value_free(receipt)

    require(
        receipt.get("schemaVersion") == "dreamjourney.credential-rotation-receipt.v1",
        "unexpected receipt schema",
    )
    require(receipt.get("workItemId") == "WI-S0-03-07", "receipt must bind WI-S0-03-07")
    require(receipt.get("authorityLock") == "CREDENTIAL_CONTROL", "authority lock is missing")
    require(str(receipt.get("executionOwner") or "").startswith("codex-goal:"), "execution owner is missing")

    families = {item.get("credentialFamily"): item for item in receipt.get("credentialFamilies", [])}
    require(ROTATION_FAMILIES <= set(families), "rotation receipt is missing a credential family")
    containment = {item.get("path"): item for item in receipt.get("internalContainment", [])}
    require(REQUIRED_CONTAINMENT <= set(containment), "internal containment evidence is incomplete")
    require(
        containment["digitalHumanLeaseDrain"].get("status") == "AUTOMATED_AND_DEPLOYED",
        "digital-human lease drain is not deployed",
    )
    require(
        containment["currentSourceCredentialLiterals"].get("status") == "RETIRED_AND_DEPLOYED",
        "current source credential literals are not retired",
    )
    inventory = receipt.get("inventoryEvidence") or {}
    require(inventory.get("sourceBlockingObservationCount") == 0, "current source must have zero blockers")
    require(inventory.get("historyBlockingObservationCount", 0) > 0, "history blocker evidence is missing")
    require(inventory.get("containerBlockingObservationCount", 0) > 0, "private/container blocker evidence is missing")
    require(
        inventory.get("blockingObservationCount")
        == inventory.get("historyBlockingObservationCount") + inventory.get("containerBlockingObservationCount"),
        "blocking observation totals do not reconcile",
    )
    drain = receipt.get("drainReceipt") or {}
    require(drain.get("elapsedActiveBefore") == 1, "drain receipt must retain the observed before count")
    require(drain.get("elapsedActiveAfter") == 0, "drain receipt must prove no elapsed active lease remains")

    receipt_status = receipt.get("status")
    if receipt_status == "EXTERNAL_OWNER_ACTION_REQUIRED":
        require((receipt.get("gateEvidence") or {}).get("G0") == "MISSING", "pending receipt cannot claim G0")
        require(receipt.get("releaseDecision") == "STOP", "pending receipt must keep release stopped")
        for family in ROTATION_FAMILIES:
            item = families[family]
            require(item.get("rotationStatus") == "OWNER_ACTION_REQUIRED", f"{family} rotation must remain pending")
            require(item.get("revocationStatus") == "OWNER_ACTION_REQUIRED", f"{family} revoke must remain pending")
            require(item.get("providerEvidenceIds") == [], f"{family} must not invent Provider evidence")
        require("状态：`EXTERNAL_BLOCKED`" in status, "status document must retain the external blocker")
        require("`G0=MISSING`" in status, "status document must not claim G0")
    elif receipt_status == "CLOSED_WITH_RISK_EXCEPTION":
        require(
            (receipt.get("gateEvidence") or {}).get("G0") == "PRESENT",
            "risk-accepted receipt requires G0 continuation evidence",
        )
        require(
            receipt.get("releaseDecision") == "CONTINUE_WITH_RISK_EXCEPTION",
            "risk-accepted receipt requires an explicit exception decision",
        )
        exception = receipt.get("riskAcceptance") or {}
        require(str(exception.get("decisionId") or "").startswith("RA-WI-S0-03-07-"), "risk decision ID is missing")
        require(exception.get("decidedBy") == "PRODUCT_OWNER", "risk acceptance must come from the product owner")
        require(bool(exception.get("decidedAt")), "risk acceptance timestamp is missing")
        require(exception.get("residualRisk") == "ACKNOWLEDGED", "residual risk must remain acknowledged")
        required_scopes = {
            "PROVIDER_ROTATION_DEFERRED",
            "OLD_CREDENTIAL_REVOCATION_DEFERRED",
            "HISTORY_AND_PRIVATE_BACKUP_RETENTION_ACCEPTED",
        }
        require(required_scopes <= set(exception.get("scope") or []), "risk acceptance scope is incomplete")
        require(
            exception.get("doesNotClaimProviderVerification") is True,
            "risk acceptance must not claim Provider verification",
        )
        for family in ROTATION_FAMILIES:
            item = families[family]
            require(
                item.get("rotationStatus") == "RISK_ACCEPTED_NOT_ROTATED",
                f"{family} must truthfully remain not rotated",
            )
            require(
                item.get("revocationStatus") == "RISK_ACCEPTED_NOT_REVOKED",
                f"{family} must truthfully remain not revoked",
            )
            require(item.get("providerEvidenceIds") == [], f"{family} must not invent Provider evidence")
            require(
                item.get("riskExceptionId") == exception.get("decisionId"),
                f"{family} must bind the accepted risk decision",
            )
        require("状态：`CLOSED_WITH_RISK_EXCEPTION`" in status, "status document must record the risk exception")
        require("`G0=PRESENT_BY_RISK_EXCEPTION`" in status, "status document must identify the exception basis")
        require("不得作为 Provider 安全验收证据" in status, "status must preserve the verification boundary")
    elif receipt_status == "VERIFIED":
        require((receipt.get("gateEvidence") or {}).get("G0") == "PRESENT", "verified receipt requires G0")
        require(receipt.get("releaseDecision") == "GO", "verified receipt requires a GO decision")
        for family in ROTATION_FAMILIES:
            item = families[family]
            require(item.get("rotationStatus") == "ROTATED", f"{family} is not rotated")
            require(item.get("revocationStatus") == "REVOKED", f"{family} old version is not revoked")
            require(bool(item.get("providerEvidenceIds")), f"{family} requires Provider evidence")
    else:
        raise AssertionError("receipt status must be pending, risk-accepted, or verified")

    print("Product V4 credential rotation receipt check passed: value-free state is truthful")


if __name__ == "__main__":
    main()
