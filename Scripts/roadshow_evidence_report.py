#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path


SCAFFOLD_FILES = [
    "evidence_manifest.json",
    "expected_screens.txt",
    "expected_state_keys.txt",
    "route_screen_checklist.md",
    "route_completion/route_acceptance_checklist.md",
    "archive_package_next_steps.txt",
]

AUTOMATIC_CONTEXT_FILES = [
    "xctrace_devices.txt",
    "physical_ios_devices.txt",
    "build_settings.txt",
    "bundle_identifier.txt",
    "iphoneos_build_gate.log",
    "iphoneos_build_gate.command",
    "iphoneos_build_gate.exit_code",
]

STAGE_EXTRA_ARTIFACTS = {
    "home": ["recordings/roadshow_6min_run.mp4"],
    "route": [
        "route_completion/route_completion_preferences.txt",
        "route_completion/route_acceptance_checklist.md",
    ],
    "voice_companion": [
        "diagnostics/digital_human_readiness.txt",
        "diagnostics/digital_human_readiness.json",
        "diagnostics/digital_human_playback.log",
        "app_console_sample.log",
    ],
    "family_share": [
        "share_packages/all_family.json",
        "share_packages/selected_member.json",
        "share_packages/privacy_check.log",
    ],
}

PRIVACY_SCAN_EXTENSIONS = {".command", ".json", ".log", ".md", ".txt"}
PRIVACY_SCAN_MAX_BYTES = 2 * 1024 * 1024
SECRET_PATTERNS = [
    (
        "credential-assignment",
        re.compile(
            r"\b(api[_-]?key|x-api-key|token|access[_-]?token|secret|secret[_-]?key|"
            r"app[_-]?key|app[_-]?token|volcengine[_-]?api[_-]?key)\b"
            r"\s*[:=]\s*[\"']?[A-Za-z0-9._\-]{12,}",
            re.IGNORECASE,
        ),
    ),
    (
        "secret-key-token",
        re.compile(r"\bsk-[A-Za-z0-9_\-]{16,}\b"),
    ),
    (
        "authorization-bearer-token",
        re.compile(r"\bBearer\s+[A-Za-z0-9._\-]{12,}\b", re.IGNORECASE),
    ),
]

