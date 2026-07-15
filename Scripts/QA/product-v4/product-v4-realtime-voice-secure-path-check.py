#!/usr/bin/env python3
"""Guard WI-S0-03-04's deny-by-default realtime voice decision."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
    dialog = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
    status = read("docs/superpowers/status/2026-07-16-wi-s0-03-04-realtime-voice-secure-path.md")

    for field in (
        "accessPath",
        "mobileDirectAllowed",
        "brokerStatus",
        "decisionReasonCode",
        "requiredCredentialProperties",
        "verifiedCredentialProperties",
        "missingCredentialProperties",
    ):
        require(field in client, f"Realtime voice client contract is missing {field}")

    require(
        "!mobileDirectAllowed" in client,
        "Unknown or denied contracts must block the direct mobile route",
    )
    require(
        'accessPath != "scopedSessionCredential"' in client,
        "Only an explicit scoped-session path may reach the direct Provider route",
    )
    require(
        "runtimeConfig.mobileDirectAllowed" in dialog,
        "DialogEngine must enforce the server decision before initialization",
    )
    require(
        "runtimeConfig.decisionReasonCode" in dialog,
        "DialogEngine diagnostics must retain the value-free denial reason",
    )
    require(
        "expiresAt" not in client[client.index("struct RealtimeVoiceRuntimeConfig"):client.index("struct ArchiveMediaUploadIntent")],
        "Blocked realtime voice config must not parse invented expiry metadata",
    )
    for term in (
        "EXTERNAL_BLOCKED",
        "KEEP_DIRECT_MOBILE_CLOSED",
        "G3=MISSING",
        "G4=MISSING",
        "scope",
        "TTL",
        "audience",
        "revocation",
        "mobileDirectAllowed=false",
        "backendProxyOrText",
    ):
        require(term in status, f"WI-S0-03-04 status receipt is missing {term}")

    print("Product V4 realtime voice secure-path check passed: direct mobile remains deny-by-default")


if __name__ == "__main__":
    main()
