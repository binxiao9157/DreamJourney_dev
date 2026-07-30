#!/usr/bin/env python3
"""Guard the QA-only Owner Truth -> KBLite compatibility read boundary."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
BACKEND_CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def declaration_body(source: str, declaration: str) -> str:
    start = source.find(declaration)
    require(start >= 0, f"missing declaration: {declaration}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing declaration body: {declaration}")

    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : index + 1]
    raise AssertionError(f"unterminated declaration: {declaration}")


def main() -> None:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    backend_client = BACKEND_CLIENT.read_text(encoding="utf-8")

    gate = declaration_body(contracts, "enum OwnerTruthKBLiteCompatibilityQAGate")
    for snippet in (
        'static let launchArgument = "DJEnableOwnerTruthKBLiteCompatibilityQA"',
        "#if DEBUG || UI_QA_SIMULATOR",
        "ProcessInfo.processInfo.arguments.contains(launchArgument)",
        "#else\n        return false",
    ):
        require(snippet in gate, f"QA-only compatibility gate missing: {snippet}")

    envelope = declaration_body(
        contracts, "struct OwnerTruthKBLiteCompatibilityReadEnvelope"
    )
    for snippet in (
        'static let schemaVersion = "owner-truth-kblite-read-envelope-v1"',
        "let vaultID: OwnerTruthVaultID",
        "let ownerSubjectID: String",
        "let authorityEpoch: Int?",
        "let projectionCheckpoint: String?",
        "let contentHash: String?",
        'Self.nonEmptyString(object["vaultId"]) == expectedVaultID.rawValue',
        'Self.nonEmptyString(object["ownerSubjectId"]) == normalizedOwnerSubjectID',
        'Self.optionalNonnegativeInt(object["authorityEpoch"])',
        'object["projectionCheckpoint"]',
        'object["contentHash"]',
        "Self.isSHA256Digest(contentHash)",
        "Self.graphContentHash(graph) == contentHash",
    ):
        require(snippet in envelope, f"read-envelope contract missing: {snippet}")

    store = declaration_body(contracts, "final class OwnerTruthKBLiteCompatibilityStore")
    for snippet in (
        'static let fileName = "owner_truth_kblite_compatibility_v1.json"',
        "private struct CacheEnvelope: Codable",
        "let vaultID: String",
        "let subjectID: String",
        "let leaseAuthorityEpoch: String",
        "vaultID == accountLease.vaultId",
        "subjectID == accountLease.subjectId",
        "leaseAuthorityEpoch == accountLease.authorityEpoch",
        "func apply(",
        "func load(for accountLease: AccountLease)",
        "discardCachedProjection()",
    ):
        require(snippet in store, f"independent compatibility cache missing: {snippet}")
    for forbidden in ("kb_graph", "KBLiteManager", "KnowledgeSyncCoordinator", "/kb/sync"):
        require(forbidden not in store, f"compatibility cache must not touch legacy path: {forbidden}")

    fetch = declaration_body(
        backend_client, "func fetchOwnerTruthKBLiteCompatibilityReadEnvelope("
    )
    for snippet in (
        "guard OwnerTruthKBLiteCompatibilityQAGate.isEnabled else",
        'feature: "ownerTruthKBLiteCompatibility"',
        'reason: "qaOnlyDisabled"',
        'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/kblite-compatibility/read-envelope"',
        'additionalHeaders: ["X-DreamJourney-QA-Owner-Truth": "1"]',
        "expectedVaultID: vaultID",
        "expectedOwnerSubjectID: expectedOwnerSubjectID",
    ):
        require(snippet in fetch, f"QA compatibility transport missing: {snippet}")
    for forbidden in ("/kb/sync", "KBLiteManager", "KnowledgeSyncCoordinator", "kb_graph"):
        require(forbidden not in fetch, f"compatibility transport must not touch legacy path: {forbidden}")

    use_case = declaration_body(
        contracts, "final class OwnerTruthKBLiteCompatibilityProjectionUseCase"
    )
    for snippet in (
        "OwnerTruthKBLiteCompatibilityClient",
        "OwnerTruthKBLiteCompatibilityStore",
        "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
        "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
        "accountLeaseRuntime.validate(accountLease, at: .runtime).allowed",
        "client.fetchOwnerTruthKBLiteCompatibilityReadEnvelope",
        "store.apply(envelope, for: accountLease)",
        "store.discardCachedProjection()",
        "guard generation == operationGeneration else { return }",
    ):
        require(snippet in use_case, f"compatibility projection use case missing: {snippet}")
    for forbidden in (
        "KBLiteManager",
        "KnowledgeSyncCoordinator",
        "/kb/sync",
        "syncKnowledge",
        "mutateKnowledge",
        "applySyncedGraphCAS",
        "writeGraph",
    ):
        require(forbidden not in use_case, f"projection use case must not mutate legacy KBLite: {forbidden}")

    print("Owner Truth KBLite compatibility projection static check passed")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        print(
            f"Owner Truth KBLite compatibility projection static check failed: {exc}",
            file=sys.stderr,
        )
        raise SystemExit(1)
