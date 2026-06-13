#!/usr/bin/env python3
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROUTE_SWIFT = ROOT / "DreamJourney/Sources/Services/RoadshowDemoRoute.swift"
PREFLIGHT = ROOT / "Scripts/roadshow_device_smoke_preflight.sh"
VERIFY_PHASE2 = ROOT / "Scripts/verify_phase2.sh"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    route_source = ROUTE_SWIFT.read_text(encoding="utf-8")
    preflight_source = PREFLIGHT.read_text(encoding="utf-8")
    verify_phase2_source = VERIFY_PHASE2.read_text(encoding="utf-8")

    step_ids = re.findall(r'id:\s*"([^"]+)"', route_source)
    if len(step_ids) != 6:
        return fail(f"expected 6 roadshow step ids, got {len(step_ids)}: {step_ids}")

    prefix_match = re.search(r'completionKeyPrefix\s*=\s*"([^"]+)"', route_source)
    if not prefix_match:
        return fail("missing RoadshowDemoRoute.completionKeyPrefix")
    prefix = prefix_match.group(1)

    missing_keys = [
        f"{prefix}{step_id}"
        for step_id in step_ids
        if f"{prefix}{step_id}" not in preflight_source
    ]
    if missing_keys:
        return fail(f"preflight scaffold missing completion keys: {missing_keys}")

    required_files = [
        "evidence_manifest.json",
        "evidence_status.json",
        "evidence_status.md",
        "archive_package_next_steps.txt",
        "screens/01_home_banner.png",
        "screens/02_route_checklist.png",
        "screens/03_memory_voice_digital_human.png",
        "screens/04_time_mailbox_delivered_letter.png",
        "screens/05_memory_archive_photo_analysis.png",
        "screens/06_family_footprint_world_generation.png",
        "screens/07_family_care_dashboard_member.png",
        "screens/08_share_package_export_sheet.png",
        "recordings/roadshow_6min_run.mp4",
        "route_completion/route_completion_preferences.txt",
        "share_packages/all_family.json",
        "share_packages/selected_member.json",
        "share_packages/privacy_check.log",
        "diagnostics/digital_human_readiness.txt",
        "diagnostics/digital_human_readiness.json",
        "diagnostics/digital_human_playback.log",
        "route_completion/route_acceptance_checklist.md",
    ]
    missing_files = [path for path in required_files if path not in preflight_source]
    if missing_files:
        return fail(f"preflight scaffold missing evidence files: {missing_files}")

    required_reporter_tokens = [
        "Scripts/roadshow_evidence_report.py",
        "--write --quiet",
        "Evidence package status",
        "--write --archive --fail-on-missing",
    ]
    missing_reporter_tokens = [token for token in required_reporter_tokens if token not in preflight_source]
    if missing_reporter_tokens:
        return fail(f"preflight does not invoke evidence reporter: {missing_reporter_tokens}")

    route_completion_tokens = [
        '"$EVIDENCE_DIR/route_completion/route_completion_preferences.txt"',
        'for route_key in',
        'printf \'%s=\' "$route_key"',
        '/usr/libexec/PlistBuddy -c "Print :$route_key"',
    ]
    missing_route_completion_tokens = [
        token for token in route_completion_tokens if token not in preflight_source
    ]
    if missing_route_completion_tokens:
        return fail(
            "preflight should auto-export route completion preferences: "
            f"{missing_route_completion_tokens}"
        )

    route_evidence_files = re.findall(r'evidenceFile:\s*"([^"]+)"', route_source)
    if len(route_evidence_files) != 6:
        return fail(f"expected 6 route evidence files, got {len(route_evidence_files)}: {route_evidence_files}")

    missing_route_evidence = [path for path in route_evidence_files if path not in preflight_source]
    if missing_route_evidence:
        return fail(f"preflight scaffold missing route evidence files: {missing_route_evidence}")

    if '"$EVIDENCE_DIR/diagnostics"' not in preflight_source:
        return fail("preflight scaffold should create diagnostics evidence directory")
    for diagnostics_copy in [
        "Documents/diagnostics/digital_human_readiness.txt",
        "Documents/diagnostics/digital_human_readiness.json",
    ]:
        if diagnostics_copy not in preflight_source:
            return fail(f"preflight should copy app-persisted diagnostics evidence: {diagnostics_copy}")
    if "Documents/diagnostics/digital_human_playback.log" not in preflight_source:
        return fail("preflight should copy app-persisted digital-human playback log when present")

    playback_tokens = [
        "playback_finished source=native_audio",
        "playback_finished source=system_tts",
        "playback_finished source=timeout",
    ]
    missing_playback_tokens = [token for token in playback_tokens if token not in preflight_source]
    if missing_playback_tokens:
        return fail(f"preflight scaffold missing digital-human playback acceptance logs: {missing_playback_tokens}")

    console_capture_tokens = [
        "console_capture_next_steps.txt",
        "grep -E 'DigitalHumanSpeech|wav_synth_success|fallback=systemTTS|playback_timeout",
        '"$EVIDENCE_DIR/app_console_sample.log"',
        '> "$EVIDENCE_DIR/diagnostics/digital_human_playback.log"',
    ]
    missing_console_capture_tokens = [
        token for token in console_capture_tokens if token not in preflight_source
    ]
    if missing_console_capture_tokens:
        return fail(
            "preflight console capture next steps should explain playback log extraction: "
            f"{missing_console_capture_tokens}"
        )

    privacy_check_tokens = [
        "Screenshots must be real PNG files",
        "roadshow recording must be a real MP4 file",
        "screenshot/recording files are not valid PNG/MP4",
        "archive_inventory.json",
        "sizeBytes and sha256",
        "sourceUserId",
        "sourceNickname",
        "exportDate",
        "graphJSON",
        "people",
        "places",
        "events",
        "facts",
        "Scripts/roadshow_share_package_privacy_check.py",
        "--write-log",
        "PASS share package privacy check",
        "checked: share_packages/all_family.json",
        "checked: share_packages/selected_member.json",
        "no PRIVATE_/LOCAL_/GENERATION_ markers",
        "no RAW_TRANSCRIPT/FULL_TRANSCRIPT/FULL_LETTER content",
        "no UNAUTHORIZED_ member content",
        "share package graphJSON is missing/unparseable",
        "privacy_check.log lacks an explicit PASS privacy sample result",
    ]
    missing_privacy_check_tokens = [
        token for token in privacy_check_tokens if token not in preflight_source
    ]
    if missing_privacy_check_tokens:
        return fail(
            "preflight should document share package privacy check acceptance tokens: "
            f"{missing_privacy_check_tokens}"
        )

    phase2_tokens = [
        "RoadshowDeviceSmokePreflight",
        "Scripts/RoadshowDeviceSmokePreflightVerify/main.py",
    ]
    missing_phase2_tokens = [
        token for token in phase2_tokens if token not in verify_phase2_source
    ]
    if missing_phase2_tokens:
        return fail(f"phase2 verification should include preflight dry-run verifier: {missing_phase2_tokens}")

    print("RoadshowEvidenceScaffold verification passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
