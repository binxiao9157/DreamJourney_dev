#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
STORE = ROOT / "DreamJourney/Sources/Services/EchoDelayedReplyStore.swift"
SCHEDULER = ROOT / "DreamJourney/Sources/Services/EchoDelayedReplyNotificationScheduler.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def body_after(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing declaration: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated body: {marker}")


def require_ordered(source: str, snippets: tuple[str, ...], label: str) -> None:
    cursor = 0
    for snippet in snippets:
        index = source.find(snippet, cursor)
        require(index >= 0, f"{label} missing or out of order: {snippet}")
        cursor = index + len(snippet)


def main() -> None:
    store = STORE.read_text()
    scheduler = SCHEDULER.read_text()

    envelope = body_after(store, "struct EchoDelayedReplyEnvelope")
    for field in (
        "let subjectId: String",
        "let vaultId: String",
        "let generation: UInt64",
        "let generationId: UUID",
        "let authorityEpoch: String",
        "let resourceOwnerId: String",
        "let operationId: String",
        "let reply: EchoDelayedReply",
    ):
        require(field in envelope, f"delayed reply envelope identity missing: {field}")

    ownership_match = body_after(store, "func matchesOwnership(")
    for field in (
        "subjectId",
        "vaultId",
        "generation",
        "generationId",
        "authorityEpoch",
        "resourceOwnerId",
        "operationId",
    ):
        require(field in ownership_match, f"envelope ownership match omits {field}")

    scope = body_after(store, "struct EchoDelayedReplyOperationScope")
    for field in (
        "accountLease.subjectId",
        "accountLease.vaultId",
        "accountLease.generation",
        "accountLease.generationId",
        "accountLease.authorityEpoch",
        "resourceOwnerId",
        "operationId",
    ):
        require(field in scope, f"operation scope digest/key omits {field}")
    require(
        "SHA256.hash" in scope,
        "owner and operation identities must use a stable one-way digest",
    )

    for signature in (
        r"func save\(\s*_ reply: EchoDelayedReply,\s*resourceOwnerId: String,\s*operationId: String,\s*accountLease: AccountLease",
        r"func load\(\s*resourceOwnerId: String,\s*operationId: String,\s*accountLease: AccountLease",
        r"func clear\(\s*resourceOwnerId: String,\s*operationId: String,\s*accountLease: AccountLease",
    ):
        require(re.search(signature, store) is not None, f"explicit store API missing: {signature}")

    save_wrapper = body_after(store, "func save(_ reply: EchoDelayedReply)")
    require(save_wrapper.count("capture(forSubjectId: nil)") == 1, "save wrapper must capture one lease")
    require("resourceOwnerId: accountLease.subjectId" in save_wrapper, "save wrapper must derive owner once")
    require("operationId: reply.id" in save_wrapper, "save wrapper must derive operation once")
    require("capture(" not in body_after(store, "resourceOwnerId: String,\n        operationId: String,\n        accountLease: AccountLease"), "explicit store API must not recapture at commit")

    require(
        'private let legacyStorageKey = "dj.echo.delayedReply"' in store,
        "the old global key must be named only as legacy input",
    )
    require(
        re.search(r"defaults\.set\([\s\S]{0,160}forKey:\s*legacyStorageKey", store) is None,
        "the global legacy key must never receive new writes",
    )
    legacy_isolation = body_after(store, "func isolateLegacyPayloadIfNeeded")
    for snippet in (
        "legacyQuarantineStorageKey",
        "legacyIsolationReceiptKey",
        ".missingAuthenticatedOwner",
        "defaults.removeObject(forKey: legacyStorageKey)",
    ):
        require(snippet in legacy_isolation, f"legacy isolation is not explainable: {snippet}")
    require("decode(EchoDelayedReplyEnvelope.self" not in legacy_isolation, "legacy payload must not be auto-owned")

    require(
        "protocol EchoDelayedReplyNotificationRequestCenter" in scheduler,
        "notification request operations must be injectable for the G0 model",
    )
    for signature in (
        r"func schedule\(\s*_ delayedReply: EchoDelayedReply,\s*resourceOwnerId: String,\s*operationId: String,\s*accountLease: AccountLease",
        r"func cancelPendingDelayedReply\(\s*resourceOwnerId: String,\s*operationId: String,\s*accountLease: AccountLease",
    ):
        require(re.search(signature, scheduler) is not None, f"explicit scheduler API missing: {signature}")

    request_builder = body_after(scheduler, "func makeRequest(")
    for route_metadata in (
        "NotificationRuntimeRoutePayload.Key.schemaVersion",
        "NotificationRuntimeRoutePayload.Key.action",
        "NotificationRuntimeRouteAction.open.rawValue",
    ):
        require(
            route_metadata in request_builder,
            f"notification runtime route metadata missing: {route_metadata}",
        )
    for metadata_key in (
        '"type"',
        '"trigger"',
        '"accountSubjectIdentity"',
        '"accountLeaseGeneration"',
        '"accountLeaseGenerationIdentity"',
        '"accountLeaseVaultIdentity"',
        '"accountLeaseAuthorityEpochIdentity"',
        '"resourceOwnerIdentity"',
        '"operationIdentity"',
    ):
        require(metadata_key in request_builder, f"notification metadata missing: {metadata_key}")
    for raw_metadata_key in (
        '"subjectId"',
        '"vaultId"',
        '"sessionId"',
        '"authorityEpoch"',
        '"generationId"',
        '"accountLeaseGenerationId"',
        '"resourceOwnerId"',
        '"delayedReplyId"',
        '"operationId"',
    ):
        require(
            raw_metadata_key not in request_builder,
            f"notification userInfo must reject raw metadata field: {raw_metadata_key}",
        )
    require(
        "delayedReply.id" not in request_builder,
        "notification userInfo must not serialize the raw delayed-reply operation",
    )
    generation_identity = body_after(scheduler, "static func generationIdentity(")
    require(
        "EchoDelayedReplyOperationScope.identityDigest(" in generation_identity
        and "accountLease.generationId.uuidString" in generation_identity,
        "generation UUID metadata must be represented only by its one-way identity digest",
    )
    require(
        "scope.notificationIdentifier" in request_builder,
        "notification request identifier must come from the owner/generation scope",
    )

    owner_match = body_after(
        scheduler,
        "private func requestIsOwned(\n        _ request: UNNotificationRequest,\n        by accountLease",
    )
    require(
        'userInfo["accountLeaseGenerationIdentity"] as? String' in owner_match
        and "Self.generationIdentity(for: accountLease)" in owner_match,
        "notification ownership queries must compare the generation UUID digest",
    )
    require(
        'userInfo["accountLeaseGenerationId"]' not in owner_match,
        "notification ownership queries must not depend on a raw generation UUID field",
    )

    stale_callback = body_after(scheduler, "requestCenter.add(request)")
    require_ordered(
        stale_callback,
        (
            "validate(scope.accountLease, at: .timer).allowed",
            "removeStaleRequestIfOwned(scope: scope)",
            "validate(scope.accountLease, at: .ui).allowed",
            "completion?(error)",
        ),
        "notification add callback fence",
    )
    stale_cleanup = body_after(scheduler, "func removeStaleRequestIfOwned")
    for snippet in (
        "request.identifier == scope.notificationIdentifier",
        "requestIsOwned(request, by: scope)",
    ):
        require(snippet in stale_cleanup, f"stale cleanup is not envelope-owned: {snippet}")
    require(
        re.search(
            r"removePendingNotificationRequests\(\s*"
            r"withIdentifiers:\s*\[scope\.notificationIdentifier\]",
            stale_cleanup,
        )
        is not None,
        "stale cleanup must remove only the original scoped identifier",
    )

    cancellation = body_after(
        scheduler,
        "func cancelPendingDelayedReply(\n        resourceOwnerId: String,",
    )
    require("removeRequestsOwned(" in cancellation, "explicit cancellation must filter by owner envelope")
    require("operationId: operationId" in cancellation, "explicit cancellation must retain operation identity")
    require(
        "[Self.notificationIdentifier]" not in scheduler,
        "the global delayed-reply identifier must never be cancelled",
    )

    print("Echo delayed reply owner-scope static check passed")


if __name__ == "__main__":
    main()
