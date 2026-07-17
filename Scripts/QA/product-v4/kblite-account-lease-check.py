#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MANAGER = ROOT / "DreamJourney/Sources/Services/KBLiteManager.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    opening = -1
    parenthesis_depth = 0
    for index in range(start, len(source)):
        character = source[index]
        if character == "(":
            parenthesis_depth += 1
        elif character == ")":
            parenthesis_depth -= 1
        elif character == "{" and parenthesis_depth == 0:
            opening = index
            break
    require(opening >= 0, f"missing function body: {signature}")
    depth = 0
    for index in range(opening, len(source)):
        character = source[index]
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return source[opening : index + 1]
    raise AssertionError(f"unterminated function: {signature}")


def main() -> None:
    manager = MANAGER.read_text()

    for snippet in (
        "struct KBLiteAccountLeaseScope",
        "let accountLease: AccountLease",
        "let ownerUserId: String",
        "let graphGeneration: UUID",
        "private let accountLeaseRuntime: AccountLeaseRuntimePort",
        "captureAccountLeaseScope(",
        "validateAccountLeaseScope(",
        "accountLeaseRuntime.validate(scope.accountLease, at: checkpoint)",
    ):
        require(snippet in manager, f"KBLite AccountLease scope missing: {snippet}")

    save = function_body(manager, "private func save(")
    for snippet in (
        "stagePersistedGraph",
        "at: .commit",
        "commitStagedGraph",
        "publishGraphEffects",
    ):
        require(snippet in save, f"save must keep one lease through persistence: {snippet}")
    require(
        "captureAccountLeaseScope" not in save,
        "save must not recapture a newer account lease",
    )

    commit = function_body(manager, "private func commitStagedGraph(")
    require(
        commit.count("at: .commit") >= 2,
        "file replacement must validate the same lease before and after commit",
    )
    require(
        "restorePersistedGraph" in commit,
        "a lease invalidated during replacement must roll back the stale file",
    )

    extraction = function_body(manager, "func extractFromTranscript(")
    for snippet in (
        "accountScope = captureAccountLeaseScope",
        "accountScope: accountScope",
        "at: .runtime",
    ):
        require(snippet in extraction, f"extraction launch lease missing: {snippet}")

    finish = function_body(manager, "private func finishExtraction(")
    for snippet in (
        "validateAccountLeaseScope(accountScope",
        "at: .commit",
        "save(accountScope: accountScope",
        "deliverExtractionCompletion",
    ):
        require(snippet in finish, f"extraction completion lease missing: {snippet}")
    require(
        "captureAccountLeaseScope" not in finish,
        "extraction completion must not recapture current account",
    )

    effects = function_body(manager, "private func publishGraphEffects(")
    for snippet in (
        "at: .runtime",
        "widgetSnapshotStore.publish",
        "at: .ui",
        "NotificationCenter.default.post",
    ):
        require(snippet in effects, f"post-commit effect checkpoint missing: {snippet}")

    warm = function_body(manager, "private func warmSemanticCache(")
    require("validateAccountLeaseScope(accountScope" in warm, "semantic work must retain its launch lease")
    require("at: .runtime" in warm, "semantic callback must validate runtime lease")
    require("captureAccountLeaseScope" not in warm, "semantic callback must not recapture current account")

    for signature in (
        "func writeGraph(",
        "func ingestImageAnalysis(",
        "func applySyncedGraphCAS(",
        "func importJSON(",
        "func reset()",
    ):
        body = function_body(manager, signature)
        require(
            "captureAccountLeaseScope" in body,
            f"account-scoped mutation must capture a lease at launch: {signature}",
        )

    print("KBLite AccountLease static check passed")


if __name__ == "__main__":
    main()
