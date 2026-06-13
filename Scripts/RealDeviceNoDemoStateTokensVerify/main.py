#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
VERIFY_SCRIPT = ROOT / "Scripts/RealDeviceNoDemoStateVerify/main.py"

required_tokens = [
    "fm_daughter_chen_lan",
    "fm_son_chen_hao",
    "fm_granddaughter_chen_yu",
    "陈岚",
    "陈浩",
    "陈予",
    "外滩老照片",
    "roadshow_demo_photo_placeholder",
]

script_text = VERIFY_SCRIPT.read_text(encoding="utf-8")
missing = [token for token in required_tokens if token not in script_text]
if missing:
    raise SystemExit("RealDeviceNoDemoStateVerify missing tokens: " + ", ".join(missing))

tmpdir = Path(tempfile.mkdtemp(prefix="dreamjourney_no_demo_tokens_"))
try:
    clean_dir = tmpdir / "clean"
    clean_dir.mkdir()
    (clean_dir / "evidence.log").write_text("真实验收：用户陈建国完成知识库沉淀。\n", encoding="utf-8")
    clean_result = subprocess.run(
        ["python3", str(VERIFY_SCRIPT), str(clean_dir), "--strict"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if clean_result.returncode != 0:
        raise SystemExit("clean no-demo evidence should pass:\n" + clean_result.stderr)

    polluted_dir = tmpdir / "polluted"
    polluted_dir.mkdir()
    (polluted_dir / "evidence.log").write_text(
        "真实验收日志不应包含陈岚或 roadshow_demo_photo_placeholder。\n",
        encoding="utf-8",
    )
    polluted_result = subprocess.run(
        ["python3", str(VERIFY_SCRIPT), str(polluted_dir), "--strict"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if polluted_result.returncode == 0:
        raise SystemExit("polluted no-demo evidence should fail")
    if "陈岚" not in polluted_result.stderr or "roadshow_demo_photo_placeholder" not in polluted_result.stderr:
        raise SystemExit("polluted no-demo evidence should name both forbidden tokens")
finally:
    shutil.rmtree(tmpdir, ignore_errors=True)

print("RealDeviceNoDemoStateTokens verification passed")