PLAYBACK_LOG_PATH = "diagnostics/digital_human_playback.log"
DIGITAL_HUMAN_READINESS_JSON_PATH = "diagnostics/digital_human_readiness.json"
ROUTE_COMPLETION_PREFERENCES_PATH = "route_completion/route_completion_preferences.txt"
ROUTE_ACCEPTANCE_CHECKLIST_PATH = "route_completion/route_acceptance_checklist.md"
SHARE_PACKAGE_PRIVACY_CHECK_PATH = "share_packages/privacy_check.log"
ROUTE_COMPLETION_KEYS = [
    "dreamjourney.roadshow.route.completed.voice_companion",
    "dreamjourney.roadshow.route.completed.time_mailbox",
    "dreamjourney.roadshow.route.completed.memory_archive",
    "dreamjourney.roadshow.route.completed.family_footprint",
    "dreamjourney.roadshow.route.completed.care_dashboard",
    "dreamjourney.roadshow.route.completed.family_share",
]
ROUTE_ACCEPTANCE_EVIDENCE_FILES = [
    "screens/03_memory_voice_digital_human.png",
    "screens/04_time_mailbox_delivered_letter.png",
    "screens/05_memory_archive_photo_analysis.png",
    "screens/06_family_footprint_world_generation.png",
    "screens/07_family_care_dashboard_member.png",
    "screens/08_share_package_export_sheet.png",
]
PLAYBACK_ACCEPTANCE_CHAINS = [
    (
        "native_audio",
        ["wav_synth_success", "playback_finished source=native_audio"],
    ),
    (
        "system_tts",
        ["fallback=systemTTS", "playback_finished source=system_tts"],
    ),
    (
        "timeout",
        ["playback_timeout", "playback_finished source=timeout"],
    ),
]
SHARE_PACKAGE_JSON_PATHS = {
    "share_packages/all_family.json",
    "share_packages/selected_member.json",
}
SHARE_PACKAGE_REQUIRED_FIELDS = [
    "sourceUserId",
    "sourceNickname",
    "exportDate",
    "graphJSON",
]
SHARE_PACKAGE_GRAPH_REQUIRED_FIELDS = [
    "people",
    "places",
    "events",
    "facts",
]
SHARE_PACKAGE_FORBIDDEN_MARKERS = [
    "PRIVATE_",
    "LOCAL_",
    "GENERATION_",
    "RAW_TRANSCRIPT",
    "FULL_TRANSCRIPT",
    "FULL_LETTER",
    "UNAUTHORIZED_",
]
SHARE_PACKAGE_PRIVACY_CHECK_TOKENS = [
    "pass",
    "share_packages/all_family.json",
    "share_packages/selected_member.json",
    "no private_",
    "no raw_transcript",
    "no unauthorized_",
]
ARCHIVE_PACKAGE_NAME = "dreamjourney_roadshow_evidence.zip"
ARCHIVE_INVENTORY_NAME = "archive_inventory.json"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def action_for(item: dict) -> dict:
    path = item["path"]
    category = item["category"]
    title = path
    priority = 90
    action = f"Add `{path}` to the evidence directory."

    if category in {"scaffold", "automatic_context"}:
        priority = 10
        title = "rerun preflight"
        action = "Rerun `Scripts/roadshow_device_smoke_preflight.sh` so device/build context and scaffold files are regenerated."
    elif path == "diagnostics/digital_human_playback.log":
        priority = 25
        title = "capture digital-human playback log"
        action = (
            "Exercise digital-human playback so the app writes `Documents/diagnostics/digital_human_playback.log`; "
            "rerun preflight to copy it into `diagnostics/digital_human_playback.log`. If the automatic file is missing, "
            "capture DigitalHumanSpeech console lines covering native_audio, system_tts, and timeout closure, then run "
            "`python3 Scripts/roadshow_digital_human_playback_audit.py <evidence-dir> --json`."
        )
    elif path.startswith("diagnostics/"):
        priority = 20
        title = "sync digital-human diagnostics"
        action = (
            "Launch the app so it writes digital-human diagnostics to `Documents/diagnostics/`, then rerun "
            "`Scripts/roadshow_device_smoke_preflight.sh` to copy them under `diagnostics/`; use the in-app diagnostics copy buttons only as fallback."
        )
    elif category == "route_screen":
        priority = 30
        title = "capture route screenshot"
        action = f"Run the route step and save its screenshot as `{path}`."
    elif path.startswith("recordings/"):
        priority = 40
        title = "record roadshow run"
        action = f"Record the six-stage roadshow flow and save it as `{path}`."
    elif path.startswith("share_packages/") and path.endswith(".json"):
        priority = 50
        title = "export share package"
        action = f"Export the matching all-family or selected-member package and save it as `{path}`."
    elif path.endswith("privacy_check.log"):
        priority = 60
        title = "write privacy check log"
        action = (
            "Run `python3 Scripts/roadshow_share_package_privacy_check.py <evidence-dir> "
            "--write-log <evidence-dir>/share_packages/privacy_check.log` after exporting both share packages."
        )
    elif path.endswith("app_console_sample.log"):
        priority = 70
        title = "capture app console"
        action = "Capture console lines for RoadshowDemo, DigitalHumanSpeech, fallback, and safety guard into `app_console_sample.log`."
    elif path.startswith("route_completion/"):
        priority = 80
        title = "copy route acceptance"
        action = "Paste the in-app route acceptance output into the route completion file."

    return {
        "priority": priority,
        "category": category,
        "path": path,
        "title": title,
        "action": action,
    }


def next_actions(missing: list[dict]) -> list[dict]:
    actions = [action_for(item) for item in missing]
    return sorted(actions, key=lambda item: (item["priority"], item["path"]))


def privacy_action_for(finding: dict) -> dict:
    path = finding["path"]
    return {
        "priority": 5,
        "category": "privacy",
        "path": path,
        "title": "redact evidence secret",
        "action": f"Remove or redact `{finding['pattern']}` at `{path}` line {finding['line']} before sharing the roadshow package.",
    }


def quality_action_for(finding: dict) -> dict:
    path = finding["path"]
    if path == ROUTE_COMPLETION_PREFERENCES_PATH:
        return {
            "priority": 35,
            "category": "quality",
            "path": path,
            "title": "complete roadshow route checklist",
            "action": f"Open the in-app roadshow route, complete all six stages, rerun preflight, and refresh `{path}`.",
        }

    if path == ROUTE_ACCEPTANCE_CHECKLIST_PATH:
        return {
            "priority": 36,
            "category": "quality",
            "path": path,
            "title": "paste route acceptance checklist",
            "action": f"Copy the in-app roadshow acceptance checklist after all six stages and paste it into `{path}`.",
        }

    if path == SHARE_PACKAGE_PRIVACY_CHECK_PATH:
        return {
            "priority": 44,
            "category": "quality",
            "path": path,
            "title": "complete share package privacy check",
            "action": (
                "Regenerate the PASS privacy check with "
                "`python3 Scripts/roadshow_share_package_privacy_check.py <evidence-dir> "
                f"--write-log <evidence-dir>/{path}` after exporting both all-family and selected-member JSON."
            ),
        }

    if path.startswith("screens/"):
        return {
            "priority": 32,
            "category": "quality",
            "path": path,
            "title": "recapture route screenshot",
            "action": f"Replace `{path}` with an actual PNG screenshot captured from the roadshow device.",
        }

    if path == DIGITAL_HUMAN_READINESS_JSON_PATH:
        return {
            "priority": 21,
            "category": "quality",
            "path": path,
            "title": "refresh digital-human diagnostics JSON",
            "action": (
                "Launch the app or open the in-app digital-human diagnostics sheet so it rewrites "
                f"`Documents/{DIGITAL_HUMAN_READINESS_JSON_PATH}`, then rerun preflight to copy a valid "
                "readiness payload with playbackEvidenceChecks and redaction policy into the evidence directory."
            ),
        }

    if path.startswith("recordings/"):
        return {
            "priority": 42,
            "category": "quality",
            "path": path,
            "title": "recapture roadshow recording",
            "action": f"Replace `{path}` with an actual MP4 recording of the roadshow run.",
        }

    if path.startswith("share_packages/"):
        return {
            "priority": 45,
            "category": "quality",
            "path": path,
            "title": "regenerate sanitized share package",
            "action": f"Re-export `{path}` from the in-app share package flow and confirm it is valid JSON without private/local/generation or unauthorized-member content.",
        }

    return {
        "priority": 24,
        "category": "quality",
        "path": path,
        "title": "recapture playback evidence",
        "action": (
            f"Regenerate `{path}` with at least one accepted playback closure chain, then run "
            "`python3 Scripts/roadshow_digital_human_playback_audit.py <evidence-dir> --json` for strict rehearsal."
        ),
    }


