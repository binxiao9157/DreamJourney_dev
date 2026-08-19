#!/usr/bin/env python3
"""Static PC-B3 guard for grounded/gap/fallback and public Citation hiding."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKEND = ROOT.parent / "DreamJourneyBackend"


def require(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise SystemExit(f"PC-B3 grounding check failed: {label} missing {marker!r}")


def forbid(text: str, marker: str, label: str) -> None:
    if marker in text:
        raise SystemExit(f"PC-B3 grounding check failed: {label} exposes {marker!r}")


backend_main = (BACKEND / "app/main.py").read_text(encoding="utf-8")
backend_citation = (BACKEND / "app/services/owner_truth_answer_citation.py").read_text(
    encoding="utf-8"
)
ios_client = (ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift").read_text(
    encoding="utf-8"
)
echo_view = (ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift").read_text(
    encoding="utf-8"
)

require(backend_main, '"ownerTruthMemoryProjection"', "backend grounded source")
require(backend_main, 'memory_outcome = "fallback"', "backend retrieval fallback")
require(backend_main, '"contentHash"', "backend response citation hash")
require(backend_main, "record_context_build", "backend automatic citation audit")
require(backend_citation, '"contextTraceIdHash"', "backend trace audit")

require(ios_client, "case fallback", "iOS grounding enum")
require(ios_client, "struct EchoAnswerGroundingQAEvidence", "iOS QA evidence")
require(ios_client, "citationContentHashDigests", "iOS redacted citation hashes")
require(echo_view, "lastEchoAnswerGroundingEvidence", "Echo QA evidence wiring")
forbid(echo_view, "citationSourceCard", "public Echo UI")
forbid(echo_view, "citationOriginalLink", "public Echo UI")

print("PC-B3 product-confirmed Echo grounding check passed")
