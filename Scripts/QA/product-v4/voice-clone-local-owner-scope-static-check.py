#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import re
import uuid
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = ROOT / "DreamJourney/Sources/Memoir/VoiceCloneService.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    for snippet in snippets:
        require(snippet in source, f"{label} missing: {snippet}")


@dataclass(frozen=True)
class LeaseModel:
    subject_id: str
    vault_id: str
    session_id: str
    generation: int
    generation_id: uuid.UUID


def storage_key(lease: LeaseModel) -> str:
    # session_id is deliberately not part of persistent ownership identity.
    values = (
        "subject",
        lease.subject_id,
        "vault",
        lease.vault_id,
        "generation",
        str(lease.generation),
        "generation-id",
        str(lease.generation_id).lower(),
    )
    canonical = "|".join(f"{len(value.encode('utf-8'))}:{value}" for value in values)
    return "dj.voiceclone.localState.scoped.v2." + hashlib.sha256(
        canonical.encode("utf-8")
    ).hexdigest()


def run_owner_scope_model() -> None:
    generation_a = uuid.UUID("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    generation_a_next = uuid.UUID("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    generation_b = uuid.UUID("cccccccc-cccc-4ccc-8ccc-cccccccccccc")

    lease_a = LeaseModel("user-a", "vault-a", "session-a1", 7, generation_a)
    lease_a_refresh = LeaseModel("user-a", "vault-a", "session-a2", 7, generation_a)
    lease_a_next = LeaseModel("user-a", "vault-a", "session-a3", 8, generation_a_next)
    lease_b = LeaseModel("user-b", "vault-b", "session-b1", 1, generation_b)

    require(
        storage_key(lease_a) == storage_key(lease_a_refresh),
        "same-generation session refresh must retain voice-clone local state",
    )
    require(
        storage_key(lease_a) != storage_key(lease_a_next),
        "new account generation for the same subject must not see prior state",
    )
    require(
        storage_key(lease_a) != storage_key(lease_b),
        "different account subjects must not share voice-clone state",
    )

    store = {storage_key(lease_a): {"speakerId": "speaker-a"}}
    require(store.get(storage_key(lease_a_refresh)) == {"speakerId": "speaker-a"},
            "same-generation refreshed session must read existing state")
    require(store.get(storage_key(lease_a_next)) is None,
            "new account generation must fail closed")
    require(store.get(storage_key(lease_b)) is None,
            "account B must fail closed on account A state")

    previous = dict(store)
    staged_key = storage_key(lease_a)
    store[staged_key] = {"speakerId": "stale-completion"}
    generation_still_valid = False
    if not generation_still_valid:
        store = previous
    require(store[staged_key] == {"speakerId": "speaker-a"},
            "stale async completion must roll back its staged write")


def main() -> None:
    source = SOURCE_PATH.read_text()

    require_all(
        source,
        (
            "private struct VoiceCloneLocalOwnerScope",
            "let generation: UInt64",
            "let generationId: UUID",
            "private struct VoiceClonePersistedState: Codable, Equatable",
            "var speakerId: String?",
            "var sampleStatus: VoiceCloneSampleStatus?",
            "var isEnabled: Bool?",
            "var realCloneProviderReady: Bool?",
            "var qualityAcceptanceRequired: Bool?",
            "var providerMode: String?",
            "var providerStatus: String?",
            "var providerMessage: String?",
            "private struct VoiceCloneLocalStateEnvelope: Codable, Equatable",
            "private final class VoiceCloneLocalStateStore",
            "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
            "accountLeaseRuntime.validate(accountLease, at: .runtime).allowed",
            "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
            "restore(",
            'ownerEvidence: "unverified"',
            "isolateLegacyPayloadIfNeeded()",
            "localStateStore.load(accountLease:",
            "localStateStore.update(accountLease:",
        ),
        "voice-clone scoped local state contract",
    )

    scope_match = re.search(
        r"private struct VoiceCloneLocalOwnerScope:[\s\S]*?\n}\n\n"
        r"private struct VoiceClonePersistedState",
        source,
    )
    require(scope_match is not None, "unable to inspect VoiceCloneLocalOwnerScope")
    scope_source = scope_match.group(0)
    require("sessionId" not in scope_source,
            "session credential must not participate in persistent state identity")
    require("generation-id" in scope_source,
            "generation identity must participate in persistent state identity")

    service_match = re.search(
        r"final class VoiceCloneService \{[\s\S]*?\n}\n\n// MARK: - 错误类型",
        source,
    )
    require(service_match is not None, "unable to inspect VoiceCloneService")
    service_source = service_match.group(0)
    require("UserDefaults.standard" not in service_source,
            "VoiceCloneService must not directly read or write global UserDefaults")
    require('?? "default"' not in service_source,
            "VoiceCloneService must not use a default/anonymous principal fallback")

    update_match = re.search(
        r"func update\([\s\S]*?\n    private func restore",
        source,
    )
    require(update_match is not None, "unable to inspect scoped state update")
    update_source = update_match.group(0)
    require(update_source.count("at: .commit") >= 2,
            "scoped write must validate AccountLease before and after staging")
    require("previousData" in update_source and "replacementData" in update_source,
            "scoped write must retain rollback material")

    legacy_keys = (
        "dj.voiceclone.speakerId",
        "dj.voiceclone.sampleStatus",
        "dj.voiceclone.isEnabled",
        "dj.voiceclone.realCloneProviderReady",
        "dj.voiceclone.qualityAcceptanceRequired",
        "dj.voiceclone.providerMode",
        "dj.voiceclone.providerStatus",
        "dj.voiceclone.providerMessage",
    )
    for key in legacy_keys:
        require(source.count(f'"{key}"') == 1,
                f"legacy key must only remain as quarantine input: {key}")

    run_owner_scope_model()
    print("Voice-clone local owner scope static/model smoke passed")


if __name__ == "__main__":
    main()