def should_scan(item: dict) -> bool:
    if not item["present"]:
        return False
    return Path(item["path"]).suffix.lower() in PRIVACY_SCAN_EXTENSIONS


def scan_quality_findings(evidence_dir: Path, items: list[dict]) -> list[dict]:
    findings = []
    item_by_path = {item["path"]: item for item in items}

    for item in items:
        relative_path = item["path"]
        if not item["present"]:
            continue
        if item["category"] == "route_screen" and relative_path.endswith(".png"):
            try:
                signature = (evidence_dir / relative_path).read_bytes()[: len(PNG_SIGNATURE)]
            except OSError:
                signature = b""
            if signature != PNG_SIGNATURE:
                findings.append(
                    {
                        "category": "quality",
                        "path": relative_path,
                        "check": "route-screenshot-invalid-png",
                        "recommendation": "Recapture this route screenshot as a real PNG file.",
                    }
                )
        elif relative_path.startswith("recordings/") and relative_path.endswith(".mp4"):
            try:
                header = (evidence_dir / relative_path).read_bytes()[:16]
            except OSError:
                header = b""
            if len(header) < 12 or header[4:8] != b"ftyp":
                findings.append(
                    {
                        "category": "quality",
                        "path": relative_path,
                        "check": "recording-invalid-mp4",
                        "recommendation": "Recapture this roadshow recording as a real MP4 file.",
                    }
                )

    route_completion_item = item_by_path.get(ROUTE_COMPLETION_PREFERENCES_PATH)
    if route_completion_item and route_completion_item["present"]:
        route_completion_path = evidence_dir / ROUTE_COMPLETION_PREFERENCES_PATH
        try:
            content = route_completion_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            findings.append(
                {
                    "category": "quality",
                    "path": ROUTE_COMPLETION_PREFERENCES_PATH,
                    "check": "route-completion-unreadable",
                    "recommendation": "Regenerate route completion preferences as UTF-8 text.",
                }
            )
        else:
            values: dict[str, str] = {}
            for line in content.splitlines():
                if "=" not in line:
                    continue
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip().lower()

            incomplete_keys = [
                key
                for key in ROUTE_COMPLETION_KEYS
                if values.get(key) not in {"true", "1", "yes"}
            ]
            if incomplete_keys:
                findings.append(
                    {
                        "category": "quality",
                        "path": ROUTE_COMPLETION_PREFERENCES_PATH,
                        "check": "route-completion-incomplete",
                        "recommendation": (
                            "Complete every in-app roadshow route step before archiving evidence. "
                            f"Missing or false keys: {', '.join(incomplete_keys)}."
                        ),
                    }
                )

    route_acceptance_item = item_by_path.get(ROUTE_ACCEPTANCE_CHECKLIST_PATH)
    if route_acceptance_item and route_acceptance_item["present"]:
        route_acceptance_path = evidence_dir / ROUTE_ACCEPTANCE_CHECKLIST_PATH
        try:
            content = route_acceptance_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            findings.append(
                {
                    "category": "quality",
                    "path": ROUTE_ACCEPTANCE_CHECKLIST_PATH,
                    "check": "route-acceptance-unreadable",
                    "recommendation": "Paste the route acceptance checklist as UTF-8 text.",
                }
            )
        else:
            missing_tokens = [
                token
                for token in ["路演验收进度 6/6", "边界声明"] + ROUTE_ACCEPTANCE_EVIDENCE_FILES
                if token not in content
            ]
            checked_count = content.count("[x]")
            if "<paste in-app checklist here>" in content or "Paste copied checklist below" in content:
                findings.append(
                    {
                        "category": "quality",
                        "path": ROUTE_ACCEPTANCE_CHECKLIST_PATH,
                        "check": "route-acceptance-placeholder",
                        "recommendation": "Replace the template placeholder with the in-app copied acceptance checklist.",
                    }
                )
            elif missing_tokens or checked_count < 6:
                findings.append(
                    {
                        "category": "quality",
                        "path": ROUTE_ACCEPTANCE_CHECKLIST_PATH,
                        "check": "route-acceptance-incomplete",
                        "recommendation": (
                            "Paste the completed 6/6 in-app route acceptance checklist with all six evidence file names."
                        ),
                    }
                )

    playback_item = item_by_path.get(PLAYBACK_LOG_PATH)
    if playback_item and playback_item["present"]:
        playback_path = evidence_dir / PLAYBACK_LOG_PATH
        try:
            content = playback_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            findings.append(
                {
                    "category": "quality",
                    "path": PLAYBACK_LOG_PATH,
                    "check": "playback-log-unreadable",
                    "recommendation": "Save the playback log as UTF-8 text before archiving evidence.",
                }
            )
        else:
            accepted_sources = [
                source
                for source, tokens in PLAYBACK_ACCEPTANCE_CHAINS
                if all(token in content for token in tokens)
            ]
            if not accepted_sources:
                findings.append(
                    {
                        "category": "quality",
                        "path": PLAYBACK_LOG_PATH,
                        "check": "playback-log-missing-accepted-chain",
                        "recommendation": (
                            "Capture at least one complete playback closure chain: "
                            "wav_synth_success -> playback_finished source=native_audio, "
                            "fallback=systemTTS -> playback_finished source=system_tts, or "
                            "playback_timeout -> playback_finished source=timeout."
                        ),
                    }
                )

    readiness_item = item_by_path.get(DIGITAL_HUMAN_READINESS_JSON_PATH)
    if readiness_item and readiness_item["present"]:
        readiness_path = evidence_dir / DIGITAL_HUMAN_READINESS_JSON_PATH
        try:
            content = readiness_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            findings.append(
                {
                    "category": "quality",
                    "path": DIGITAL_HUMAN_READINESS_JSON_PATH,
                    "check": "digital-human-readiness-unreadable",
                    "recommendation": "Save the digital-human readiness JSON as UTF-8 text.",
                }
            )
        else:
            try:
                readiness = json.loads(content)
            except json.JSONDecodeError:
                findings.append(
                    {
                        "category": "quality",
                        "path": DIGITAL_HUMAN_READINESS_JSON_PATH,
                        "check": "digital-human-readiness-invalid-json",
                        "recommendation": "Copy the in-app digital-human diagnostics JSON again; evidence must parse as JSON.",
                    }
                )
            else:
                missing_fields = []
                if not isinstance(readiness, dict):
                    missing_fields = ["items", "playbackEvidenceChecks", "redaction"]
                else:
                    if not isinstance(readiness.get("items"), list) or not readiness.get("items"):
                        missing_fields.append("items")
                    if (
                        not isinstance(readiness.get("playbackEvidenceChecks"), list)
                        or not readiness.get("playbackEvidenceChecks")
                    ):
                        missing_fields.append("playbackEvidenceChecks")
                    if not isinstance(readiness.get("redaction"), str) or "No API Key" not in readiness.get("redaction", ""):
                        missing_fields.append("redaction")
                if missing_fields:
                    findings.append(
                        {
                            "category": "quality",
                            "path": DIGITAL_HUMAN_READINESS_JSON_PATH,
                            "check": "digital-human-readiness-incomplete",
                            "recommendation": (
                                "Copy the complete diagnostics JSON, including items, playbackEvidenceChecks, "
                                f"and redaction policy. Missing or invalid fields: {', '.join(missing_fields)}."
                            ),
                        }
                    )

    privacy_check_item = item_by_path.get(SHARE_PACKAGE_PRIVACY_CHECK_PATH)
    if privacy_check_item and privacy_check_item["present"]:
        privacy_check_path = evidence_dir / SHARE_PACKAGE_PRIVACY_CHECK_PATH
        try:
            content = privacy_check_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            findings.append(
                {
                    "category": "quality",
                    "path": SHARE_PACKAGE_PRIVACY_CHECK_PATH,
                    "check": "share-package-privacy-check-unreadable",
                    "recommendation": "Save the share package privacy check as UTF-8 text.",
                }
            )
        else:
            normalized = content.lower()
            missing_tokens = [
                token for token in SHARE_PACKAGE_PRIVACY_CHECK_TOKENS
                if token not in normalized
            ]
            if missing_tokens:
                findings.append(
                    {
                        "category": "quality",
                        "path": SHARE_PACKAGE_PRIVACY_CHECK_PATH,
                        "check": "share-package-privacy-check-incomplete",
                        "recommendation": (
                            "Record a PASS privacy check that names both exported JSON files and states no "
                            "PRIVATE_/LOCAL_, RAW_TRANSCRIPT/FULL_TRANSCRIPT/FULL_LETTER, or UNAUTHORIZED_ "
                            f"content was found. Missing tokens: {', '.join(missing_tokens)}."
                        ),
                    }
                )

    for relative_path in sorted(SHARE_PACKAGE_JSON_PATHS):
        item = item_by_path.get(relative_path)
        if not item or not item["present"]:
            continue

        package_path = evidence_dir / relative_path
        try:
            content = package_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            findings.append(
                {
                    "category": "quality",
                    "path": relative_path,
                    "check": "share-package-unreadable",
                    "recommendation": "Re-export this share package as UTF-8 JSON.",
                }
            )
            continue

        try:
            package = json.loads(content)
        except json.JSONDecodeError:
            findings.append(
                {
                    "category": "quality",
                    "path": relative_path,
                    "check": "share-package-invalid-json",
                    "recommendation": "Re-export this share package; evidence must be parseable JSON.",
                }
            )
            continue

        for marker in SHARE_PACKAGE_FORBIDDEN_MARKERS:
            if marker in content:
                findings.append(
                    {
                        "category": "quality",
                        "path": relative_path,
                        "check": f"share-package-forbidden-marker:{marker}",
                        "recommendation": "Re-export via the sanitized share package flow before archiving evidence.",
                    }
                )
                break
        else:
            if not isinstance(package, dict):
                missing_fields = SHARE_PACKAGE_REQUIRED_FIELDS
            else:
                missing_fields = [
                    field
                    for field in SHARE_PACKAGE_REQUIRED_FIELDS
                    if not isinstance(package.get(field), str) or not package.get(field, "").strip()
                ]
            if missing_fields:
                findings.append(
                    {
                        "category": "quality",
                        "path": relative_path,
                        "check": "share-package-invalid-schema",
                        "recommendation": (
                            "Re-export this share package; evidence must include sourceUserId, "
                            "sourceNickname, exportDate, and graphJSON. "
                            f"Missing or empty fields: {', '.join(missing_fields)}."
                        ),
                    }
                )
                continue

            try:
                graph = json.loads(package["graphJSON"])
            except json.JSONDecodeError:
                findings.append(
                    {
                        "category": "quality",
                        "path": relative_path,
                        "check": "share-package-invalid-graph-json",
                        "recommendation": "Re-export this share package; graphJSON must be parseable JSON.",
                    }
                )
                continue

            if not isinstance(graph, dict):
                missing_graph_fields = SHARE_PACKAGE_GRAPH_REQUIRED_FIELDS
            else:
                missing_graph_fields = [
                    field
                    for field in SHARE_PACKAGE_GRAPH_REQUIRED_FIELDS
                    if not isinstance(graph.get(field), list)
                ]
            if missing_graph_fields:
                findings.append(
                    {
                        "category": "quality",
                        "path": relative_path,
                        "check": "share-package-invalid-graph-schema",
                        "recommendation": (
                            "Re-export this share package; graphJSON must include people, places, "
                            f"events, and facts arrays. Missing or invalid fields: {', '.join(missing_graph_fields)}."
                        ),
                    }
                )

    return findings


