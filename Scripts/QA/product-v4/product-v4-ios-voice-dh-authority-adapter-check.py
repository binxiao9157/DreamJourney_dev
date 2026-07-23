#!/usr/bin/env python3
"""Static/model gate for the default-deny iOS Voice/DH Authority adapter."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNTIME = ROOT / "DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntime.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def declaration_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing declaration: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing declaration body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : index + 1]
    raise AssertionError(f"unterminated declaration: {marker}")


@dataclass(frozen=True)
class Lease:
    subject_id: str
    vault_id: str


@dataclass(frozen=True)
class Envelope:
    subject_id: str
    vault_id: str
    authority_epoch: str
    status: str


def model_decision(envelope: Envelope | None, lease: Lease) -> str:
    if envelope is None:
        return "unavailable"
    if envelope.subject_id != lease.subject_id:
        return "subjectMismatch"
    if envelope.vault_id != lease.vault_id:
        return "vaultMismatch"
    if not envelope.authority_epoch or envelope.status != "blocked":
        return "defaultDenied"
    return "observedDefaultDeny"


def run_model_check() -> None:
    lease = Lease(subject_id="owner-a", vault_id="vault-a")
    valid = Envelope("owner-a", "vault-a", "3", "blocked")
    require(model_decision(None, lease) == "unavailable", "missing Authority must fail closed")
    require(
        model_decision(Envelope("other", "vault-a", "3", "blocked"), lease) == "subjectMismatch",
        "cross-subject Authority must fail closed",
    )
    require(
        model_decision(Envelope("owner-a", "vault-b", "3", "blocked"), lease) == "vaultMismatch",
        "cross-Vault Authority must fail closed",
    )
    require(
        model_decision(Envelope("owner-a", "vault-a", "", "blocked"), lease) == "defaultDenied",
        "empty epoch must not promote a runtime",
    )
    require(
        model_decision(valid, lease) == "observedDefaultDeny",
        "a matching blocked envelope remains non-promoting",
    )


def run_static_check() -> None:
    require(RUNTIME.is_file(), "DigitalHumanRuntime.swift is missing")
    require(CLIENT.is_file(), "DreamJourneyBackendClient.swift is missing")
    runtime = RUNTIME.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")

    envelope = declaration_body(runtime, "struct VoiceDigitalHumanAuthorityEnvelope")
    for required in (
        "let subjectId: String",
        "let vaultId: String",
        "let authorityEpoch: String",
        "let purpose: String",
        "let resourceKind: String",
        "let status: String",
        "let receiptIdHash: String",
    ):
        require(required in envelope, f"Authority envelope missing: {required}")
    for forbidden in (
        "credential",
        "assetKey",
        "audioBase64",
        "providerKey",
        "sessionId",
        "text",
    ):
        require(forbidden not in envelope, f"Authority envelope leaked forbidden value: {forbidden}")

    decision_state = declaration_body(runtime, "enum VoiceDigitalHumanAuthorityDecisionState")
    for required in (
        "case unavailable",
        "case subjectMismatch",
        "case vaultMismatch",
        "case observedDefaultDeny",
    ):
        require(required in decision_state, f"Authority decision state missing: {required}")

    decision = declaration_body(runtime, "struct VoiceDigitalHumanAuthorityDecision")
    for required in (
        "let providerEffectAllowed: Bool = false",
        "let runtimePromotionAllowed: Bool = false",
    ):
        require(required in decision, f"Authority decision missing: {required}")

    adapter = declaration_body(runtime, "enum VoiceDigitalHumanAuthorityAdapter")
    for required in (
        "accountLease.subjectId",
        "accountLease.vaultId",
    ):
        require(required in adapter, f"Authority adapter missing: {required}")

    for marker in (
        "struct DigitalHumanSessionContract",
        "struct VoiceCloneProfileContract",
        "struct VoiceCloneSynthesisResult",
    ):
        body = declaration_body(client, marker)
        require("let authority: VoiceDigitalHumanAuthorityEnvelope?" in body, f"{marker} lacks authority")
        require(
            "VoiceDigitalHumanAuthorityEnvelope(json: json[\"authority\"] as? [String: Any])" in body,
            f"{marker} must parse only the authority child object",
        )


def main() -> None:
    run_model_check()
    run_static_check()
    print("Product V4 iOS Voice/DH Authority adapter check passed")


if __name__ == "__main__":
    main()
