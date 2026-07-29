#!/usr/bin/env python3
"""Static guard for QA-only live legacy/Owner Truth Context parity evidence."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
ECHO_VIEW_MODEL = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift"
ECHO_VIEW_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
BACKEND_CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
TESTS = ROOT / "DreamJourneyTests/AudioOwnerLeaseModelTests.swift"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def section(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    require(start_index >= 0, f"missing section start: {start}")
    end_index = source.find(end, start_index)
    require(end_index >= 0, f"missing section end: {end}")
    return source[start_index:end_index]


def main() -> int:
    view_model = read(ECHO_VIEW_MODEL)
    controller = read(ECHO_VIEW_CONTROLLER)
    backend_client = read(BACKEND_CLIENT)
    tests = read(TESTS)

    for required in [
        "struct EchoOwnerTruthContextParityLease",
        "struct EchoOwnerTruthContextParityLegacyObservation",
        "struct EchoOwnerTruthContextParityShadowObservation",
        "struct EchoOwnerTruthContextParityQAEvidenceReadout",
        "observedNonPromoting",
        "promotionDecision",
        "enum EchoOwnerTruthContextParityAdapter",
        "OwnerTruthMigrationParityViewStateComparator.compare(",
        "func beginOwnerTruthContextParity(",
        "func recordOwnerTruthContextParityLegacy(",
        "func recordOwnerTruthContextParityShadow(",
        "func invalidateOwnerTruthContextParity(",
        "OwnerTruthContextCitationQAGate.isEnabled",
        "OwnerTruthMigrationParityQAGate.isEnabled",
    ]:
        require(required in view_model, f"live Context parity must define {required}")

    adapter = section(
        view_model,
        "enum EchoOwnerTruthContextParityAdapter",
        "/// Incremental application coordinator for Echo business requests.",
    )
    for forbidden in [
        "generationContextText",
        "DialogEngine",
        "submitEchoTurnKnowledgeContext",
        "buildOwnerTruthContextShadow(",
    ]:
        require(
            forbidden not in adapter,
            f"parity adapter must not own reply input, transport, or raw context text: {forbidden}",
        )

    for required in [
        "beginOwnerTruthContextParity(",
        "recordOwnerTruthContextParityLegacy(",
        "recordOwnerTruthContextParityShadow(",
        "recordOwnerTruthContextParityQAEvidence(",
        "lastOwnerTruthContextParityEvidence",
        "ctxParity schema",
    ]:
        require(required in controller, f"Echo controller must keep parity evidence QA-only: {required}")

    for required in [
        "schemaVersion = 3",
        "ownerTruthContextParityEvidence",
        "echoQaBundle-v3",
        "Owner Truth Context V1/V4 parity",
    ]:
        require(required in backend_client, f"QA evidence bundle must carry parity evidence: {required}")

    for required in [
        "testOwnerTruthContextParityRequiresBothQAGates",
        "testOwnerTruthContextParityPairsRealContractShapesWithoutPromotion",
        "testOwnerTruthContextParityRejectsQueryMismatchAndContextInvalidation",
    ]:
        require(required in tests, f"focused coordinator tests must cover parity guard: {required}")

    print(
        "Product V4 live Echo Context parity check passed: "
        "V1/V4 evidence is pair-fenced, value-minimized, QA-only, and non-promoting"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"Product V4 live Echo Context parity check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