def scan_privacy_findings(evidence_dir: Path, items: list[dict]) -> list[dict]:
    findings = []
    for item in items:
        if not should_scan(item):
            continue

        relative_path = item["path"]
        path = evidence_dir / relative_path
        if not path.is_file():
            continue
        if path.stat().st_size > PRIVACY_SCAN_MAX_BYTES:
            findings.append(
                {
                    "category": "privacy",
                    "path": relative_path,
                    "line": 0,
                    "pattern": "scan-skipped-large-file",
                    "recommendation": "Review this large text evidence file manually before sharing.",
                }
            )
            continue

        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        for line_number, line in enumerate(content.splitlines(), start=1):
            for pattern_name, pattern in SECRET_PATTERNS:
                if pattern.search(line):
                    findings.append(
                        {
                            "category": "privacy",
                            "path": relative_path,
                            "line": line_number,
                            "pattern": pattern_name,
                            "recommendation": "Remove or redact this value before sharing evidence.",
                        }
                    )
                    break
    return findings


def load_manifest(evidence_dir: Path) -> dict:
    manifest_path = evidence_dir / "evidence_manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"missing manifest: {manifest_path}")
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def is_present(path: Path) -> bool:
    return path.exists() and (path.is_dir() or path.stat().st_size > 0)


def inspect_group(evidence_dir: Path, category: str, paths: list[str]) -> list[dict]:
    rows = []
    for relative_path in paths:
        path = evidence_dir / relative_path
        present = is_present(path)
        rows.append(
            {
                "category": category,
                "path": relative_path,
                "present": present,
                "sizeBytes": path.stat().st_size if path.exists() and path.is_file() else 0,
            }
        )
    return rows


