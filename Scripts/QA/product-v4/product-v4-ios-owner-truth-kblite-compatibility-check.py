#!/usr/bin/env python3
"""Guard the default-off iOS Owner Truth Projection compatibility reader."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.find(marker)
    require(start >= 0, f"missing function: {name}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {name}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def type_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing type: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing type body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated type: {marker}")


def main() -> None:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "enum OwnerTruthKBLiteCompatibilityQAGate",
        'static let launchArgument = "DJEnableOwnerTruthKBLiteCompatibilityQA"',
        "enum OwnerTruthKBLiteCompatibilityReadState",
        "enum OwnerTruthKBLiteCompatibilityCacheDisposition",
        "struct OwnerTruthKBLiteCompatibilityFactCitation",
        "struct OwnerTruthKBLiteCompatibilityFact",
        "struct OwnerTruthKBLiteCompatibilityGraph",
        "struct OwnerTruthKBLiteCompatibilityReadEnvelope",
        "struct OwnerTruthKBLiteCompatibilityCachedProjection",
        "enum OwnerTruthKBLiteCompatibilityCacheLoadResult",
        "final class OwnerTruthKBLiteCompatibilityStore",
        "protocol OwnerTruthKBLiteCompatibilityClient",
        "final class OwnerTruthKBLiteCompatibilityProjectionUseCase",
        "enum OwnerTruthKBLiteCompatibilityProjectionPhase",
        "struct OwnerTruthKBLiteCompatibilityProjectionReadout",
        "struct OwnerTruthKBLiteCompatibilityProjectionViewState",
        "owner-truth-kblite-read-envelope-v1",
        "owner-truth-memory-projection",
        "case discard",
        "case replace",
        "SHA256.hash(data: data)",
        "cacheDisposition == .discard",
        "cacheDisposition == .replace",
    ):
        require(required in contracts, f"Owner Truth KBLite compatibility contract missing: {required}")

    require(
        "#if DEBUG || UI_QA_SIMULATOR" in contracts,
        "compatibility reader must remain unavailable in release builds",
    )
    require(
        "subjectID == accountLease.subjectId" in contracts
        and "vaultID == accountLease.vaultId" in contracts
        and "sessionID == accountLease.sessionId" in contracts
        and "generation == accountLease.generation" in contracts
        and "generationID == accountLease.generationId" in contracts
        and "leaseAuthorityEpoch == accountLease.authorityEpoch" in contracts,
        "cache envelope must bind every AccountLease identity component",
    )
    for checkpoint in (".request", ".commit", ".runtime"):
        require(
            f"accountLeaseRuntime.validate(accountLease, at: {checkpoint}).allowed" in contracts,
            f"cache read/write must validate AccountLease at {checkpoint}",
        )
    store_body = type_body(contracts, "final class OwnerTruthKBLiteCompatibilityStore")
    require(
        "KBLiteManager" not in store_body and "loadGraph" not in store_body,
        "compatibility store must not import or read the legacy KBLite writer",
    )
    require(
        "discardCachedProjection()" in store_body,
        "cache mismatch, corruption, and non-ready responses must delete local state",
    )
    require(
        "try? Data(contentsOf: cacheURL)" in store_body
        and "JSONDecoder().decode(CacheEnvelope.self, from: data)" in store_body,
        "cache must be parsed through the typed local envelope",
    )

    request_body = function_body(client, "fetchOwnerTruthKBLiteCompatibilityReadEnvelope")
    for required in (
        "OwnerTruthKBLiteCompatibilityQAGate.isEnabled",
        'path: "/v2/vaults/\\(pathComponent(vaultID.rawValue))/kblite-compatibility/read-envelope"',
        '"X-DreamJourney-QA-Owner-Truth": "1"',
        "authPolicy: .userRequired",
        "expectedOwnerSubjectID: expectedOwnerSubjectID",
    ):
        require(required in request_body, f"compatibility request boundary missing: {required}")
    require(
        "extension DreamJourneyBackendClient: OwnerTruthKBLiteCompatibilityClient {}" in client,
        "backend client must conform to the typed compatibility port",
    )
    require(
        "var isOwnerTruthKBLiteCompatibilityQAConfigured: Bool" in client,
        "runtime capability must expose only the QA-gated configuration state",
    )

    use_case_body = type_body(
        contracts, "final class OwnerTruthKBLiteCompatibilityProjectionUseCase"
    )
    for required in (
        "OwnerTruthKBLiteCompatibilityQAGate.isEnabled",
        "accountLeaseRuntime.validate(accountLease, at: .request).allowed",
        "accountLeaseRuntime.validate(accountLease, at: .commit).allowed",
        "accountLeaseRuntime.validate(accountLease, at: .runtime).allowed",
        "client.fetchOwnerTruthKBLiteCompatibilityReadEnvelope",
        "store.apply(envelope, for: accountLease)",
        "store.discardCachedProjection()",
        "guard generation == operationGeneration else { return }",
    ):
        require(required in use_case_body, f"compatibility projection use case missing: {required}")
    for forbidden in (
        "KBLiteManager",
        "KnowledgeSyncCoordinator",
        "syncKnowledge",
        "mutateKnowledge",
        "applySyncedGraphCAS",
    ):
        require(
            forbidden not in use_case_body,
            f"compatibility projection use case must not touch legacy sync: {forbidden}",
        )

    for test_name in (
        "func testKBLiteCompatibilityReadEnvelopeAcceptsOnlyConfirmedProjectionFacts()",
        "func testKBLiteCompatibilityReadEnvelopeRejectsTamperedContentHash()",
        "func testKBLiteCompatibilityStoreFailsClosedAcrossAccountABA()",
        "func testKBLiteCompatibilityStoreDiscardsNonReadyAndCorruptCaches()",
        "func testKBLiteCompatibilityProjectionUseCaseRefreshesOnlyTheIsolatedCache()",
        "func testKBLiteCompatibilityProjectionUseCaseDiscardsAStaleCompletion()",
        "func testKBLiteCompatibilityProjectionUseCaseDoesNotRequestWhenQAGateIsClosed()",
    ):
        require(test_name in tests, f"compatibility cache test missing: {test_name}")

    print(
        "Product V4 iOS Owner Truth KBLite compatibility check passed: Projection-only, "
        "QA-gated, owner-authenticated read envelope and lease-bound fail-closed cache remain isolated"
    )


if __name__ == "__main__":
    main()
