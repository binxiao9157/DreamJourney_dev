#!/usr/bin/env python3

from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Optional


ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = ROOT / "DreamJourney/Sources/App/DigitalHumanContextStore.swift"


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


def compact(value: str) -> str:
    return "".join(value.split())


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    normalized = compact(source)
    for snippet in snippets:
        require(compact(snippet) in normalized, f"{label} missing: {snippet}")


def run_static_check() -> None:
    require(SOURCE_PATH.is_file(), "DigitalHumanContextStore.swift is missing")
    source = SOURCE_PATH.read_text()

    envelope = declaration_body(source, "private struct DigitalHumanContextStorageEnvelope")
    require_all(
        envelope,
        (
            "let subjectId: String",
            "let accountGeneration: UInt64",
            "let accountGenerationId: UUID",
            "subjectId == accountLease.subjectId",
            "accountGeneration == accountLease.generation",
            "accountGenerationId == accountLease.generationId",
        ),
        "generation-scoped envelope",
    )
    require("sessionId" not in envelope, "storage envelope must not bind session credentials")

    store = declaration_body(source, "final class DigitalHumanContextStore")
    require_all(
        store,
        (
            'private let legacyKeyBase = "dj.digitalHuman.currentContext"',
            'private let scopedKeyBase = "dj.digitalHuman.currentContext.v2"',
            "accountLeaseRuntime.capture(forSubjectId: userId)",
            "accountLeaseRuntime.capture(forSubjectId: sourceUserId)",
            "quarantineLegacySubjectPayloadIfNeeded(accountLease: accountLease)",
            "DigitalHumanContextLegacyQuarantineRecord",
            'reason: "missingAccountGeneration"',
            "restore(previousData, forKey: storageKey)",
            "accountLeaseRuntime.validate(accountLease, at: .request)",
            "accountLeaseRuntime.validate(accountLease, at: .commit)",
            "accountLeaseRuntime.validate(accountLease, at: .runtime)",
            "accountLeaseRuntime.validate(accountLease, at: .ui)",
        ),
        "DigitalHumanContextStore owner scope",
    )
    require(
        '.defaultContext(userId: "")' not in store,
        "store must not synthesize an anonymous/default principal",
    )
    require(
        "capture(forSubjectId: nil)" not in store,
        "compatibility APIs must capture an explicit authenticated subject",
    )
    require(
        "JSONDecoder().decode(DigitalHumanContext.self" not in store,
        "legacy subject-only payload must not be decoded and claimed as current state",
    )

    scoped_key = declaration_body(store, "private func scopedKey")
    require_all(
        scoped_key,
        (
            "accountLease.subjectId",
            "accountLease.generation",
            "accountLease.generationId",
        ),
        "generation-scoped storage key",
    )
    require("sessionId" not in scoped_key, "same-generation session refresh must keep the same key")

    quarantine = declaration_body(store, "private func quarantineLegacySubjectPayloadIfNeeded")
    require_all(
        quarantine,
        (
            "legacyKey(for: accountLease.subjectId)",
            "legacyQuarantineKey(for: accountLease.subjectId)",
            "defaults.set(quarantineData, forKey: quarantineStorageKey)",
            "defaults.removeObject(forKey: sourceStorageKey)",
        ),
        "legacy quarantine",
    )

    apply_current = declaration_body(store, "private func applyCurrent")
    restore_index = apply_current.find("restore(previousData, forKey: storageKey)")
    notification_index = apply_current.find("NotificationCenter.default.post")
    require(restore_index >= 0, "stale commit rollback is missing")
    require(notification_index > restore_index, "notifications must only follow a successful commit")


@dataclass(frozen=True)
class Lease:
    subject: str
    generation: int
    generation_id: str
    session_id: str


@dataclass(frozen=True)
class Envelope:
    subject: str
    generation: int
    generation_id: str
    value: str


class Runtime:
    def __init__(self) -> None:
        self.active: Optional[Lease] = None

    def validate(self, lease: Lease) -> bool:
        active = self.active
        return bool(
            active
            and active.subject == lease.subject
            and active.generation == lease.generation
            and active.generation_id == lease.generation_id
        )


