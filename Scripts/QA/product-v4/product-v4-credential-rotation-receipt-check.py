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
    elif receipt_status == "VERIFIED":
        require((receipt.get("gateEvidence") or {}).get("G0") == "PRESENT", "verified receipt requires G0")
        require(receipt.get("releaseDecision") == "GO", "verified receipt requires a GO decision")
        for family in ROTATION_FAMILIES:
            item = families[family]
            require(item.get("rotationStatus") == "ROTATED", f"{family} is not rotated")
            require(item.get("revocationStatus") == "REVOKED", f"{family} old version is not revoked")
            require(bool(item.get("providerEvidenceIds")), f"{family} requires Provider evidence")
    else:
        raise AssertionError("receipt status must be pending or verified")

    print("Product V4 credential rotation receipt check passed: value-free state is truthful")


if __name__ == "__main__":
    main()
