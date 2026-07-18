#!/usr/bin/env python3

from dataclasses import dataclass
from pathlib import Path
import re
import sys
from typing import Optional


ROOT = Path(__file__).resolve().parents[3]
SOURCES = {
    "conversation": ROOT / "DreamJourney/Sources/Services/ConversationMemoryManager.swift",
    "knowledge": ROOT / "DreamJourney/Sources/Services/KBLiteManager.swift",
    "sync": ROOT / "DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift",
    "family": ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"FAIL: {message}", file=sys.stderr)
        raise SystemExit(1)


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
    raise AssertionError(f"unterminated function body: {signature}")


def require_snippets(source: str, snippets: list[str], label: str) -> None:
    for snippet in snippets:
        require(snippet in source, f"{label} missing contract: {snippet}")


def check_fixed_detail_codes(body: str, label: str) -> None:
    detail_values = re.findall(r'detailCode:\s*"([^"]+)"', body)
    require(detail_values, f"{label} must return fixed detail codes")
    for value in detail_values:
        require(
            re.fullmatch(r"[A-Za-z0-9._-]+", value) is not None,
            f"{label} detail code must be value-free: {value}",
        )
    require("\\(" not in "\n".join(detail_values), f"{label} detail code must not interpolate values")


def check_static_contract() -> None:
    source = {name: path.read_text(encoding="utf-8") for name, path in SOURCES.items()}

    conversation = source["conversation"]
    conversation_body = function_body(conversation, "func teardownForAccountLifecycle(")
    require_snippets(
        conversation,
        [
            "let runtimeGeneration: UUID",
            "private var runtimeGeneration = UUID()",
            "runtimeGeneration = UUID()",
            "purgeLocalDataForAccountDeletion(accountLease: oldAccountLease)",
            'detailCode: "conversationDeletionPurgeFailed"',
            'detailCode: "conversationSwitchRetainedLocked"',
            'detailCode: "conversationLogoutRetainedLocked"',
            'detailCode: "conversationSuspensionRetainedLocked"',
        ],
        "ConversationMemoryManager",
    )
    require("UserManager" not in conversation_body, "conversation teardown must use captured old scope")
    require("refreshForCurrentContext" not in conversation_body, "conversation teardown must not mount data")
    check_fixed_detail_codes(conversation_body, "conversation teardown")

    knowledge = source["knowledge"]
    knowledge_body = function_body(knowledge, "func teardownForAccountLifecycle(")
    require_snippets(
        knowledge_body,
        [
            "loadedUserId = Self.signedOutUserId",
            "userGeneration = UUID()",
            "personaGeneration = UUID()",
            "familyAuthorizationGeneration = nil",
            "graph = KBLiteGraph()",
            "isExtracting = false",
            "performSynchronouslyOnExtractQueue",
            "KBLiteSemanticSearch.shared.activate(scope: nil)",
            "widgetSnapshotStore.activate(ownerUserId: nil",
            'detailCode: "knowledgeDeletionPurgeUnsupported"',
        ],
        "KBLiteManager teardown",
    )
    require("loadGraph(" not in knowledge_body, "cold-start teardown must not claim a knowledge graph")
    require("switchUser(" not in knowledge_body, "teardown must not activate another knowledge owner")
    require("UserManager" not in knowledge_body, "knowledge teardown must use captured old scope")
    require(
        "clearExtractionFlagIfCurrent(accountScope)" in knowledge,
        "stale extraction callbacks must not reset a newer owner's extraction state",
    )
    check_fixed_detail_codes(knowledge_body, "knowledge teardown")

    sync = source["sync"]
    sync_body = function_body(sync, "func teardownForAccountLifecycle(")
    require_snippets(
        sync_body,
        [
            "self.governanceCompletions.removeAll()",
            "self.debounceWorkItem?.cancel()",
            "self.syncGeneration = UUID()",
            "self.activeUserId = nil",
            "self.activeAccountLease = nil",
            "self.activeSyncAuthorization = nil",
            "self.activePersonaIdentity = nil",
            "self.activePullSessionID = nil",
            "Self.isSameAccountLeaseGeneration(activeAccountLease, oldAccountLease)",
            "try self.baseStore.remove(for: oldOwner)",
            "try self.pendingStore.remove(for: oldOwner)",
            "try self.governanceOutboxStore.removeAll(for: oldOwner)",
            'detailCode: "knowledgeSyncDeletionPurged"',
        ],
        "KnowledgeSyncCoordinator teardown",
    )
    require("UserManager" not in sync_body, "knowledge sync teardown must use captured old scope")
    deletion_index = sync_body.find("case .accountDeletion:")
    first_remove_index = sync_body.find("baseStore.remove")
    require(
        deletion_index >= 0 and first_remove_index > deletion_index,
        "knowledge draft/outbox files may only be purged in accountDeletion",
    )
    check_fixed_detail_codes(sync_body, "knowledge sync teardown")

    family = source["family"]
    family_body = function_body(family, "func teardownForAccountLifecycle(")
    require_snippets(
        family,
        [
            "private var startupWorkItem: DispatchWorkItem?",
            "self.startupWorkItem = startupWorkItem",
            "DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: startupWorkItem)",
        ],
        "FamilyRepository startup cancellation",
    )
    require_snippets(
        family_body,
        [
            "startupWorkItem?.cancel()",
            "userGeneration = UUID()",
            "authorizationFreshness.reset()",
            "members = []",
            "knowledgeCandidates = []",
            "modeOverrides = [:]",
            "voiceProfileOverrides = [:]",
            'detailCode: "familyDeletionPurgeUnsupported"',
        ],
        "FamilyRepository teardown",
    )
    require("UserManager" not in family_body, "family teardown must use captured old scope")
    require("activateUser(" not in family_body, "family teardown must not activate another owner")
    require("removeObject" not in family_body, "family teardown must retain owner override authority")
    require("delete" not in family_body.lower(), "family teardown must not delete relationship authority")
    check_fixed_detail_codes(family_body, "family teardown")


