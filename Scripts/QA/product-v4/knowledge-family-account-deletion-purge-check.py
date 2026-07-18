#!/usr/bin/env python3

from dataclasses import dataclass
from pathlib import Path
import tempfile
from typing import Optional


ROOT = Path(__file__).resolve().parents[3]
KBLITE = ROOT / "DreamJourney/Sources/Services/KBLiteManager.swift"
KNOWLEDGE_SYNC = ROOT / "DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift"
CONVERSATION = ROOT / "DreamJourney/Sources/Services/ConversationMemoryManager.swift"
FAMILY = ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function signature: {signature}")
    brace = source.find("{", start)
    require(brace >= 0, f"missing function body: {signature}")
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace : index + 1]
    raise SystemExit(f"FAIL: unterminated function body: {signature}")


def require_snippets(source: str, snippets: list[str], label: str) -> None:
    for snippet in snippets:
        require(snippet in source, f"{label} missing contract: {snippet}")


def check_static_contract() -> None:
    kblite = KBLITE.read_text(encoding="utf-8")
    kblite_teardown = function_body(kblite, "func teardownForAccountLifecycle(")
    kblite_purge = function_body(kblite, "func purgeLocalDataForAccountDeletion(")
    require_snippets(
        kblite,
        [
            "private var mountedAccountLease: AccountLease?",
            "func purgeLocalDataForAccountDeletion(",
            "removePersistedGraphArtifacts(forOwnerUserId:",
            "Self.isSameAccountLeaseGeneration",
            "hasConflictingCurrentLease",
            'detailCode: "knowledgeDeletionPurged"',
            'detailCode: "knowledgeDeletionPurgeFailed"',
        ],
        "KBLite account deletion",
    )
    require(
        "purgeLocalDataForAccountDeletion(accountLease: oldAccountLease)" in kblite_teardown,
        "KBLite teardown must invoke the old-lease purge",
    )
    require(
        "accountLeaseRuntime.validate" not in kblite_purge,
        "KBLite deletion must not validate a lease after the transition fence",
    )
    require(
        "graphFilePath(for:" not in kblite_purge,
        "KBLite deletion must not use the legacy path helper with migration side effects",
    )

    sync = KNOWLEDGE_SYNC.read_text(encoding="utf-8")
    sync_teardown = function_body(sync, "func teardownForAccountLifecycle(")
    require_snippets(
        sync_teardown,
        [
            "try self.baseStore.remove(for: oldOwner)",
            "try self.pendingStore.remove(for: oldOwner)",
            "try self.governanceOutboxStore.removeAll(for: oldOwner)",
            'detailCode: "knowledgeSyncDeletionPurged"',
        ],
        "KnowledgeSync account deletion",
    )

    conversation = CONVERSATION.read_text(encoding="utf-8")
    conversation_teardown = function_body(conversation, "func teardownForAccountLifecycle(")
    conversation_purge = function_body(conversation, "func purgeLocalDataForAccountDeletion(")
    require_snippets(
        conversation_teardown,
        [
            "purgeLocalDataForAccountDeletion(accountLease: oldAccountLease)",
            'detailCode: "conversationDeletionPurged"',
        ],
        "Conversation account deletion",
    )
    require(
        "accountLeaseRuntime.validate" in conversation_purge
        and "loadedStorageLease" in conversation_purge,
        "Conversation deletion must accept its pre-fence mounted lease path",
    )

    family = FAMILY.read_text(encoding="utf-8")
    family_teardown = function_body(family, "func teardownForAccountLifecycle(")
    family_purge = function_body(family, "func purgeLocalDataForAccountDeletion(")
    require_snippets(
        family,
        [
            "private var activeAccountLease: AccountLease?",
            "func purgeLocalDataForAccountDeletion(",
            "UserDefaults.standard.removeObject(forKey: modeKey)",
            "UserDefaults.standard.removeObject(forKey: voiceKey)",
            "Self.isSameAccountLeaseGeneration",
            "hasConflictingCurrentLease",
            'detailCode: "familyDeletionLocalProjectionPurgedRemoteRightsPending"',
            'detailCode: "familyDeletionPurgeFailed"',
        ],
        "Family account deletion",
    )
    require(
        "purgeLocalDataForAccountDeletion(accountLease: oldAccountLease)" in family_teardown,
        "Family teardown must invoke the old-lease purge",
    )
    require(
        "accountLeaseRuntime.validate" not in family_purge,
        "Family deletion must not validate a lease after the transition fence",
    )
    forbidden_remote_calls = ["DreamJourneyBackendClient", "deleteFamily", "removeFamily"]
    for forbidden in forbidden_remote_calls:
        require(
            forbidden not in family_purge,
            f"Family local purge must not mutate backend relationship authority: {forbidden}",
        )


