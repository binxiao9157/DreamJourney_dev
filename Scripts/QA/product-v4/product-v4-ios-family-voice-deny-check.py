#!/usr/bin/env python3
"""Guard the V4 rule that a family role cannot select a cloned voice in Echo."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def declaration_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing declaration: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing declaration body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : index + 1]
    raise AssertionError(f"unterminated declaration: {marker}")


def main() -> None:
    require(ECHO.is_file(), "EchoViewController.swift is missing")
    source = ECHO.read_text(encoding="utf-8")

    selection = declaration_body(source, "private struct EchoRoleVoiceProfileSelection")
    require("case familyVoiceNotPermitted" in selection, "missing family voice deny state")
    require(
        'return "家人复刻音色当前不可用于回响"' in selection,
        "family voice denial must have a clear fallback status",
    )
    require(
        "case .selfAssistantDefault, .personalOwner, .familyVoiceNotPermitted:\n            return false" in selection,
        "family voice denial must remain QA-only instead of exposing a public missing-voice state",
    )

    resolver = declaration_body(source, "private func resolveEchoRoleVoiceProfileSelection")
    require("source: .familyVoiceNotPermitted" in resolver, "family roles must resolve to a deny state")
    require("voiceProfileId: nil" in resolver, "family roles must clear the selected voice profile")
    require(
        "FamilyRepository.shared.acceptedMember" not in resolver,
        "family relationship lookup must not select a cloned voice for Echo",
    )
    require(
        "normalizedVoiceProfileId" not in resolver,
        "family voiceProfileId must not enter Echo role selection",
    )

    pcm_drive = declaration_body(source, "private func sendEchoReplyViaTencentVoiceClonePCMDrive")
    require(
        "let voiceSelection = resolveEchoRoleVoiceProfileSelection()" in pcm_drive,
        "PCM drive must use the role selection boundary",
    )
    require(
        "let voiceProfileId = voiceSelection.voiceProfileId" in pcm_drive,
        "PCM drive must not bypass the denied role selection",
    )

    qa_smoke = declaration_body(source, "func runUIQAEchoTraceEvidencePackagePanelExportSmoke")
    for required in (
        "S_uiqa_family_profile_must_not_route",
        "familyVoiceProfileBlocked",
        "familyVoiceNotPermitted",
        "voiceProfileId: nil",
        'reason: "familyVoiceNotPermitted"',
        'latestRuntimeVoiceProfileIdHash == "missing"',
    ):
        require(required in qa_smoke, f"family voice QA evidence missing: {required}")
    for forbidden in (
        "S_uiqa_family_panel_voice",
        'latestRoleVoiceSource == "familyMember"',
    ):
        require(forbidden not in qa_smoke, f"legacy family voice route remains in QA evidence: {forbidden}")

    print("Product V4 iOS family voice deny check passed")


if __name__ == "__main__":
    main()
