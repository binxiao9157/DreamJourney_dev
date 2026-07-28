#!/usr/bin/env python3
"""Guard the QA-only C05 legacy/V4 ViewState parity comparator."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


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
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "enum OwnerTruthMigrationParityQAGate",
        'static let launchArgument = "DJEnableOwnerTruthMigrationParityQA"',
        "#if DEBUG || UI_QA_SIMULATOR",
        "struct OwnerTruthMigrationParityDigest",
        "enum OwnerTruthMigrationParitySurface",
        "enum OwnerTruthMigrationParityClientGeneration",
        "enum OwnerTruthMigrationParityRouteDecision",
        "enum OwnerTruthMigrationParityVisibility",
        "enum OwnerTruthMigrationParityViewStatePhase",
        "enum OwnerTruthMigrationParityCacheState",
        "enum OwnerTruthMigrationParityMismatchCode",
        "struct OwnerTruthMigrationParityAuthorityBinding",
        "struct OwnerTruthMigrationParityViewStateSnapshot",
        "struct OwnerTruthMigrationParityM08Disposition",
        "struct OwnerTruthMigrationParityViewStateMismatch",
        "struct OwnerTruthMigrationParityViewStateReport",
        "enum OwnerTruthMigrationParityViewStateComparator",
        "owner-truth-migration-view-state-parity-v1",
        "guard legacy.source == .legacy, v4.source == .v4 else",
        "guard legacy.surface == v4.surface else",
        "guard qaGateEnabled else",
        "m08Dispositions",
        "m08DispositionStatus",
    ):
        require(required in contracts, f"C05 ViewState parity contract missing: {required}")

    for code in range(1, 9):
        require(f'"M{code:02d}"' in contracts, f"C05 mismatch taxonomy missing M{code:02d}")

    require(
        "self != .m08Presentation" in contracts,
        "M01-M07 must remain promotion blockers",
    )
    require(
        "approvalReferenceHash" in contracts and "expiresAt > date" in contracts,
        "M08 disposition must be scoped and expiring",
    )
    require(
        "A caller\n/// may use the returned report as QA evidence only" in contracts,
        "comparator must remain evidence-only rather than an Authority selector",
    )

    snapshot = type_body(contracts, "struct OwnerTruthMigrationParityViewStateSnapshot")
    report = type_body(contracts, "struct OwnerTruthMigrationParityViewStateReport")
    mismatch = type_body(contracts, "struct OwnerTruthMigrationParityViewStateMismatch")
    value_minimized_source = "\n".join((snapshot, report, mismatch))
    for prohibited in (
        "let query:",
        "let text:",
        "let content:",
        "let routeURL:",
        "let ownerSubjectID:",
        "let vaultID:",
        "let title:",
    ):
        require(
            prohibited not in value_minimized_source,
            f"C05 ViewState parity evidence must not retain raw value: {prohibited}",
        )

    comparator = type_body(contracts, "enum OwnerTruthMigrationParityViewStateComparator")
    for prohibited in (
        "URLSession",
        "UserDefaults",
        "FileManager",
        "write(",
        "POST",
    ):
        require(
            prohibited not in comparator,
            f"C05 ViewState comparator must remain pure and non-writing: {prohibited}",
        )

    for test_name in (
        "func testMigrationViewStateParityMatchesEquivalentLegacyAndV4Read()",
        "func testMigrationViewStateParityClassifiesAllBlockingDimensions()",
        "func testMigrationViewStateParityAllowsOnlyScopedUnexpiredM08PresentationDisposition()",
        "func testMigrationViewStateParityRejectsDisabledGateAndInvalidSourcePairs()",
        "func testMigrationViewStateParitySnapshotRejectsRawOrMalformedDigest()",
        "func fetchOwnerTruthInterviewNaturalInputCurrentSession(",
    ):
        require(test_name in tests, f"C05 ViewState parity regression coverage missing: {test_name}")

    print(
        "Product V4 iOS C05 ViewState parity check passed: QA-only legacy/V4 "
        "comparison is hash-only, M01-M07 block promotion, and M08 requires "
        "a scoped expiring disposition"
    )


if __name__ == "__main__":
    main()
