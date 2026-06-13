#!/usr/bin/env python3
import hashlib
import json
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[2]
REPORTER = ROOT / "Scripts/roadshow_evidence_report.py"


def fail(message: str) -> int:
    print(f"RoadshowEvidencePackage verification failed: {message}", file=sys.stderr)
    return 1


def write_file(path: Path, content: str = "ok\n") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def write_bytes(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def write_minimal_png(path: Path) -> None:
    write_bytes(path, b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR")


def write_minimal_mp4(path: Path) -> None:
    write_bytes(path, b"\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42")


def create_fixture(root: Path) -> None:
    manifest = {
        "app": "DreamJourney",
        "mode": "roadshow_device_smoke",
        "routeScreens": [
            {"id": "home", "title": "Home", "evidenceFile": "screens/01_home_banner.png"},
            {"id": "route", "title": "Route", "evidenceFile": "screens/02_route_checklist.png"},
        ],
        "additionalArtifacts": [
            "recordings/roadshow_6min_run.mp4",
            "route_completion/route_completion_preferences.txt",
            "share_packages/all_family.json",
            "share_packages/selected_member.json",
            "share_packages/privacy_check.log",
            "diagnostics/digital_human_readiness.txt",
            "diagnostics/digital_human_readiness.json",
            "diagnostics/digital_human_playback.log",
            "app_console_sample.log",
        ],
    }
    write_file(root / "evidence_manifest.json", json.dumps(manifest, ensure_ascii=False))
    for relative_path in [
        "expected_screens.txt",
        "expected_state_keys.txt",
        "route_screen_checklist.md",
        "route_completion/route_acceptance_checklist.md",
        "archive_package_next_steps.txt",
        "xctrace_devices.txt",
        "physical_ios_devices.txt",
        "build_settings.txt",
        "bundle_identifier.txt",
        "iphoneos_build_gate.log",
        "iphoneos_build_gate.command",
        "iphoneos_build_gate.exit_code",
    ]:
        write_file(root / relative_path)
    write_minimal_png(root / "screens/01_home_banner.png")
    write_minimal_mp4(root / "recordings/roadshow_6min_run.mp4")


def run_reporter(evidence_dir: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(REPORTER), str(evidence_dir), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def route_completion_preferences_text(value: str = "true") -> str:
    return "\n".join(
        [
            "Roadshow route completion preferences",
            f"dreamjourney.roadshow.route.completed.voice_companion={value}",
            f"dreamjourney.roadshow.route.completed.time_mailbox={value}",
            f"dreamjourney.roadshow.route.completed.memory_archive={value}",
            f"dreamjourney.roadshow.route.completed.family_footprint={value}",
            f"dreamjourney.roadshow.route.completed.care_dashboard={value}",
            f"dreamjourney.roadshow.route.completed.family_share={value}",
            "",
        ]
    )


def route_acceptance_checklist_text() -> str:
    return "\n".join(
        [
            "路演验收进度 6/6",
            "启动参数：Scripts/roadshow_device_smoke_preflight.sh",
            "",
            "[x] 语音陪伴与数字人 - 已验收 证据：screens/03_memory_voice_digital_human.png",
            "[x] 时空信箱边界 - 已验收 证据：screens/04_time_mailbox_delivered_letter.png",
            "[x] 记忆档案馆 - 已验收 证据：screens/05_memory_archive_photo_analysis.png",
            "[x] 家族足迹点亮 - 已验收 证据：screens/06_family_footprint_world_generation.png",
            "[x] 亲友关怀看板 - 已验收 证据：screens/07_family_care_dashboard_member.png",
            "[x] 分享包与隐私收口 - 已验收 证据：screens/08_share_package_export_sheet.png",
            "",
            "边界声明",
            "- 不做诊断，不冒充亲人。",
            "",
        ]
    )


def privacy_check_log_text() -> str:
    return "\n".join(
        [
            "PASS share package privacy check",
            "checked: share_packages/all_family.json",
            "checked: share_packages/selected_member.json",
            "no PRIVATE_/LOCAL_/GENERATION_ markers",
            "no RAW_TRANSCRIPT/FULL_TRANSCRIPT/FULL_LETTER content",
            "no UNAUTHORIZED_ member content",
            "",
        ]
    )


def digital_human_readiness_json_text() -> str:
    return json.dumps(
        {
            "title": "数字人真机诊断",
            "status": "ready",
            "statusTitle": "已就绪",
            "subtitle": "真实语音链路 · 4/4 项就绪",
            "items": [
                {
                    "title": "数字人口型 TTS",
                    "status": "ready",
                    "statusTitle": "已就绪",
                    "detail": "已配置",
                    "recommendation": "保持当前配置",
                }
            ],
            "playbackEvidenceChecks": [
                {
                    "title": "原生音频播放完成",
                    "source": "native_audio",
                    "expectedLog": "wav_synth_success -> playback_finished source=native_audio",
                    "acceptance": "数字人口型和声音完成播放",
                }
            ],
            "redaction": "No API Key, Token, Secret, or realtime request header is included.",
        },
        ensure_ascii=False,
        sort_keys=True,
    ) + "\n"


def share_package_json_text(graph: Optional[dict] = None, **overrides: object) -> str:
    graph_payload = graph if graph is not None else {
        "version": 2,
        "lastUpdated": "2026-06-12T00:00:00Z",
        "sessionCount": 1,
        "people": [],
        "places": [],
        "events": [],
        "facts": [],
    }
    package = {
        "sourceUserId": "roadshow-user",
        "sourceNickname": "陈岚",
        "exportDate": "2026-06-12T00:00:00Z",
        "graphJSON": json.dumps(graph_payload, ensure_ascii=False, sort_keys=True),
    }
    package.update(overrides)
    return json.dumps(package, ensure_ascii=False, sort_keys=True) + "\n"


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="dreamjourney_evidence_verify_") as tmp:
        evidence_dir = Path(tmp)
        create_fixture(evidence_dir)

        result = run_reporter(evidence_dir, "--write", "--quiet")
        if result.returncode != 0:
            return fail(f"reporter should allow missing manual evidence, got {result.returncode}: {result.stderr}")
        if "needs_manual_evidence" not in result.stdout:
            return fail("reporter should print needs_manual_evidence for incomplete route artifacts")

        status_path = evidence_dir / "evidence_status.json"
        markdown_path = evidence_dir / "evidence_status.md"
        if not status_path.exists() or not markdown_path.exists():
            return fail("reporter should write JSON and Markdown status files")

        status = json.loads(status_path.read_text(encoding="utf-8"))
        if status["status"] != "needs_manual_evidence":
            return fail(f"expected needs_manual_evidence, got {status['status']}")
        readiness = status.get("readiness", {})
        if readiness.get("canArchive") is not False:
            return fail("incomplete evidence should not be archive-ready")
        if readiness.get("completionPercent", 100) >= 100:
            return fail("incomplete evidence should report completion below 100 percent")
        if "manual_evidence" not in readiness.get("blockers", []):
            return fail("incomplete evidence should report manual_evidence blocker")
        if status["summary"]["routeScreensMissing"] != 1:
            return fail("reporter should count one missing route screenshot")
        if status["summary"]["additionalArtifactsMissing"] != 8:
            return fail("reporter should count eight missing additional artifacts")
        if status["summary"]["automaticContextMissing"] != 0:
            return fail("reporter should treat automatic context as complete in fixture")
        stage_groups = status.get("stageGroups", [])
        if not stage_groups:
            return fail("reporter should emit stageGroups")
        stage_by_id = {group["id"]: group for group in stage_groups}
        if stage_by_id.get("preflight", {}).get("status") != "complete":
            return fail("preflight stage group should be complete in fixture")
        if "screens/02_route_checklist.png" not in stage_by_id.get("route", {}).get("missingPaths", []):
            return fail("route stage group should include missing route screenshot")
        if "route_completion/route_completion_preferences.txt" not in stage_by_id.get("route", {}).get("missingPaths", []):
            return fail("route stage group should include missing route completion preferences")
        supporting_missing = stage_by_id.get("supporting_artifacts", {}).get("missingPaths", [])
        for path in [
            "diagnostics/digital_human_readiness.json",
            "diagnostics/digital_human_readiness.txt",
            "diagnostics/digital_human_playback.log",
            "share_packages/all_family.json",
            "app_console_sample.log",
        ]:
            if path not in supporting_missing:
                return fail(f"supporting stage group should include missing {path}")
        if status["summary"]["stageGroupsIncomplete"] < 2:
            return fail("reporter should count incomplete stage groups")
        actions = status.get("nextActions", [])
        if not actions:
            return fail("reporter should emit prioritized nextActions")
        action_paths = [item["path"] for item in actions]
        expected_paths = [
            "diagnostics/digital_human_readiness.json",
            "diagnostics/digital_human_readiness.txt",
            "diagnostics/digital_human_playback.log",
            "screens/02_route_checklist.png",
            "route_completion/route_acceptance_checklist.md",
            "share_packages/all_family.json",
            "share_packages/selected_member.json",
            "share_packages/privacy_check.log",
            "app_console_sample.log",
            "route_completion/route_completion_preferences.txt",
        ]
        if action_paths != expected_paths:
            return fail(f"nextActions should be prioritized by roadshow workflow, got {action_paths}")
        if actions[0]["priority"] != 20 or "Documents/diagnostics/" not in actions[0]["action"]:
            return fail("diagnostics should be the first semi-auto next action")
        if actions[2]["priority"] != 25 or "DigitalHumanSpeech" not in actions[2]["action"]:
            return fail("digital-human playback log should follow diagnostics next actions")
        if "roadshow_digital_human_playback_audit.py" not in actions[2]["action"]:
            return fail("digital-human playback next action should include strict audit command")
        if actions[4]["priority"] != 36 or "acceptance checklist" not in actions[4]["action"]:
            return fail("route acceptance checklist should be the first route quality action")
        if readiness.get("nextAction", {}).get("path") != expected_paths[0]:
            return fail("readiness summary should point to the first prioritized next action")
        markdown = markdown_path.read_text(encoding="utf-8")
        if "## Roadshow Readiness" not in markdown:
            return fail("markdown report should include Roadshow Readiness")
        if "Can archive/share evidence: `false`" not in markdown:
            return fail("markdown report should mark incomplete evidence as not archive-ready")
        if "## Next Actions" not in markdown:
            return fail("markdown report should include Next Actions")
        if "## Stage Evidence" not in markdown:
            return fail("markdown report should include Stage Evidence")
        if "自动上下文与脚手架" not in markdown:
            return fail("markdown report should include preflight stage group")
        if "screens/02_route_checklist.png" not in markdown:
            return fail("markdown report should list missing route screenshot")
        if "diagnostics/digital_human_readiness.txt" not in markdown:
            return fail("markdown report should list missing diagnostics evidence")
        if "diagnostics/digital_human_playback.log" not in markdown:
            return fail("markdown report should list missing playback log evidence")
        if "## Quality Review" not in markdown:
            return fail("markdown report should include Quality Review")

        fail_result = run_reporter(evidence_dir, "--fail-on-missing", "--quiet")
        if fail_result.returncode != 1:
            return fail("--fail-on-missing should return 1 when evidence is incomplete")

        write_minimal_png(evidence_dir / "screens/02_route_checklist.png")
        write_file(evidence_dir / "route_completion/route_completion_preferences.txt", route_completion_preferences_text())
        write_file(evidence_dir / "route_completion/route_acceptance_checklist.md", route_acceptance_checklist_text())
        write_file(evidence_dir / "share_packages/all_family.json", share_package_json_text())
        write_file(evidence_dir / "share_packages/selected_member.json", share_package_json_text())
        write_file(evidence_dir / "share_packages/privacy_check.log", privacy_check_log_text())
        write_file(evidence_dir / "diagnostics/digital_human_readiness.txt")
        write_file(evidence_dir / "diagnostics/digital_human_readiness.json", digital_human_readiness_json_text())
        write_file(
            evidence_dir / "diagnostics/digital_human_playback.log",
            "wav_synth_success\nplayback_finished source=native_audio\n",
        )
        write_file(evidence_dir / "app_console_sample.log")
        complete_result = run_reporter(evidence_dir, "--write", "--fail-on-missing", "--quiet")
        if complete_result.returncode != 0:
            return fail(f"complete evidence should pass fail-on-missing: {complete_result.stderr}")
        complete_status = json.loads(status_path.read_text(encoding="utf-8"))
        if complete_status["status"] != "complete":
            return fail(f"expected complete status, got {complete_status['status']}")
        if complete_status["readiness"]["canArchive"] is not True:
            return fail("complete evidence should be archive-ready")
        if complete_status["readiness"]["completionPercent"] != 100:
            return fail("complete evidence should report 100 percent completion")
        if complete_status["readiness"]["blockers"]:
            return fail("complete evidence should not report blockers")
        if complete_status["summary"]["privacyFindings"] != 0:
            return fail("complete clean fixture should not report privacy findings")
        if complete_status["summary"].get("qualityFindings", 0) != 0:
            return fail("accepted playback chain should not report quality findings")
        if complete_status["summary"]["stageGroupsIncomplete"] != 0:
            return fail("complete clean fixture should not have incomplete stage groups")
        archive_plan = complete_status.get("archivePlan", {})
        if archive_plan.get("ready") is not True:
            return fail("complete clean fixture should expose a ready archive plan")
        if not str(archive_plan.get("packageName", "")).endswith(".zip"):
            return fail("archive plan should name a zip package")
        for path in [
            "evidence_manifest.json",
            "archive_package_next_steps.txt",
            "route_completion/route_completion_preferences.txt",
            "screens/01_home_banner.png",
            "diagnostics/digital_human_readiness.json",
            "diagnostics/digital_human_playback.log",
            "share_packages/all_family.json",
            "share_packages/privacy_check.log",
        ]:
            if path not in archive_plan.get("includedPaths", []):
                return fail(f"archive plan should include {path}")

        complete_markdown = markdown_path.read_text(encoding="utf-8")
        if "## Archive Package" not in complete_markdown:
            return fail("markdown report should include Archive Package")
        if "Ready: `true`" not in complete_markdown:
            return fail("markdown archive section should mark complete evidence as ready")

        archive_result = run_reporter(evidence_dir, "--write", "--archive", "--quiet")
        if archive_result.returncode != 0:
            return fail(f"--archive should create a zip for complete evidence: {archive_result.stderr}")
        archive_path = evidence_dir / archive_plan["packageName"]
        if not archive_path.exists():
            return fail("--archive should write the planned zip file")
        with zipfile.ZipFile(archive_path) as archive:
            names = set(archive.namelist())
            archive_payloads = {
                name: archive.read(name)
                for name in names
                if not name.endswith("/")
            }
        for path in [
            "evidence_status.json",
            "evidence_status.md",
            "evidence_manifest.json",
            "archive_inventory.json",
            "archive_package_next_steps.txt",
            "route_completion/route_completion_preferences.txt",
            "diagnostics/digital_human_readiness.json",
            "diagnostics/digital_human_playback.log",
            "share_packages/all_family.json",
            "share_packages/privacy_check.log",
        ]:
            if path not in names:
                return fail(f"archive zip should include {path}")
        archive_inventory = json.loads(archive_payloads["archive_inventory.json"].decode("utf-8"))
        if archive_inventory.get("packageName") != archive_plan["packageName"]:
            return fail("archive inventory should record the package name")
        inventory_files = {
            item["path"]: item
            for item in archive_inventory.get("files", [])
        }
        for path in archive_plan.get("includedPaths", []):
            if path == "archive_inventory.json":
                continue
            if path not in inventory_files:
                return fail(f"archive inventory should include {path}")
            payload = archive_payloads.get(path)
            if payload is None:
                return fail(f"archive zip should contain inventory path {path}")
            item = inventory_files[path]
            if item.get("sizeBytes") != len(payload):
                return fail(f"archive inventory should record size for {path}")
            if item.get("sha256") != hashlib.sha256(payload).hexdigest():
                return fail(f"archive inventory should record sha256 for {path}")

        write_file(evidence_dir / "screens/02_route_checklist.png", "not a png\n")
        invalid_png_result = run_reporter(evidence_dir, "--write", "--quiet")
        if invalid_png_result.returncode != 0:
            return fail(f"invalid PNG quality review should not crash: {invalid_png_result.stderr}")
        invalid_png_status = json.loads(status_path.read_text(encoding="utf-8"))
        if invalid_png_status["status"] != "needs_manual_evidence":
            return fail(f"expected needs_manual_evidence for invalid PNG, got {invalid_png_status['status']}")
        invalid_png_markdown = markdown_path.read_text(encoding="utf-8")
        if "route-screenshot-invalid-png" not in invalid_png_markdown:
            return fail("markdown report should name invalid route screenshot PNG")
        write_minimal_png(evidence_dir / "screens/02_route_checklist.png")

        write_file(evidence_dir / "recordings/roadshow_6min_run.mp4", "not an mp4\n")
        invalid_mp4_result = run_reporter(evidence_dir, "--write", "--quiet")
        if invalid_mp4_result.returncode != 0:
            return fail(f"invalid MP4 quality review should not crash: {invalid_mp4_result.stderr}")
        invalid_mp4_status = json.loads(status_path.read_text(encoding="utf-8"))
        if invalid_mp4_status["status"] != "needs_manual_evidence":
            return fail(f"expected needs_manual_evidence for invalid MP4, got {invalid_mp4_status['status']}")
        invalid_mp4_markdown = markdown_path.read_text(encoding="utf-8")
        if "recording-invalid-mp4" not in invalid_mp4_markdown:
            return fail("markdown report should name invalid roadshow recording MP4")
        write_minimal_mp4(evidence_dir / "recordings/roadshow_6min_run.mp4")

        write_file(evidence_dir / "diagnostics/digital_human_readiness.json", "{not-json\n")
        invalid_readiness_result = run_reporter(evidence_dir, "--write", "--quiet")
        if invalid_readiness_result.returncode != 0:
            return fail(f"invalid readiness JSON quality review should not crash: {invalid_readiness_result.stderr}")
        invalid_readiness_status = json.loads(status_path.read_text(encoding="utf-8"))
        if invalid_readiness_status["status"] != "needs_manual_evidence":
            return fail(
                "expected needs_manual_evidence for invalid readiness JSON, "
                f"got {invalid_readiness_status['status']}"
            )
        invalid_readiness_markdown = markdown_path.read_text(encoding="utf-8")
        if "digital-human-readiness-invalid-json" not in invalid_readiness_markdown:
            return fail("markdown report should name invalid digital-human readiness JSON")

        write_file(
            evidence_dir / "diagnostics/digital_human_readiness.json",
            json.dumps({"title": "数字人真机诊断"}, ensure_ascii=False) + "\n",
        )
        incomplete_readiness_result = run_reporter(evidence_dir, "--write", "--quiet")
        if incomplete_readiness_result.returncode != 0:
            return fail(
                "incomplete readiness JSON quality review should not crash: "
                f"{incomplete_readiness_result.stderr}"
            )
        incomplete_readiness_status = json.loads(status_path.read_text(encoding="utf-8"))
        if incomplete_readiness_status["summary"].get("qualityFindings") != 1:
            return fail("incomplete readiness JSON should report one quality finding")
        incomplete_readiness_markdown = markdown_path.read_text(encoding="utf-8")
        if "digital-human-readiness-incomplete" not in incomplete_readiness_markdown:
            return fail("markdown report should name incomplete digital-human readiness JSON")

        write_file(evidence_dir / "diagnostics/digital_human_readiness.json", digital_human_readiness_json_text())

        write_file(evidence_dir / "diagnostics/digital_human_playback.log", "DigitalHumanSpeech ready\n")
        quality_result = run_reporter(evidence_dir, "--write", "--quiet")
        if quality_result.returncode != 0:
            return fail(f"quality review without fail-on-missing should not crash: {quality_result.stderr}")
        quality_status = json.loads(status_path.read_text(encoding="utf-8"))
        if quality_status["status"] != "needs_manual_evidence":
            return fail(f"expected needs_manual_evidence for weak playback evidence, got {quality_status['status']}")
        if quality_status["readiness"]["canArchive"] is not False:
            return fail("weak playback evidence should block archive readiness")
        if "manual_evidence" not in quality_status["readiness"]["blockers"]:
            return fail("weak playback evidence should be listed as a manual evidence blocker")
        if quality_status["summary"].get("qualityFindings") != 1:
            return fail("weak playback evidence should report one quality finding")
        quality_actions = quality_status.get("nextActions", [])
        if not quality_actions or quality_actions[0]["category"] != "quality":
            return fail("quality review should be the highest-priority non-privacy next action")
        quality_markdown = markdown_path.read_text(encoding="utf-8")
        if "playback-log-missing-accepted-chain" not in quality_markdown:
            return fail("markdown report should name the playback log quality check")

        quality_fail_result = run_reporter(evidence_dir, "--fail-on-missing", "--quiet")
        if quality_fail_result.returncode != 1:
            return fail("--fail-on-missing should return 1 when playback evidence is weak")
        quality_archive_result = run_reporter(evidence_dir, "--archive", "--quiet")
        if quality_archive_result.returncode != 1:
            return fail("--archive should refuse weak playback evidence")

        write_file(
            evidence_dir / "diagnostics/digital_human_playback.log",
            "fallback=systemTTS\nplayback_finished source=system_tts\n",
        )

        write_file(evidence_dir / "route_completion/route_completion_preferences.txt", route_completion_preferences_text("false"))
        route_quality_result = run_reporter(evidence_dir, "--write", "--quiet")
        if route_quality_result.returncode != 0:
            return fail(f"route completion quality review should not crash: {route_quality_result.stderr}")
        route_quality_status = json.loads(status_path.read_text(encoding="utf-8"))
        if route_quality_status["status"] != "needs_manual_evidence":
            return fail(f"expected needs_manual_evidence for incomplete route completion, got {route_quality_status['status']}")
        if route_quality_status["summary"].get("qualityFindings") != 1:
            return fail("incomplete route completion should report one quality finding")
        route_quality_markdown = markdown_path.read_text(encoding="utf-8")
        if "route-completion-incomplete" not in route_quality_markdown:
            return fail("markdown report should name incomplete route completion check")
        route_quality_archive_result = run_reporter(evidence_dir, "--archive", "--quiet")
        if route_quality_archive_result.returncode != 1:
            return fail("--archive should refuse incomplete route completion preferences")

        write_file(evidence_dir / "route_completion/route_completion_preferences.txt", route_completion_preferences_text())

        write_file(
            evidence_dir / "route_completion/route_acceptance_checklist.md",
            "Paste copied checklist below:\n\n```text\n<paste in-app checklist here>\n```\n",
        )
        acceptance_quality_result = run_reporter(evidence_dir, "--write", "--quiet")
        if acceptance_quality_result.returncode != 0:
            return fail(f"route acceptance quality review should not crash: {acceptance_quality_result.stderr}")
        acceptance_quality_status = json.loads(status_path.read_text(encoding="utf-8"))
        if acceptance_quality_status["status"] != "needs_manual_evidence":
            return fail(
                "expected needs_manual_evidence for placeholder route acceptance checklist, "
                f"got {acceptance_quality_status['status']}"
            )
        if acceptance_quality_status["summary"].get("qualityFindings") != 1:
            return fail("placeholder route acceptance checklist should report one quality finding")
        acceptance_quality_markdown = markdown_path.read_text(encoding="utf-8")
        if "route-acceptance-placeholder" not in acceptance_quality_markdown:
            return fail("markdown report should name placeholder route acceptance check")

        write_file(evidence_dir / "route_completion/route_acceptance_checklist.md", route_acceptance_checklist_text())

        write_file(evidence_dir / "share_packages/all_family.json", "{not-json\n")
        invalid_share_result = run_reporter(evidence_dir, "--write", "--quiet")
        if invalid_share_result.returncode != 0:
            return fail(f"invalid share package quality review should not crash: {invalid_share_result.stderr}")
        invalid_share_status = json.loads(status_path.read_text(encoding="utf-8"))
        if invalid_share_status["status"] != "needs_manual_evidence":
            return fail(f"expected needs_manual_evidence for invalid share package, got {invalid_share_status['status']}")
        if invalid_share_status["summary"].get("qualityFindings") != 1:
            return fail("invalid share package should report one quality finding")
        if invalid_share_status.get("nextActions", [])[0]["path"] != "share_packages/all_family.json":
            return fail("invalid share package should be the first quality next action")
        invalid_share_markdown = markdown_path.read_text(encoding="utf-8")
        if "share-package-invalid-json" not in invalid_share_markdown:
            return fail("markdown report should name invalid share package JSON")

        invalid_share_fail_result = run_reporter(evidence_dir, "--fail-on-missing", "--quiet")
        if invalid_share_fail_result.returncode != 1:
            return fail("--fail-on-missing should return 1 when share package JSON is invalid")

        write_file(evidence_dir / "share_packages/all_family.json", "{\"graphJSON\":\"PRIVATE_ROADSHOW_PERSON_SENTINEL\"}\n")
        leaked_share_result = run_reporter(evidence_dir, "--write", "--quiet")
        if leaked_share_result.returncode != 0:
            return fail(f"forbidden share package marker review should not crash: {leaked_share_result.stderr}")
        leaked_share_status = json.loads(status_path.read_text(encoding="utf-8"))
        if leaked_share_status["summary"].get("qualityFindings") != 1:
            return fail("forbidden share package marker should report one quality finding")
        leaked_share_markdown = markdown_path.read_text(encoding="utf-8")
        if "share-package-forbidden-marker:PRIVATE_" not in leaked_share_markdown:
            return fail("markdown report should name forbidden share package marker type")

        write_file(evidence_dir / "share_packages/all_family.json", "{}\n")
        missing_schema_result = run_reporter(evidence_dir, "--write", "--quiet")
        if missing_schema_result.returncode != 0:
            return fail(f"missing share package schema review should not crash: {missing_schema_result.stderr}")
        missing_schema_status = json.loads(status_path.read_text(encoding="utf-8"))
        if missing_schema_status["status"] != "needs_manual_evidence":
            return fail(
                "expected needs_manual_evidence for missing share package schema, "
                f"got {missing_schema_status['status']}"
            )
        missing_schema_markdown = markdown_path.read_text(encoding="utf-8")
        if "share-package-invalid-schema" not in missing_schema_markdown:
            return fail("markdown report should name invalid share package schema")

        write_file(evidence_dir / "share_packages/all_family.json", share_package_json_text(graphJSON="not-json"))
        invalid_graph_result = run_reporter(evidence_dir, "--write", "--quiet")
        if invalid_graph_result.returncode != 0:
            return fail(f"invalid graphJSON review should not crash: {invalid_graph_result.stderr}")
        invalid_graph_status = json.loads(status_path.read_text(encoding="utf-8"))
        if invalid_graph_status["summary"].get("qualityFindings") != 1:
            return fail("invalid graphJSON should report one quality finding")
        invalid_graph_markdown = markdown_path.read_text(encoding="utf-8")
        if "share-package-invalid-graph-json" not in invalid_graph_markdown:
            return fail("markdown report should name invalid inner graph JSON")

        write_file(evidence_dir / "share_packages/all_family.json", share_package_json_text(graph={"people": []}))
        invalid_graph_schema_result = run_reporter(evidence_dir, "--write", "--quiet")
        if invalid_graph_schema_result.returncode != 0:
            return fail(f"invalid graph schema review should not crash: {invalid_graph_schema_result.stderr}")
        invalid_graph_schema_status = json.loads(status_path.read_text(encoding="utf-8"))
        if invalid_graph_schema_status["summary"].get("qualityFindings") != 1:
            return fail("invalid graph schema should report one quality finding")
        invalid_graph_schema_markdown = markdown_path.read_text(encoding="utf-8")
        if "share-package-invalid-graph-schema" not in invalid_graph_schema_markdown:
            return fail("markdown report should name invalid inner graph schema")

        write_file(evidence_dir / "share_packages/all_family.json", share_package_json_text())

        write_file(evidence_dir / "share_packages/privacy_check.log", "checked exported packages\n")
        privacy_check_quality_result = run_reporter(evidence_dir, "--write", "--quiet")
        if privacy_check_quality_result.returncode != 0:
            return fail(
                f"privacy check log quality review should not crash: {privacy_check_quality_result.stderr}"
            )
        privacy_check_quality_status = json.loads(status_path.read_text(encoding="utf-8"))
        if privacy_check_quality_status["status"] != "needs_manual_evidence":
            return fail(
                "expected needs_manual_evidence for weak privacy check log, "
                f"got {privacy_check_quality_status['status']}"
            )
        if privacy_check_quality_status["summary"].get("qualityFindings") != 1:
            return fail("weak privacy check log should report one quality finding")
        privacy_next_action = privacy_check_quality_status.get("nextActions", [])[0]
        if privacy_next_action["path"] != "share_packages/privacy_check.log":
            return fail("weak privacy check log should be the first share-package quality action")
        if "roadshow_share_package_privacy_check.py" not in privacy_next_action["action"]:
            return fail("weak privacy check action should include share package sample checker command")
        privacy_check_quality_markdown = markdown_path.read_text(encoding="utf-8")
        if "share-package-privacy-check-incomplete" not in privacy_check_quality_markdown:
            return fail("markdown report should name weak share package privacy check")

        write_file(evidence_dir / "share_packages/privacy_check.log", privacy_check_log_text())

        leaked_value = "sk-" + "testshouldnotappear1234567890"
        write_file(evidence_dir / "app_console_sample.log", f"DigitalHumanSpeech x-api-key: {leaked_value}\n")
        privacy_result = run_reporter(evidence_dir, "--write", "--quiet")
        if privacy_result.returncode != 0:
            return fail(f"privacy review without fail-on-missing should not crash: {privacy_result.stderr}")
        if "needs_privacy_review" not in privacy_result.stdout:
            return fail("reporter should print needs_privacy_review when evidence contains token-shaped values")
        privacy_status = json.loads(status_path.read_text(encoding="utf-8"))
        if privacy_status["status"] != "needs_privacy_review":
            return fail(f"expected needs_privacy_review, got {privacy_status['status']}")
        if privacy_status["readiness"]["canArchive"] is not False:
            return fail("privacy findings should block archive readiness")
        if "privacy" not in privacy_status["readiness"]["blockers"]:
            return fail("privacy findings should be listed as a readiness blocker")
        if privacy_status["summary"]["privacyFindings"] != 1:
            return fail("reporter should count one privacy finding")
        privacy_actions = privacy_status.get("nextActions", [])
        if not privacy_actions or privacy_actions[0]["category"] != "privacy":
            return fail("privacy review should be the highest-priority next action")

        privacy_markdown = markdown_path.read_text(encoding="utf-8")
        if "## Privacy Review" not in privacy_markdown:
            return fail("markdown report should include Privacy Review section")
        if "credential-assignment" not in privacy_markdown:
            return fail("markdown report should include the detected credential pattern name")
        if leaked_value in privacy_markdown or leaked_value in json.dumps(privacy_status, ensure_ascii=False):
            return fail("privacy report must not echo raw secret-like values")

        privacy_fail_result = run_reporter(evidence_dir, "--fail-on-missing", "--quiet")
        if privacy_fail_result.returncode != 1:
            return fail("--fail-on-missing should return 1 when privacy findings exist")

        write_file(evidence_dir / "app_console_sample.log", "DigitalHumanSpeech ready without credentials\n")
        clean_result = run_reporter(evidence_dir, "--write", "--fail-on-missing", "--quiet")
        if clean_result.returncode != 0:
            return fail(f"cleaned complete evidence should pass after privacy finding is removed: {clean_result.stderr}")
        clean_status = json.loads(status_path.read_text(encoding="utf-8"))
        if clean_status["status"] != "complete":
            return fail(f"expected complete after redaction, got {clean_status['status']}")

    print("RoadshowEvidencePackage verification passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