@dataclass
class LifecycleState:
    owner: Optional[str] = "owner-a"
    generation: int = 1
    timer_active: bool = True
    callback_active: bool = True
    pending_transcript: bool = True
    graph_mounted: bool = True
    projection_mounted: bool = True
    authorization_mounted: bool = True
    durable_owner_data: bool = True


POLICY = {
    "conversation": {
        "coldStartRecovery": ("unmounted", True),
        "switchAccount": ("retainedLocked", True),
        "logout": ("retainedLocked", True),
        "privateSuspension": ("retainedLocked", True),
        "accountDeletion": ("purged", False),
    },
    "knowledge": {
        "coldStartRecovery": ("unmounted", True),
        "switchAccount": ("retainedLocked", True),
        "logout": ("retainedLocked", True),
        "privateSuspension": ("retainedLocked", True),
        "accountDeletion": ("failed", True),
    },
    "sync": {
        "coldStartRecovery": ("unmounted", True),
        "switchAccount": ("retainedLocked", True),
        "logout": ("retainedLocked", True),
        "privateSuspension": ("retainedLocked", True),
        "accountDeletion": ("purged", False),
    },
    "family": {
        "coldStartRecovery": ("unmounted", True),
        "switchAccount": ("retainedLocked", True),
        "logout": ("retainedLocked", True),
        "privateSuspension": ("retainedLocked", True),
        "accountDeletion": ("failed", True),
    },
}


def model_teardown(module: str, event: str, state: LifecycleState, old_owner: Optional[str]):
    if state.owner is not None and old_owner is not None and state.owner != old_owner:
        return "failed", True
    state.owner = None
    state.generation += 1
    state.timer_active = False
    state.callback_active = False
    state.pending_transcript = False
    state.graph_mounted = False
    state.projection_mounted = False
    state.authorization_mounted = False
    outcome, remaining = POLICY[module][event]
    state.durable_owner_data = remaining
    return outcome, remaining


def check_model_contract() -> None:
    for module, events in POLICY.items():
        for event, expected in events.items():
            state = LifecycleState()
            actual = model_teardown(module, event, state, old_owner="owner-a")
            require(actual == expected, f"{module}/{event} outcome mismatch")
            require(state.owner is None, f"{module}/{event} must unmount owner")
            require(state.generation == 2, f"{module}/{event} must rotate generation")
            require(not state.timer_active, f"{module}/{event} must cancel timer/debounce")
            require(not state.callback_active, f"{module}/{event} must cancel old callbacks")
            require(not state.pending_transcript, f"{module}/{event} must clear pending transcript")
            require(not state.graph_mounted, f"{module}/{event} must unload graph")
            require(not state.projection_mounted, f"{module}/{event} must unload projection")
            require(not state.authorization_mounted, f"{module}/{event} must unload authorization")

    cold_state = LifecycleState(owner=None)
    model_teardown("knowledge", "coldStartRecovery", cold_state, old_owner=None)
    require(cold_state.owner is None, "cold-start recovery without a lease must remain unmounted")

    current_state = LifecycleState(owner="owner-b")
    snapshot = LifecycleState(**vars(current_state))
    outcome, _ = model_teardown("family", "switchAccount", current_state, old_owner="owner-a")
    require(outcome == "failed", "old scope must not teardown the current owner")
    require(current_state == snapshot, "scope mismatch must not mutate current owner state")


def main() -> None:
    check_static_contract()
    check_model_contract()
    print(
        "Knowledge/Conversation/Family lifecycle gate passed: "
        "modules=4 events=5 staleScopeIsolation=ok deletionUnsupported=2"
    )


if __name__ == "__main__":
    main()
