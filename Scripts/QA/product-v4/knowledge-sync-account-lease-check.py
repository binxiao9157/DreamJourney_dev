#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.find(marker)
    require(start >= 0, f"KnowledgeSync function is missing: {name}")
    opening_brace = source.find("{", start)
    require(opening_brace >= 0, f"KnowledgeSync function has no body: {name}")

    depth = 0
    for index in range(opening_brace, len(source)):
        character = source[index]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    raise AssertionError(f"KnowledgeSync function body is unterminated: {name}")


def main() -> None:
    require(SOURCE.is_file(), "KnowledgeSyncCoordinator production file is missing")
    source = SOURCE.read_text()

    for snippet in (
        "private let accountLeaseRuntime = AccountLeaseRuntime.shared",
        "private struct KnowledgeSyncLeaseContext",
        "let userId: String",
        "let generation: UUID",
        "let accountLease: AccountLease",
        "accountLeaseRuntime.capture(forSubjectId: userId)",
        "private func isCurrent(",
        "_ context: KnowledgeSyncLeaseContext",
        "at checkpoint: AccountLeaseCheckpoint",
        "accountLeaseRuntime.validate(context.accountLease, at: checkpoint).allowed",
    ):
        require(snippet in source, f"KnowledgeSync AccountLease binding missing: {snippet}")
    require(
        source.count("accountLeaseRuntime.capture(forSubjectId:") == 1,
        "KnowledgeSync must capture only at its entry adapter, never inside async continuations",
    )

    debounce = function_body(source, "enqueueSync")
    require("context: KnowledgeSyncLeaseContext" in debounce, "debounce must capture the sync lease context")
    require("isCurrent(context, at: .timer)" in debounce, "debounce timer must validate its captured lease")
    require("startSync(context: context" in debounce, "debounce must forward the same lease context")
    require("capture(forSubjectId" not in debounce, "debounce must not recapture the current account")

    request_functions = (
        "startNextGovernance",
        "pullNextKnowledgePage",
        "recoverCompactedKnowledgeFeed",
        "pushLocalGraph",
        "pushLegacyMutation",
        "pushLegacySnapshot",
    )
    for name in request_functions:
        body = function_body(source, name)
        require("context: KnowledgeSyncLeaseContext" in body, f"{name} must receive the captured lease context")
        require("isCurrent(context, at: .request)" in body, f"{name} must validate before its request")
        require("isCurrent(context, at: .commit)" in body, f"{name} callback must validate before effects")
        require("capture(forSubjectId" not in body, f"{name} must not recapture after an async boundary")
        require(
            "UserManager.shared.currentUser" not in body,
            f"{name} must not substitute the current user after capturing its lease",
        )

    commit_functions = (
        "updateFamilyAuthorization",
        "performGovernance",
        "handleGovernancePayloadConflict",
        "handleGovernanceSuccess",
        "commitKnowledgePull",
        "applyAuthoritativeRemote",
        "pushLocalGraph",
        "recoverPendingOperationConflict",
        "saveLegacyBase",
        "loadBase",
        "loadPending",
        "loadGovernanceOutbox",
    )
    for name in commit_functions:
        body = function_body(source, name)
        has_bound_context = (
            "KnowledgeSyncLeaseContext" in body or "bindAccountLease(accountLease" in body
        )
        require(has_bound_context, f"{name} must bind commits to the captured lease")
        require(".commit" in body, f"{name} must validate the lease at commit")

    completion = function_body(source, "completeGovernance")
    require(
        "context: KnowledgeSyncLeaseContext" in completion,
        "governance completion must retain the operation lease context",
    )
    require(
        "isCurrent(context, at: .ui)" in completion,
        "governance completion must validate again when applied on the main queue",
    )

    outbox_enqueue = source.find("governanceOutboxStore.enqueue(")
    governance_request = source.find("DreamJourneyBackendClient.shared.governKnowledge(")
    require(
        0 <= outbox_enqueue < governance_request,
        "governance outbox durability must precede request dispatch",
    )
    governance_success = function_body(source, "handleGovernanceSuccess")
    authoritative_apply = governance_success.find("applyAuthoritativeRemote(")
    outbox_remove = governance_success.find("governanceOutboxStore.remove(")
    require(
        0 <= authoritative_apply < outbox_remove,
        "governance outbox removal must follow authoritative commit",
    )
    pending_recovery = function_body(source, "recoverPendingOperationConflict")
    pending_remove = pending_recovery.find("pendingStore.remove(")
    authoritative_refresh = pending_recovery.find("refreshAfterConflict(context: context)")
    require(
        0 <= pending_remove < authoritative_refresh,
        "poisoned pending mutation must be removed before authoritative refresh",
    )

    for store_call in (
        "baseStore.save(",
        "pendingStore.save(",
        "governanceOutboxStore.enqueue(",
        "governanceOutboxStore.replace(",
        "governanceOutboxStore.remove(",
        "KBLiteManager.shared.applySyncedGraphCAS(",
    ):
        require(store_call in source, f"expected KnowledgeSync commit surface is missing: {store_call}")

    print("KnowledgeSync AccountLease static check passed")


if __name__ == "__main__":
    main()
