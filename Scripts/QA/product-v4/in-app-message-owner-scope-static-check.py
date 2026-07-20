#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = ROOT / "DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift"


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


def function_body(source: str, signature_pattern: str, label: str) -> str:
    match = re.search(signature_pattern, source, re.MULTILINE)
    require(match is not None, f"missing function: {label}")
    opening = source.find("{", match.end())
    require(opening >= 0, f"missing function body: {label}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated function: {label}")


def compact(value: str) -> str:
    return "".join(value.split())


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    normalized = compact(source)
    for snippet in snippets:
        require(compact(snippet) in normalized, f"{label} missing: {snippet}")


def explicit_api_body(class_body: str, name: str, first_parameter: str) -> str:
    pattern = (
        rf"func\s+{name}\s*\(\s*{first_parameter}[\s\S]*?"
        r"accountLease\s*:\s*AccountLease\s*,\s*"
        r"resourceOwnerId\s*:\s*String\s*,\s*"
        r"operationId\s*:\s*String[\s\S]*?\)"
    )
    return function_body(class_body, pattern, f"{name} explicit owner-scope API")


def check_store(
    source: str,
    class_name: str,
    surface: str,
    legacy_key: str,
    source_type: str,
) -> None:
    store = declaration_body(source, f"final class {class_name}")
    require(
        store.count(f'"{legacy_key}"') == 1,
        f"{class_name} legacy global key must be declared exactly once and remain read-only",
    )
    require_all(
        store,
        (
            "private let defaults: UserDefaults",
            "private let accountLeaseRuntime: AccountLeaseRuntimePort",
            "retireLegacyGlobalPayloadIfNeeded()",
            "legacyRetirementStatus()",
            "legacyRetirementReceipt()",
            "legacyQuarantinePayload()",
            "accountLeaseRuntime.validate",
        ),
        class_name,
    )

    sources = explicit_api_body(store, "sources", "")
    save = explicit_api_body(store, "save", rf"_\s+\w+\s*:\s*\[{source_type}\]\s*,\s*")
    clear = explicit_api_body(store, "clear", "")
    require("capture(" not in sources, f"{class_name} explicit read must retain its supplied lease")
    require("capture(" not in save, f"{class_name} explicit save must retain its supplied lease")
    require("capture(" not in clear, f"{class_name} explicit clear must retain its supplied lease")
    require_all(
        sources,
        ("at: .request", "at: .runtime", "resourceOwnerId", "operationId"),
        f"{class_name} scoped read",
    )
    require_all(
        save,
        ("at: .request", "at: .commit", "resourceOwnerId", "operationId"),
        f"{class_name} scoped save",
    )
    require_all(
        clear,
        ("at: .request", "at: .commit", "resourceOwnerId", "operationId"),
        f"{class_name} scoped clear",
    )

    wrapper_sources = function_body(
        store,
        r"func\s+sources\s*\(\s*\)\s*->",
        f"{class_name} compatibility sources",
    )
    wrapper_save = function_body(
        store,
        rf"func\s+save\s*\(\s*_\s+\w+\s*:\s*\[{source_type}\]\s*\)\s*",
        f"{class_name} compatibility save",
    )
    wrapper_clear = function_body(
        store,
        r"func\s+clear\s*\(\s*\)\s*",
        f"{class_name} compatibility clear",
    )
    for body, label in (
        (wrapper_sources, "sources"),
        (wrapper_save, "save"),
        (wrapper_clear, "clear"),
    ):
        require(
            body.count("capture(forSubjectId: nil)") == 1,
            f"{class_name} compatibility {label} must capture exactly once",
        )
        require_all(
            body,
            ("accountLease: accountLease", "resourceOwnerId: accountLease.subjectId", "operationId:"),
            f"{class_name} compatibility {label} forwarding",
        )

    require(
        f"defaults.set(data, forKey: legacyStorageKey)" not in store,
        f"{class_name} must never write the legacy global key",
    )
    require(
        f"storageKey(for: .{surface})" in store,
        f"{class_name} must use the owner scope key for {surface}",
    )