def make_stage_group(group_id: str, title: str, paths: list[str], item_by_path: dict[str, dict]) -> dict:
    artifacts = [item_by_path[path] for path in paths if path in item_by_path]
    present_count = sum(1 for item in artifacts if item["present"])
    missing = [item for item in artifacts if not item["present"]]
    return {
        "id": group_id,
        "title": title,
        "total": len(artifacts),
        "present": present_count,
        "missing": len(missing),
        "status": "complete" if artifacts and not missing else "missing",
        "missingPaths": [item["path"] for item in missing],
        "artifacts": artifacts,
    }


def make_stage_groups(manifest: dict, items: list[dict]) -> list[dict]:
    item_by_path = {item["path"]: item for item in items}
    covered_paths: set[str] = set()
    groups = []

    preflight_paths = SCAFFOLD_FILES + AUTOMATIC_CONTEXT_FILES
    groups.append(make_stage_group("preflight", "自动上下文与脚手架", preflight_paths, item_by_path))
    covered_paths.update(path for path in preflight_paths if path in item_by_path)

    for route_screen in manifest.get("routeScreens", []):
        group_id = route_screen.get("id", route_screen.get("title", "route_screen"))
        title = route_screen.get("title", group_id)
        paths = [route_screen.get("evidenceFile", "")]
        paths.extend(STAGE_EXTRA_ARTIFACTS.get(group_id, []))
        groups.append(make_stage_group(group_id, title, paths, item_by_path))
        covered_paths.update(path for path in paths if path in item_by_path)

    remaining_paths = [
        item["path"]
        for item in items
        if item["path"] not in covered_paths and item["category"] == "additional_artifact"
    ]
    if remaining_paths:
        groups.append(make_stage_group("supporting_artifacts", "补充证据", remaining_paths, item_by_path))

    return groups


