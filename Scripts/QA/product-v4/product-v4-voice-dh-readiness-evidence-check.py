#!/usr/bin/env python3
"""Guard QA-only Voice/Digital Human exit readiness evidence.

The Echo QA evidence bundle may report a selected voice profile, but it must
also state whether the local client could resolve that profile's exit boundary.
This prevents a deleted or disabled profile from being presented as a fully
cleared provider asset when no provider cleanup receipt exists.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    client = read(CLIENT)
    echo = read(ECHO)

    required_snapshot_fields = (
        "let voiceProfileExitEvidenceState: String?",
        "let voiceProfileExitState: String?",
        "let voiceProfileAccessRevoked: Bool?",
        "let voiceProfileLocalCleanupState: String?",
        "let voiceProfileProviderCleanupState: String?",
        "let voiceProfileProviderCleanupReceiptAvailable: Bool?",
    )
    for field in required_snapshot_fields:
        require(field in client, f"missing Voice/DH readiness evidence field: {field}")

    required_snapshot_assignments = (
        "self.voiceProfileExitEvidenceState = voiceProfileExitEvidenceState",
        "self.voiceProfileExitState = voiceProfileExitState",
        "self.voiceProfileAccessRevoked = voiceProfileAccessRevoked",
        "self.voiceProfileLocalCleanupState = voiceProfileLocalCleanupState",
        "self.voiceProfileProviderCleanupState = voiceProfileProviderCleanupState",
        "self.voiceProfileProviderCleanupReceiptAvailable = voiceProfileProviderCleanupReceiptAvailable",
    )
    for assignment in required_snapshot_assignments:
        require(assignment in client, f"missing Voice/DH readiness evidence assignment: {assignment}")

    for redacted_code_key in (
        '"voiceProfileExitEvidenceState"',
        '"voiceProfileExitState"',
        '"voiceProfileLocalCleanupState"',
        '"voiceProfileProviderCleanupState"',
    ):
        require(redacted_code_key in client, f"missing redacted readiness code key: {redacted_code_key}")

    require(
        "private func resolveVoiceProfileExitEvidence(" in echo,
        "Echo diagnostics must resolve the selected profile exit boundary",
    )
    for state in ('evidenceState: "notSelected"', 'evidenceState: "localResolved"', 'evidenceState: "unresolved"'):
        require(state in echo, f"missing conservative exit-evidence state: {state}")
    require(
        "VoiceCloneService.shared.voiceCloneShellSnapshot()" in echo,
        "Echo diagnostics must read the current owner-scoped VoiceClone snapshot",
    )
    require(
        "snapshot.voiceProfileId == voiceProfileId" in echo,
        "Echo diagnostics must require profile identity before reporting exit state",
    )

    for required_wiring in (
        "let voiceExitEvidence = resolveVoiceProfileExitEvidence(for: voiceSelection)",
        "voiceProfileExitEvidenceState: voiceExitEvidence.evidenceState",
        "voiceProfileExitState: voiceExitEvidence.exitState",
        "voiceProfileProviderCleanupReceiptAvailable: voiceExitEvidence.providerCleanupReceiptAvailable",
        '"voiceExit: evidence=',
    ):
        require(required_wiring in echo, f"missing Echo QA readiness wiring: {required_wiring}")

    forbidden = (
        "providerCleanupComplete",
        "thirdPartyCleanupComplete",
    )
    for claim in forbidden:
        require(claim not in echo, f"unsupported provider cleanup completion claim: {claim}")

    print("Product V4 Voice/DH readiness evidence check passed")


if __name__ == "__main__":
    main()