def main() -> None:
    require(SOURCE_PATH.is_file(), "InAppMessageCenter.swift is missing")
    source = SOURCE_PATH.read_text()

    scope = declaration_body(source, "struct InAppMessageOwnerScope")
    require_all(
        scope,
        (
            "let subjectId: String",
            "let vaultId: String",
            "let sessionId: String",
            "let generation: UInt64",
            "let generationId: UUID",
            "let authorityEpoch: String",
            "let resourceOwnerId: String",
            "let operationId: String",
            "accountLease.subjectId",
            "accountLease.vaultId",
            "accountLease.sessionId",
            "accountLease.generation",
            "accountLease.generationId",
            "accountLease.authorityEpoch",
            "scopeDigest",
        ),
        "complete in-app message owner scope",
    )
    envelope = declaration_body(source, "struct InAppMessageSourceEnvelope")
    require_all(
        envelope,
        (
            "let subjectId: String",
            "let vaultId: String",
            "let sessionId: String",
            "let generation: UInt64",
            "let generationId: UUID",
            "let authorityEpoch: String",
            "let resourceOwnerId: String",
            "let operationId: String",
            "matches(_ scope: InAppMessageOwnerScope)",
        ),
        "owner-scoped message envelope",
    )

    require_all(
        source,
        (
            "protocol InAppMessageResourceOwnerSource",
            "struct OwnerAwareFamilyInvitationMessageSource",
            "extension FamilyMember: InAppMessageResourceOwnerSource",
            "struct InAppMessageLegacyRetirementReceipt",
            "enum InAppMessageLegacyRetirementStatus",
            "case quarantined",
            'ownerEvidence: "unverified"',
            "InAppMessageLegacyQuarantineRecord",
        ),
        "owner projection and legacy retirement contract",
    )

    for name in ("fromFamilyInvitation", "fromSystemNotice", "fromEchoReply"):
        mapping = function_body(
            source,
            rf"static\s+func\s+{name}\s*\(",
            name,
        )
        require_all(
            mapping,
            ("authenticatedResourceOwnerId", "ownerUserId: resourceOwnerId"),
            f"{name} owner projection",
        )
        require("ownerUserId: nil" not in mapping, f"{name} must not create ownerless messages")

    care_mapping = function_body(source, r"static\s+func\s+fromCareSignal\s*\(", "fromCareSignal")
    require_all(
        care_mapping,
        ("careSignalOwnerUserId", "ownerUserId: resourceOwnerId"),
        "fromCareSignal owner projection",
    )
    require("ownerUserId: source.careSignalOwnerUserId" not in care_mapping, "care signals must fail closed without an owner")

    for forbidden in (
        "ownerUserId: source.familyMemberId",
        "ownerUserId: source.systemNoticeId",
        "ownerUserId: source.echoReplyId",
        "ownerUserId: source.echoReplyTrigger",
    ):
        require(forbidden not in source, f"message/voice/persona identifiers cannot be principals: {forbidden}")

    for name in ("markingRead", "markingArchived"):
        transition = function_body(source, rf"func\s+{name}\s*\(", name)
        require(
            "ownerUserId: ownerUserId" in transition,
            f"{name} must preserve resource-owner metadata",
        )

    check_store(
        source,
        "SystemNoticeMessageStore",
        "systemNotice",
        "dj.inAppMessage.systemNotice.sources",
        "StaticSystemNoticeMessageSource",
    )
    check_store(
        source,
        "EchoReplyMessageStore",
        "echoReply",
        "dj.inAppMessage.echoReply.sources",
        "StaticEchoReplyMessageSource",
    )

    echo_store = declaration_body(source, "final class EchoReplyMessageStore")
    arrived = explicit_api_body(
        echo_store,
        "saveArrivedReply",
        r"id\s*:\s*String\s*,\s*sourceAnswerID\s*:\s*String\s*,\s*"
        r"deliverAt\s*:\s*Date\s*,\s*trigger\s*:\s*String\s*,\s*",
    )
    require("capture(" not in arrived, "explicit arrived-reply save must retain its supplied lease")
    require_all(
        arrived,
        (
            "normalizedId == normalizedOperationId",
            "normalizedSourceAnswerID",
            "!normalizedSourceAnswerID.isEmpty",
            "echoReplySourceAnswerID: normalizedSourceAnswerID",
            "return withLock",
            "inboxSources(",
            "accountLease: accountLease",
            "resourceOwnerId: resourceOwnerId",
            "operationId: Self.inboxOperationId",
        ),
        "explicit arrived-reply forwarding",
    )
    arrived_wrapper = function_body(
        echo_store,
        r"func\s+saveArrivedReply\s*\(\s*id\s*:\s*String\s*,\s*"
        r"sourceAnswerID\s*:\s*String\s*,\s*deliverAt\s*:\s*Date\s*,\s*"
        r"trigger\s*:\s*String\s*\)",
        "compatibility arrived-reply save",
    )
    require(
        arrived_wrapper.count("capture(forSubjectId: nil)") == 1,
        "compatibility arrived-reply save must capture exactly once",
    )
    require_all(
        arrived_wrapper,
        ("accountLease: accountLease", "resourceOwnerId: accountLease.subjectId", "operationId:"),
        "compatibility arrived-reply forwarding",
    )

    print("In-app message owner scope static check passed")


if __name__ == "__main__":
    main()