def make_readiness_summary(status: str, items: list[dict], actions: list[dict], privacy_findings: list[dict], quality_findings: list[dict]) -> dict:
    total = len(items)
    present = sum(1 for item in items if item["present"])
    completion_percent = int(round((present / total) * 100)) if total else 0
    blockers = []

    if status == "needs_preflight":
        blockers.append("preflight")
    if status == "needs_privacy_review" or privacy_findings:
        blockers.append("privacy")
    if status == "needs_manual_evidence" or quality_findings:
        blockers.append("manual_evidence")

    next_action = actions[0] if actions else None
    return {
        "completionPercent": completion_percent,
        "canArchive": status == "complete" and not privacy_findings and not quality_findings,
        "blockers": blockers,
        "nextAction": next_action,
    }


def make_archive_plan(status: str, items: list[dict], privacy_findings: list[dict], quality_findings: list[dict]) -> dict:
    included_paths = [
        item["path"]
        for item in items
        if item["present"]
    ]
    for generated_path in ["evidence_status.json", "evidence_status.md", ARCHIVE_INVENTORY_NAME]:
        if generated_path not in included_paths:
            included_paths.append(generated_path)

    blockers = []
    if status != "complete":
        blockers.append(status)
    if privacy_findings:
        blockers.append("privacy")
    if quality_findings:
        blockers.append("quality")

    return {
        "ready": status == "complete" and not privacy_findings and not quality_findings,
        "packageName": ARCHIVE_PACKAGE_NAME,
        "includedPaths": included_paths,
        "blockers": blockers,
        "command": "python3 Scripts/roadshow_evidence_report.py <evidence-dir> --write --archive --fail-on-missing",
    }


def make_report(evidence_dir: Path) -> dict:
    manifest = load_manifest(evidence_dir)
    route_screens = [item["evidenceFile"] for item in manifest.get("routeScreens", [])]
    additional_artifacts = manifest.get("additionalArtifacts", [])

    items = []
    items.extend(inspect_group(evidence_dir, "scaffold", SCAFFOLD_FILES))
    items.extend(inspect_group(evidence_dir, "automatic_context", AUTOMATIC_CONTEXT_FILES))
    items.extend(inspect_group(evidence_dir, "route_screen", route_screens))
    items.extend(inspect_group(evidence_dir, "additional_artifact", additional_artifacts))
    stage_groups = make_stage_groups(manifest, items)

    missing = [item for item in items if not item["present"]]
    present = [item for item in items if item["present"]]
    privacy_findings = scan_privacy_findings(evidence_dir, items)
    quality_findings = scan_quality_findings(evidence_dir, items)

    route_missing = [item for item in missing if item["category"] == "route_screen"]
    additional_missing = [item for item in missing if item["category"] == "additional_artifact"]
    automatic_missing = [item for item in missing if item["category"] == "automatic_context"]
    scaffold_missing = [item for item in missing if item["category"] == "scaffold"]

    if scaffold_missing or automatic_missing:
        status = "needs_preflight"
    elif privacy_findings:
        status = "needs_privacy_review"
    elif route_missing or additional_missing or quality_findings:
        status = "needs_manual_evidence"
    else:
        status = "complete"

    actions = sorted(
        [privacy_action_for(finding) for finding in privacy_findings]
        + [quality_action_for(finding) for finding in quality_findings]
        + next_actions(missing),
        key=lambda item: (item["priority"], item["path"]),
    )

    readiness_summary = make_readiness_summary(status, items, actions, privacy_findings, quality_findings)
    archive_plan = make_archive_plan(status, items, privacy_findings, quality_findings)

    return {
        "app": manifest.get("app", "DreamJourney"),
        "mode": manifest.get("mode", "roadshow_device_smoke"),
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "evidenceDir": str(evidence_dir),
        "status": status,
        "readiness": readiness_summary,
        "archivePlan": archive_plan,
        "summary": {
            "total": len(items),
            "present": len(present),
            "missing": len(missing),
            "routeScreensMissing": len(route_missing),
            "additionalArtifactsMissing": len(additional_missing),
            "automaticContextMissing": len(automatic_missing),
            "scaffoldMissing": len(scaffold_missing),
            "privacyFindings": len(privacy_findings),
            "qualityFindings": len(quality_findings),
            "stageGroupsIncomplete": sum(1 for group in stage_groups if group["missing"] > 0),
        },
        "items": items,
        "missing": missing,
        "privacyFindings": privacy_findings,
        "qualityFindings": quality_findings,
        "stageGroups": stage_groups,
        "nextActions": actions,
    }


