#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SCAFFOLD = ROOT / "Scripts/phase1_acceptance_evidence_scaffold.py"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"

MODULE_DIRS = [
    "phase1-memory-archive",
    "phase1-digital-human-grounding",
    "phase1-care-dashboard",
    "phase1-time-mailbox",
    "phase1-backend-smoke",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"Phase1AcceptanceEvidenceScaffold verification failed: {message}", file=sys.stderr)
        sys.exit(1)


require(SCAFFOLD.exists(), "Scripts/phase1_acceptance_evidence_scaffold.py should exist")

source = SCAFFOLD.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

for token in [
    "DREAMJOURNEY_BACKEND_BASE_URL",
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "BackendAuthenticatedSmoke/main.py --remote",
    "不提交原始照片、原始音频、信件正文、完整 transcript",
    "metadata-only",
]:
    require(token in source, f"scaffold should document {token!r}")

require(
    "Phase1AcceptanceEvidenceScaffoldVerify/main.py" in phase1,
    "phase1 verification should include the acceptance evidence scaffold contract",
)

with tempfile.TemporaryDirectory(prefix="dreamjourney_phase1_evidence_verify_") as tmp:
    evidence_root = Path(tmp) / "evidence"
    result = subprocess.run(
        [sys.executable, str(SCAFFOLD), "--root", str(evidence_root)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )
    require(result.returncode == 0, f"scaffold should exit 0: {result.stdout}\n{result.stderr}")

    manifest_path = evidence_root / "phase1_acceptance_manifest.json"
    status_path = evidence_root / "phase1_acceptance_checklist.md"
    require(manifest_path.exists(), "scaffold should write phase1_acceptance_manifest.json")
    require(status_path.exists(), "scaffold should write phase1_acceptance_checklist.md")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    module_ids = [module["id"] for module in manifest.get("modules", [])]
    for module_dir in MODULE_DIRS:
        require(module_dir in module_ids, f"manifest should include {module_dir}")
        require((evidence_root / module_dir / "README.md").exists(), f"{module_dir} should keep README.md")
        require((evidence_root / module_dir / "acceptance_checklist.md").exists(), f"{module_dir} should have acceptance checklist")

    memory_checklist = (evidence_root / "phase1-memory-archive" / "acceptance_checklist.md").read_text(encoding="utf-8")
    digital_checklist = (evidence_root / "phase1-digital-human-grounding" / "acceptance_checklist.md").read_text(encoding="utf-8")
    care_checklist = (evidence_root / "phase1-care-dashboard" / "acceptance_checklist.md").read_text(encoding="utf-8")
    mailbox_checklist = (evidence_root / "phase1-time-mailbox" / "acceptance_checklist.md").read_text(encoding="utf-8")
    backend_checklist = (evidence_root / "phase1-backend-smoke" / "acceptance_checklist.md").read_text(encoding="utf-8")

    require("陈建国" in memory_checklist and "林桂芳" in memory_checklist, "memory checklist should include canonical true-device text material")
    require("有证据才回答" in digital_checklist and "未沉淀事实不编造" in digital_checklist, "digital checklist should cover grounded answers")
    require("撤回后 403" in care_checklist and "无原始 transcript" in care_checklist, "care checklist should cover revocation and redaction")
    require("5 分钟" in mailbox_checklist and "正文不出端" in mailbox_checklist, "mailbox checklist should reflect current delay and privacy")
    require("BackendAuthenticatedSmoke/main.py --remote" in backend_checklist, "backend checklist should point to authenticated smoke")

print("Phase1AcceptanceEvidenceScaffold verification passed")
