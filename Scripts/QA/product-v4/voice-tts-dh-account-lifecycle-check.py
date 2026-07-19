#!/usr/bin/env python3
"""Static/model gate for WI-S0-01-08B Voice/TTS/DigitalHuman teardown."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[3]
VOICE_SOURCE = ROOT / "DreamJourney/Sources/Memoir/VoiceCloneService.swift"
TTS_SOURCE = ROOT / "DreamJourney/Sources/Memoir/MemoirTTSService.swift"
DH_SOURCE = ROOT / "DreamJourney/Sources/App/DigitalHumanContextStore.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def declaration_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing declaration: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing declaration body: {marker}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated declaration: {marker}")


def function_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing function: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {marker}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated function: {marker}")


def compact(value: str) -> str:
    return "".join(value.split())


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    normalized = compact(source)
    for snippet in snippets:
        require(compact(snippet) in normalized, f"{label} missing: {snippet}")


def require_handler_contract(handler: str, label: str) -> None:
    require_all(
        handler,
        (
            "context.oldAccountLease",
            "oldAccountLease.generation == context.oldGeneration",
            "context.event == .accountDeletion",
            "requestedOutcome == .cleared",
            "requestedOutcome == .purged",
            ".failed",
            "remainingLocalData: true",
        ),
        label,
    )
    forbidden = (
        "accountLeaseRuntime.validate",
        "DreamJourneyBackendClient",
        "NotificationCenter",
        "requestVoiceCloneSynthesis",
        "saveVoiceCloneProfile",
        "refreshVoiceCloneProfile",
    )
    for snippet in forbidden:
        require(snippet not in handler, f"{label} must not use current runtime/provider: {snippet}")


def require_fixed_detail_codes(source: str, marker: str, label: str) -> None:
    body = function_body(source, marker)
    require("switch outcome" in body, f"{label} must map fixed codes by outcome")
    for outcome in (
        ".retainedLocked",
        ".unmounted",
        ".cancelled",
        ".cleared",
        ".purged",
        ".skipped",
        ".failed",
    ):
        require(outcome in body, f"{label} missing outcome mapping: {outcome}")
    require("\\(" not in body, f"{label} must not interpolate owner/provider values")


def run_voice_static_check(source: str) -> None:
    service = declaration_body(source, "final class VoiceCloneService")
    require_all(
        service,
        (
            "func handleAccountLifecycle(",
            "_ context: AccountLifecycleContext",
            "requestedOutcome: AccountLifecycleModuleOutcome",
            ") -> AccountLifecycleModuleResult",
        ),
        "VoiceCloneService lifecycle signature",
    )
    handler = function_body(service, "func handleAccountLifecycle(")
    require_handler_contract(handler, "VoiceCloneService lifecycle handler")
    require_all(
        handler,
        (
            "cancelTrainingRuntime(for: oldAccountLease)",
            "localStateStore.handleAccountLifecycle(",
            "accountLease: oldAccountLease",
        ),
        "VoiceCloneService lifecycle handler",
    )

    store = declaration_body(source, "private final class VoiceCloneLocalStateStore")
    store_handler = function_body(store, "func handleAccountLifecycle(")
    require_all(
        store_handler,
        (
            "VoiceCloneLocalOwnerScope(accountLease: accountLease)",
            "defaults.data(forKey: scope.storageKey)",
            "decode(VoiceCloneLocalStateEnvelope.self",
            "envelope.matches(scope)",
            "defaults.removeObject(forKey: scope.storageKey)",
        ),
        "voice exact-scope teardown",
    )
    require(
        "accountLeaseRuntime.validate" not in store_handler,
        "voice teardown must accept the captured stale lease",
    )
    require(
        "legacyQuarantineKey" not in store_handler and "LegacyKey" not in store_handler,
        "voice teardown must not claim/delete unverified legacy state",
    )

    cancel = function_body(service, "private func cancelTrainingRuntime(")
    require_all(
        cancel,
        (
            "VoiceCloneLocalOwnerScope(accountLease: oldAccountLease)",
            "let operation = trainingRuntimeOperation",
            "VoiceCloneLocalOwnerScope(accountLease: operation.accountLease) == oldScope",
            "invalidateTrainingRuntime(expected: operation)",
        ),
        "voice runtime cancellation",
    )
    require_fixed_detail_codes(service, "private func voiceLifecycleDetailCode(", "voice detailCode")


def run_tts_static_check(source: str) -> None:
    service = declaration_body(source, "final class MemoirTTSService")
    require_all(
        service,
        (
            "func handleAccountLifecycle(",
            "_ context: AccountLifecycleContext",
            "requestedOutcome: AccountLifecycleModuleOutcome",
            ") -> AccountLifecycleModuleResult",
        ),
        "MemoirTTSService lifecycle signature",
    )
    handler = function_body(service, "func handleAccountLifecycle(")
    require_handler_contract(handler, "MemoirTTSService lifecycle handler")
    require_all(
        handler,
        (
            "MemoirTTSCacheScope(accountLease: oldAccountLease)",
            "cancelSynthesisRuntime(for: oldScope)",
            "handleScopedCacheLifecycle(scope: oldScope, purge: purge)",
        ),
        "MemoirTTSService lifecycle handler",
    )

    cancel = function_body(service, "private func cancelSynthesisRuntime(")
    require_all(
        cancel,
        (
            "MemoirTTSCacheScope(accountLease: activeSynthesisOperation.accountLease) == oldScope",
            "self.activeSynthesisOperation = nil",
        ),
        "TTS synthesis cancellation",
    )

    teardown = function_body(service, "private func handleScopedCacheLifecycle(")
    require_all(
        teardown,
        (
            "audioDirectory(for: scope)",
            "cacheDirectory(for: scope)",
            "isExpectedLifecycleDirectory(",
            "root: scopedAudioRootDirectory",
            "root: scopedCacheRootDirectory",
            "storageLock.lock()",
            "FileManager.default.removeItem(at: scopedAudioDirectory)",
            "FileManager.default.removeItem(at: scopedMetadataDirectory)",
        ),
        "TTS exact-scope teardown",
    )
    for forbidden in (
        "accountLeaseRuntime.validate",
        "legacyAudioDirectory",
        "legacyCacheDirectory",
        "legacyQuarantineDirectory",
        "ensureScopeDirectories",
        "draft",
        "recording",
    ):
        require(forbidden not in teardown, f"TTS teardown crossed storage boundary: {forbidden}")
    require_fixed_detail_codes(service, "private func memoirTTSLifecycleDetailCode(", "TTS detailCode")


def run_digital_human_static_check(source: str) -> None:
    store = declaration_body(source, "final class DigitalHumanContextStore")
    require_all(
        store,
        (
            "func handleAccountLifecycle(",
            "_ context: AccountLifecycleContext",
            "requestedOutcome: AccountLifecycleModuleOutcome",
            ") -> AccountLifecycleModuleResult",
        ),
        "DigitalHumanContextStore lifecycle signature",
    )
    handler = function_body(store, "func handleAccountLifecycle(")
    require_handler_contract(handler, "DigitalHumanContextStore lifecycle handler")
    require_all(
        handler,
        (
            "handleScopedContextLifecycle(",
            "accountLease: oldAccountLease",
        ),
        "DigitalHumanContextStore lifecycle handler",
    )

    teardown = function_body(store, "private func handleScopedContextLifecycle(")
    require_all(
        teardown,
        (
            "scopedKey(for: accountLease)",
            "defaults.data(forKey: storageKey)",
            "decode(DigitalHumanContextStorageEnvelope.self",
            "envelope.matches(accountLease)",
            "defaults.removeObject(forKey: storageKey)",
        ),
        "digital-human exact-scope teardown",
    )
    for forbidden in (
        "accountLeaseRuntime.validate",
        "UserManager.shared.currentUser",
        "legacyKey(",
        "legacyQuarantineKey(",
        "NotificationCenter",
    ):
        require(forbidden not in teardown, f"digital-human teardown crossed boundary: {forbidden}")
    require_fixed_detail_codes(
        store,
        "private func digitalHumanContextLifecycleDetailCode(",
        "digital-human detailCode",
    )


@dataclass(frozen=True)
class Lease:
    subject: str
    vault: str
    generation: int
    generation_id: str
    session: str


def scope(lease: Lease) -> tuple[str, str, int, str]:
    return (lease.subject, lease.vault, lease.generation, lease.generation_id)


@dataclass
class TeardownResult:
    outcome: str
    remaining_local_data: bool
    active_scope: Optional[tuple[str, str, int, str]]


class ScopedLifecycleModel:
    def __init__(self) -> None:
        self.envelopes: dict[tuple[str, str, int, str], tuple[str, str, int, str]] = {}
        self.active_scope: Optional[tuple[str, str, int, str]] = None
        self.explicit_memoir_drafts = {"memoir-draft-a", "recording-a"}

    def teardown(
        self,
        old_lease: Optional[Lease],
        event: str,
        requested_outcome: str,
        removal_succeeds: bool = True,
    ) -> TeardownResult:
        if old_lease is None:
            return TeardownResult("failed", True, self.active_scope)
        old_scope = scope(old_lease)
        if self.active_scope == old_scope:
            self.active_scope = None
        purge = event == "accountDeletion" or requested_outcome in {"cleared", "purged"}
        envelope_scope = self.envelopes.get(old_scope)
        if envelope_scope is not None and envelope_scope != old_scope:
            return TeardownResult("failed", True, self.active_scope)
        if not purge:
            return TeardownResult(requested_outcome, envelope_scope is not None, self.active_scope)
        if envelope_scope is not None and not removal_succeeds:
            return TeardownResult("failed", True, self.active_scope)
        self.envelopes.pop(old_scope, None)
        return TeardownResult(requested_outcome, False, self.active_scope)


def run_lifecycle_model() -> None:
    old = Lease("owner-a", "vault-a", 7, "generation-a", "session-old")
    refreshed = Lease("owner-a", "vault-a", 7, "generation-a", "session-refreshed")
    new_generation = Lease("owner-a", "vault-a", 8, "generation-b", "session-new")
    other = Lease("owner-b", "vault-b", 1, "generation-c", "session-other")
    require(scope(old) == scope(refreshed), "session refresh must retain deterministic scope")
    require(scope(old) != scope(new_generation), "new generation must have a different scope")
    require(scope(old) != scope(other), "another owner must have a different scope")

    model = ScopedLifecycleModel()
    model.envelopes[scope(old)] = scope(old)
    model.envelopes[scope(new_generation)] = scope(new_generation)
    model.active_scope = scope(new_generation)
    result = model.teardown(old, "switchAccount", "cleared")
    require(result.outcome == "cleared" and not result.remaining_local_data,
            "captured stale lease must clear its exact old scope")
    require(scope(old) not in model.envelopes, "old scope must be removed")
    require(scope(new_generation) in model.envelopes, "new scope must remain untouched")
    require(result.active_scope == scope(new_generation), "old teardown must not cancel new runtime")
    require(model.explicit_memoir_drafts == {"memoir-draft-a", "recording-a"},
            "Voice/TTS teardown must not delete explicit memoir drafts or recordings")

    retained = ScopedLifecycleModel()
    retained.envelopes[scope(old)] = scope(old)
    retained.active_scope = scope(old)
    result = retained.teardown(old, "privateSuspension", "unmounted")
    require(result.outcome == "unmounted" and result.remaining_local_data,
            "unmount must retain locked cache when policy requests it")
    require(result.active_scope is None, "unmount must clear old in-memory runtime")

    malformed = ScopedLifecycleModel()
    malformed.envelopes[scope(old)] = scope(other)
    result = malformed.teardown(old, "logout", "cleared")
    require(result.outcome == "failed" and result.remaining_local_data,
            "mismatched envelope must fail closed without deletion")

    failed_delete = ScopedLifecycleModel()
    failed_delete.envelopes[scope(old)] = scope(old)
    result = failed_delete.teardown(old, "accountDeletion", "purged", removal_succeeds=False)
    require(result.outcome == "failed" and result.remaining_local_data,
            "failed account deletion must report remaining local data")


def main() -> None:
    voice = VOICE_SOURCE.read_text(encoding="utf-8")
    tts = TTS_SOURCE.read_text(encoding="utf-8")
    digital_human = DH_SOURCE.read_text(encoding="utf-8")
    run_voice_static_check(voice)
    run_tts_static_check(tts)
    run_digital_human_static_check(digital_human)
    run_lifecycle_model()
    print("PASS: Voice/TTS/DigitalHuman account lifecycle static/model gate")


if __name__ == "__main__":
    main()