def render_markdown(report: dict) -> str:
    summary = report["summary"]
    lines = [
        "# DreamJourney Roadshow Evidence Status",
        "",
        f"- Evidence dir: `{report['evidenceDir']}`",
        f"- Status: `{report['status']}`",
        f"- Roadshow archive-ready: `{str(report['readiness']['canArchive']).lower()}`",
        f"- Completion: {report['readiness']['completionPercent']}%",
        f"- Present: {summary['present']}/{summary['total']}",
        f"- Missing route screenshots: {summary['routeScreensMissing']}",
        f"- Missing additional artifacts: {summary['additionalArtifactsMissing']}",
        f"- Missing automatic context: {summary['automaticContextMissing']}",
        f"- Privacy findings: {summary['privacyFindings']}",
        f"- Quality findings: {summary.get('qualityFindings', 0)}",
        f"- Incomplete stage groups: {summary['stageGroupsIncomplete']}",
        "",
    ]

    readiness = report.get("readiness", {})
    next_action = readiness.get("nextAction")
    if next_action:
        lines.extend(
            [
                "## Roadshow Readiness",
                "",
                f"- Can archive/share evidence: `{str(readiness.get('canArchive', False)).lower()}`",
                f"- Blockers: `{', '.join(readiness.get('blockers', [])) or 'none'}`",
                f"- First action: {next_action['action']}",
                f"- Evidence: `{next_action['path']}`",
                "",
            ]
        )
    else:
        lines.extend(
            [
                "## Roadshow Readiness",
                "",
                "- Can archive/share evidence: `true`",
                "- Blockers: `none`",
                "- First action: None.",
                "",
            ]
        )

    missing = report["missing"]
    next_actions_rows = report.get("nextActions", [])
    if next_actions_rows:
        lines.extend(["## Next Actions", "", "| Priority | Action | Evidence |", "| ---: | --- | --- |"])
        lines.extend(
            f"| {item['priority']} | {item['action']} | `{item['path']}` |"
            for item in next_actions_rows
        )
        lines.append("")

    if missing:
        lines.extend(["## Missing Items", "", "| Category | Path |", "| --- | --- |"])
        lines.extend(f"| {item['category']} | `{item['path']}` |" for item in missing)
        lines.append("")
    else:
        lines.extend(["## Missing Items", "", "None.", ""])

    stage_groups = report.get("stageGroups", [])
    if stage_groups:
        lines.extend(["## Stage Evidence", "", "| Stage | Present | Missing | Key Missing |", "| --- | ---: | ---: | --- |"])
        for group in stage_groups:
            key_missing = ", ".join(f"`{path}`" for path in group["missingPaths"][:3])
            if group["missing"] > 3:
                key_missing += f", +{group['missing'] - 3} more"
            if not key_missing:
                key_missing = "None"
            lines.append(
                f"| {group['title']} | {group['present']}/{group['total']} | {group['missing']} | {key_missing} |"
            )
        lines.append("")

    privacy_findings = report.get("privacyFindings", [])
    if privacy_findings:
        lines.extend(["## Privacy Review", "", "| Path | Line | Pattern | Action |", "| --- | ---: | --- | --- |"])
        lines.extend(
            f"| `{item['path']}` | {item['line']} | `{item['pattern']}` | {item['recommendation']} |"
            for item in privacy_findings
        )
        lines.append("")
    else:
        lines.extend(["## Privacy Review", "", "No token-shaped evidence values found.", ""])

    quality_findings = report.get("qualityFindings", [])
    if quality_findings:
        lines.extend(["## Quality Review", "", "| Path | Check | Action |", "| --- | --- | --- |"])
        lines.extend(
            f"| `{item['path']}` | `{item['check']}` | {item['recommendation']} |"
            for item in quality_findings
        )
        lines.append("")
    else:
        lines.extend(["## Quality Review", "", "No content quality blockers found.", ""])

    archive_plan = report.get("archivePlan", {})
    archive_ready = str(archive_plan.get("ready", False)).lower()
    lines.extend(
        [
            "## Archive Package",
            "",
            f"- Ready: `{archive_ready}`",
            f"- Package: `{archive_plan.get('packageName', ARCHIVE_PACKAGE_NAME)}`",
            f"- Command: `{archive_plan.get('command', '')}`",
        ]
    )
    blockers = archive_plan.get("blockers", [])
    if blockers:
        lines.append(f"- Blockers: `{', '.join(blockers)}`")
    else:
        lines.append("- Blockers: `none`")
    lines.append("")

    lines.extend(["## Present Items", "", "| Category | Path | Size |", "| --- | --- | ---: |"])
    for item in report["items"]:
        if item["present"]:
            lines.append(f"| {item['category']} | `{item['path']}` | {item['sizeBytes']} |")
    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Inspect a DreamJourney roadshow evidence directory.")
    parser.add_argument("evidence_dir", type=Path)
    parser.add_argument("--write", action="store_true", help="write evidence_status.json and evidence_status.md")
    parser.add_argument("--archive", action="store_true", help="create a zip archive when evidence is complete and clean")
    parser.add_argument("--fail-on-missing", action="store_true", help="exit 1 when any expected item is missing")
    parser.add_argument("--quiet", action="store_true", help="only print the status line")
    return parser.parse_args()


