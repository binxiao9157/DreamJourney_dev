#!/usr/bin/env python3
"""Static G0 fence for the QA-only V1/V4 Context comparison client."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
VIEW_MODEL = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift"
VIEW_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"


def require(contents: str, fragments: list[str], *, label: str) -> None:
    missing = [fragment for fragment in fragments if fragment not in contents]
    if missing:
        raise AssertionError(f"{label} missing: {', '.join(missing)}")


def main() -> int:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    view_model = VIEW_MODEL.read_text(encoding="utf-8")
    view_controller = VIEW_CONTROLLER.read_text(encoding="utf-8")

    require(
        contracts,
        [
            "enum OwnerTruthContextShadowCompareDisposition",
            "struct OwnerTruthContextShadowCompare",
            "struct OwnerTruthContextShadowCompareRequestCorrelation",
            "protocol OwnerTruthContextShadowCompareClient",
            "owner-truth-context-shadow-compare-response-v1",
            "owner-truth-context-shadow-compare-v1",
            "owner-truth-context-shadow-compare-policy-v1",
            "ensureNoRawContentRecursively",
            "context comparison must remain QA-only and legacy read-only",
        ],
        label="Owner Truth Context compare contract",
    )
    require(
        client,
        [
            "func compareOwnerTruthContextShadow(",
            "/context-shadow/compare",
            "OwnerTruthContextCitationQAGate.isEnabled",
            "X-DreamJourney-QA-Owner-Truth",
            "OwnerTruthContextShadowCompare(",
            "extension DreamJourneyBackendClient: OwnerTruthContextShadowCompareClient {}",
        ],
        label="Owner Truth Context compare client",
    )

    compare_start = client.index("func compareOwnerTruthContextShadow(")
    compare_end = client.index("/// Narrows the hidden Owner Truth request", compare_start)
    compare_block = client[compare_start:compare_end]
    if "/context/build" in compare_block or "generationContext" in compare_block:
        raise AssertionError("QA comparison client must not call public Context or consume generation text")

    require(
        view_model,
        [
            "protocol EchoOwnerTruthContextShadowCompareTransport",
            "struct EchoOwnerTruthContextShadowCompareLease",
            "struct EchoOwnerTruthContextShadowCompareQAEvidenceReadout",
            "func requestOwnerTruthContextShadowCompare(",
            "ownerTruthContextCitationQAEnabled()",
            "ownerTruthMigrationParityQAEnabled()",
            "intent: \"echo_chat\"",
        ],
        label="Owner Truth Context compare Echo coordinator",
    )
    require(
        view_controller,
        [
            "lastOwnerTruthContextCompareEvidence",
            "observeOwnerTruthContextShadowCompareForEchoTurn",
            "recordOwnerTruthContextCompareQAEvidence",
            "ownerTruthContextCompareEvidence",
            "ctxCompare schema",
        ],
        label="Owner Truth Context compare QA evidence",
    )

    print("Product V4 iOS Owner Truth Context compare static check passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ValueError) as error:
        print(f"Product V4 iOS Owner Truth Context compare static check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