@dataclass(frozen=True)
class Lease:
    subject: str
    vault: str
    generation: int
    generation_id: str
    authority_epoch: str


def same_generation(lhs: Lease, rhs: Lease) -> bool:
    return (
        lhs.subject == rhs.subject
        and lhs.vault == rhs.vault
        and lhs.generation == rhs.generation
        and lhs.generation_id == rhs.generation_id
        and lhs.authority_epoch == rhs.authority_epoch
    )


def model_kblite_purge(root: Path, old: Lease, current: Optional[Lease]) -> bool:
    if current is not None and not same_generation(current, old):
        return False
    file_name = f"kb_graph_{old.subject}.json"
    if Path(file_name).name != file_name or file_name in {".", ".."}:
        return False
    for candidate in list(root.iterdir()):
        name = candidate.name
        is_primary = name == file_name
        is_corrupt = name.startswith(f"{file_name}.corrupted")
        is_staging = name.startswith(f".{file_name}.") and name.endswith(".staging")
        if is_primary or is_corrupt or is_staging:
            candidate.unlink()
    return True


def model_family_purge(defaults: dict[str, object], old: Lease, current: Optional[Lease]) -> bool:
    if current is not None and not same_generation(current, old):
        return False
    defaults.pop(f"dj.family.digitalHumanModeOverrides.{old.subject}", None)
    defaults.pop(f"dj.family.voiceProfileOverrides.{old.subject}", None)
    return True


def check_model_contract() -> None:
    old = Lease("owner-a", "vault-a", 7, "generation-a", "epoch-a")
    newer = Lease("owner-a", "vault-a", 8, "generation-b", "epoch-a")
    other = Lease("owner-b", "vault-b", 3, "generation-c", "epoch-a")

    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        old_primary = root / "kb_graph_owner-a.json"
        old_corrupt = root / "kb_graph_owner-a.json.corrupted"
        old_staging = root / ".kb_graph_owner-a.json.operation.staging"
        other_primary = root / "kb_graph_owner-b.json"
        unrelated = root / "kb_graph_legacy_quarantine.json"
        for path in [old_primary, old_corrupt, old_staging, other_primary, unrelated]:
            path.write_text(path.name, encoding="utf-8")

        require(model_kblite_purge(root, old, current=None), "old fenced lease should purge")
        require(not old_primary.exists(), "old graph must be removed")
        require(not old_corrupt.exists(), "old corrupt backup must be removed")
        require(not old_staging.exists(), "old staging artifact must be removed")
        require(other_primary.exists(), "another owner's graph must remain")
        require(unrelated.exists(), "unowned quarantine evidence must remain")

        old_primary.write_text("old", encoding="utf-8")
        require(
            not model_kblite_purge(root, old, current=newer),
            "old lease must not purge a newer generation",
        )
        require(old_primary.exists(), "generation conflict must preserve old-subject path")
        require(
            not model_kblite_purge(root, Lease("../escape", "v", 1, "g", "e"), current=None),
            "unsafe subject path must be rejected",
        )

    defaults: dict[str, object] = {
        "dj.family.digitalHumanModeOverrides.owner-a": {"member-a": "star"},
        "dj.family.voiceProfileOverrides.owner-a": b"voice-a",
        "dj.family.digitalHumanModeOverrides.owner-b": {"member-b": "sunshine"},
        "dj.family.voiceProfileOverrides.owner-b": b"voice-b",
        "dj.device.apns.token": "device-level",
    }
    require(model_family_purge(defaults, old, current=None), "family local purge should succeed")
    require(
        "dj.family.digitalHumanModeOverrides.owner-a" not in defaults
        and "dj.family.voiceProfileOverrides.owner-a" not in defaults,
        "old family overrides must be removed",
    )
    require(
        "dj.family.digitalHumanModeOverrides.owner-b" in defaults
        and "dj.family.voiceProfileOverrides.owner-b" in defaults,
        "another owner's family overrides must remain",
    )
    require(defaults["dj.device.apns.token"] == "device-level", "device state must remain")

    blocked_defaults = {
        "dj.family.digitalHumanModeOverrides.owner-a": {"member-a": "star"},
        "dj.family.voiceProfileOverrides.owner-a": b"voice-a",
    }
    require(
        not model_family_purge(blocked_defaults, old, current=newer),
        "family old lease must not clear a newer generation",
    )
    require(len(blocked_defaults) == 2, "generation conflict must not mutate family defaults")
    require(not same_generation(old, other), "different owner leases must never compare equal")


def main() -> None:
    check_static_contract()
    check_model_contract()
    print(
        "PASS: WI-S0-01-08C account deletion local purge "
        "modules=4 staleGenerationIsolation=ok crossOwnerIsolation=ok remoteFamilyMutation=none"
    )


if __name__ == "__main__":
    main()
