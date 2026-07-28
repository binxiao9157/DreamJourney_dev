#!/usr/bin/env python3
"""Guard the V4 boundary between legacy KBLite and Echo follow-up prompts."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DIALOG_ENGINE = ROOT / "DreamJourney/Sources/Services/DialogEngineManager.swift"
GAP_DETECTOR = ROOT / "DreamJourney/Sources/Services/KBLiteGapDetector.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    dialog_engine = DIALOG_ENGINE.read_text(encoding="utf-8")
    gap_detector = GAP_DETECTOR.read_text(encoding="utf-8")

    require(
        "KBLiteGapDetector.shared.buildGapContext()" not in dialog_engine,
        "legacy KBLite gap suggestions must not be injected into Echo prompts",
    )
    require(
        "legacy KBLite is a compatibility projection only" in dialog_engine,
        "DialogEngineManager must document the V4 compatibility boundary",
    )
    require(
        "buildGenerationAllowedContextString(query: nil)" in dialog_engine,
        "the scoped legacy compatibility read must remain explicit until Projection cutover",
    )
    require(
        "func buildGapContext() -> String" in gap_detector,
        "the detector may remain available to non-Echo legacy diagnostics",
    )

    print("V4 legacy KBLite gap prompt fence check passed")


if __name__ == "__main__":
    main()