def write_archive(evidence_dir: Path, report: dict) -> Path:
    archive_plan = report.get("archivePlan", {})
    if not archive_plan.get("ready", False):
        raise RuntimeError("evidence is not archive-ready")

    archive_path = evidence_dir / archive_plan.get("packageName", ARCHIVE_PACKAGE_NAME)
    if archive_path.exists():
        archive_path.unlink()

    archive_entries: list[tuple[str, bytes]] = []
    for relative_path in archive_plan.get("includedPaths", []):
        if relative_path == ARCHIVE_INVENTORY_NAME:
            continue
        source = evidence_dir / relative_path
        if source == archive_path or not source.exists():
            continue
        if source.is_dir():
            for child in source.rglob("*"):
                if child.is_file():
                    archive_entries.append((child.relative_to(evidence_dir).as_posix(), child.read_bytes()))
        elif source.is_file():
            archive_entries.append((relative_path, source.read_bytes()))

    inventory = {
        "packageName": archive_plan.get("packageName", ARCHIVE_PACKAGE_NAME),
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "evidenceStatus": report.get("status", "unknown"),
        "files": [
            {
                "path": relative_path,
                "sizeBytes": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
            }
            for relative_path, payload in sorted(archive_entries, key=lambda item: item[0])
        ],
    }
    inventory_payload = json.dumps(inventory, ensure_ascii=False, indent=2, sort_keys=True).encode("utf-8") + b"\n"

    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for relative_path, payload in archive_entries:
            archive.writestr(relative_path, payload)
        archive.writestr(ARCHIVE_INVENTORY_NAME, inventory_payload)

    return archive_path


def main() -> int:
    args = parse_args()
    evidence_dir = args.evidence_dir.resolve()
    if not evidence_dir.exists():
        print(f"FAIL: evidence directory does not exist: {evidence_dir}", file=sys.stderr)
        return 2

    try:
        report = make_report(evidence_dir)
    except Exception as error:
        print(f"FAIL: could not inspect evidence directory: {error}", file=sys.stderr)
        return 2

    markdown = render_markdown(report)
    if args.write or args.archive:
        (evidence_dir / "evidence_status.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        (evidence_dir / "evidence_status.md").write_text(markdown, encoding="utf-8")

    archive_path = None
    if args.archive:
        try:
            archive_path = write_archive(evidence_dir, report)
        except RuntimeError as error:
            print(f"FAIL: {error}", file=sys.stderr)
            return 1

    if args.quiet:
        print(
            f"Evidence status: {report['status']} "
            f"({report['summary']['present']}/{report['summary']['total']} present, "
            f"{report['summary']['privacyFindings']} privacy findings, "
            f"{report['summary']['qualityFindings']} quality findings)"
        )
        if archive_path is not None:
            print(f"Archive package: {archive_path}")
    else:
        print(markdown)
        if archive_path is not None:
            print(f"Archive package: {archive_path}")

    if args.fail_on_missing and (
        report["summary"]["missing"] > 0
        or report["summary"]["privacyFindings"] > 0
        or report["summary"]["qualityFindings"] > 0
    ):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