class ScopedStoreModel:
    def __init__(self, runtime: Runtime) -> None:
        self.runtime = runtime
        self.scoped: dict[str, Envelope] = {}
        self.legacy: dict[str, str] = {}
        self.quarantine: dict[str, str] = {}
        self.notification_count = 0

    @staticmethod
    def key(lease: Lease) -> str:
        return f"{lease.subject}|{lease.generation}|{lease.generation_id}"

    def quarantine_legacy(self, lease: Lease) -> bool:
        if lease.subject not in self.legacy:
            return True
        payload = self.legacy[lease.subject]
        existing = self.quarantine.get(lease.subject)
        if existing is not None and existing != payload:
            return False
        self.quarantine[lease.subject] = payload
        del self.legacy[lease.subject]
        return True

    def read(self, lease: Lease) -> Optional[str]:
        if not self.runtime.validate(lease) or not self.quarantine_legacy(lease):
            return None
        envelope = self.scoped.get(self.key(lease))
        if envelope is None:
            return None
        if (
            envelope.subject != lease.subject
            or envelope.generation != lease.generation
            or envelope.generation_id != lease.generation_id
            or not self.runtime.validate(lease)
        ):
            return None
        return envelope.value

    def write(
        self,
        lease: Lease,
        value: str,
        before_commit: Optional[Callable[[], None]] = None,
    ) -> bool:
        if not self.runtime.validate(lease) or not self.quarantine_legacy(lease):
            return False
        key = self.key(lease)
        previous = self.scoped.get(key)
        self.scoped[key] = Envelope(
            subject=lease.subject,
            generation=lease.generation,
            generation_id=lease.generation_id,
            value=value,
        )
        if before_commit:
            before_commit()
        if not self.runtime.validate(lease):
            if previous is None:
                del self.scoped[key]
            else:
                self.scoped[key] = previous
            return False
        self.notification_count += 1
        return True


def run_model_smoke() -> None:
    runtime = Runtime()
    store = ScopedStoreModel(runtime)

    account_a_generation_1 = Lease("account-a", 1, "a-generation-1", "session-1")
    runtime.active = account_a_generation_1
    require(store.write(account_a_generation_1, "family-a"), "generation 1 write failed")

    refreshed_session = Lease("account-a", 1, "a-generation-1", "session-2")
    runtime.active = refreshed_session
    require(
        store.read(refreshed_session) == "family-a",
        "same-generation session refresh lost digital-human context",
    )

    account_b = Lease("account-b", 1, "b-generation-1", "session-b")
    runtime.active = account_b
    require(store.read(account_b) is None, "account B read account A context")

    account_a_generation_2 = Lease("account-a", 2, "a-generation-2", "session-3")
    runtime.active = account_a_generation_2
    require(
        store.read(account_a_generation_2) is None,
        "new generation for the same subject read the prior generation",
    )
    require(store.write(account_a_generation_2, "self"), "generation 2 baseline write failed")
    successful_notifications = store.notification_count

    account_a_generation_3 = Lease("account-a", 3, "a-generation-3", "session-4")
    require(
        not store.write(
            account_a_generation_2,
            "stale-family",
            before_commit=lambda: setattr(runtime, "active", account_a_generation_3),
        ),
        "stale asynchronous completion committed",
    )
    runtime.active = account_a_generation_2
    require(store.read(account_a_generation_2) == "self", "stale write did not roll back")
    require(
        store.notification_count == successful_notifications,
        "stale completion emitted a change notification",
    )

    legacy_generation = Lease("legacy-account", 7, "legacy-generation-7", "legacy-session")
    runtime.active = legacy_generation
    store.legacy[legacy_generation.subject] = "unscoped-family-context"
    require(store.read(legacy_generation) is None, "legacy payload was auto-claimed")
    require(legacy_generation.subject not in store.legacy, "legacy payload was not unmounted")
    require(
        store.quarantine.get(legacy_generation.subject) == "unscoped-family-context",
        "legacy payload was not preserved in quarantine",
    )

    runtime.active = None
    require(store.read(refreshed_session) is None, "signed-out read did not fail closed")


def main() -> None:
    run_static_check()
    run_model_smoke()
    print("Digital-human context owner-scope static/model smoke passed")


if __name__ == "__main__":
    main()
