#!/usr/bin/env python3
import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "Scripts/roadshow_share_package_privacy_check.py"


def fail(message: str) -> int:
    print(f"RoadshowSharePackageSample verification failed: {message}", file=sys.stderr)
    return 1


def package_text(graph: dict) -> str:
    return json.dumps(
        {
            "sourceUserId": "roadshow-user",
            "sourceNickname": "陈岚",
            "exportDate": "2026-06-12T12:00:00Z",
            "graphJSON": json.dumps(graph, ensure_ascii=False),
        },
        ensure_ascii=False,
    )


def valid_graph() -> dict:
    return {
        "people": [{"id": "p1", "name": "陈树安"}],
        "places": [{"id": "pl1", "name": "上海"}],
        "events": [{"id": "e1", "title": "外滩合影"}],
        "facts": [{"id": "f1", "statement": "公开家庭记忆摘要"}],
    }


def write_valid_packages(evidence_dir: Path) -> None:
    share_dir = evidence_dir / "share_packages"
    share_dir.mkdir(parents=True, exist_ok=True)
    (share_dir / "all_family.json").write_text(package_text(valid_graph()), encoding="utf-8")
    selected = valid_graph()
    selected["people"] = [{"id": "p2", "name": "陈静文"}]
    (share_dir / "selected_member.json").write_text(package_text(selected), encoding="utf-8")


def run_checker(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(CHECKER), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def main() -> int:
    if not CHECKER.exists():
        return fail("share package sample checker is missing")

    with tempfile.TemporaryDirectory(prefix="dreamjourney_share_package_sample_verify_") as tmp_name:
        evidence_dir = Path(tmp_name)
        write_valid_packages(evidence_dir)
        privacy_log = evidence_dir / "share_packages/privacy_check.log"

        passed = run_checker(str(evidence_dir), "--write-log", str(privacy_log))
        if passed.returncode != 0:
            return fail(f"valid share packages should pass: {passed.stderr}")
        log_text = privacy_log.read_text(encoding="utf-8").lower()
        for token in [
            "pass share package privacy check",
            "share_packages/all_family.json",
            "share_packages/selected_member.json",
            "no private_",
            "no raw_transcript",
            "no unauthorized_",
        ]:
            if token not in log_text:
                return fail(f"privacy check log missing token: {token}")

        json_result = run_checker(str(evidence_dir), "--json")
        if json_result.returncode != 0:
            return fail("json mode should pass valid share packages")
        payload = json.loads(json_result.stdout)
        if payload.get("status") != "pass" or len(payload.get("packages", [])) != 2:
            return fail("json mode should report two passing packages")

        (evidence_dir / "share_packages/all_family.json").write_text("{bad-json\n", encoding="utf-8")
        invalid_json = run_checker(str(evidence_dir), "--json")
        if invalid_json.returncode != 2:
            return fail("checker should fail invalid package JSON")
        invalid_payload = json.loads(invalid_json.stdout)
        if invalid_payload.get("status") != "fail" or "invalid-json" not in str(invalid_payload.get("findings", [])):
            return fail("checker should report invalid-json finding")

        write_valid_packages(evidence_dir)
        leaked = package_text(valid_graph()).replace("公开家庭记忆摘要", "PRIVATE_RAW_TRANSCRIPT")
        (evidence_dir / "share_packages/selected_member.json").write_text(leaked, encoding="utf-8")
        leaked_result = run_checker(str(evidence_dir), "--json")
        if leaked_result.returncode != 2:
            return fail("checker should fail forbidden share package sentinel")
        leaked_payload = json.loads(leaked_result.stdout)
        if "PRIVATE_" not in str(leaked_payload.get("findings", [])):
            return fail("checker should name forbidden marker type")

        write_valid_packages(evidence_dir)
        incomplete_graph = {"people": []}
        (evidence_dir / "share_packages/all_family.json").write_text(
            package_text(incomplete_graph),
            encoding="utf-8",
        )
        incomplete_result = run_checker(str(evidence_dir), "--json")
        if incomplete_result.returncode != 2:
            return fail("checker should fail graphJSON missing arrays")
        incomplete_payload = json.loads(incomplete_result.stdout)
        if "missing-graph-field" not in str(incomplete_payload.get("findings", [])):
            return fail("checker should report missing graph fields")

    print("RoadshowSharePackageSample verification passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
