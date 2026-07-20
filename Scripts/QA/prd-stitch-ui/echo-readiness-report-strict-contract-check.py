#!/usr/bin/env python3
"""Regression contract for fail-closed Echo readiness aggregation."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[3]
REPORT = ROOT / "Scripts/QA/prd-stitch-ui/echo-readiness-report.py"


def run_report(*, strict: bool) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
    environment = dict(os.environ)
    environment.pop("BACKEND_BASE_URL", None)
    environment.pop("BACKEND_API_TOKEN", None)
    environment.pop("VOICE_CLONE_READY_PROFILE_ID", None)
    environment["READINESS_STRICT"] = "1" if strict else "0"
    with tempfile.TemporaryDirectory(prefix="echo-readiness-strict-") as output:
        completed = subprocess.run(
            [sys.executable, str(REPORT), str(ROOT), output],
            capture_output=True,
            check=False,
            encoding="utf-8",
            env=environment,
            text=True,
        )
        report_path = Path(output) / "echo-readiness-report.json"
        if not report_path.exists():
            raise AssertionError(f"readiness report missing: {completed.stdout}\n{completed.stderr}")
        return completed, json.loads(report_path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    relaxed, relaxed_report = run_report(strict=False)
    require(relaxed.returncode == 0, "non-strict diagnostic report should be emitted")
    require(relaxed_report.get("completed") is False, "skipped checks must not complete readiness")
    require(relaxed_report.get("readinessStatus") == "notRun", "missing backend must be notRun")

    strict, strict_report = run_report(strict=True)
    require(strict.returncode != 0, "strict readiness must fail when backend probes are skipped")
    require(strict_report.get("completed") is False, "strict report must remain incomplete")
    require(strict_report.get("readinessStatus") == "notRun", "strict status must expose notRun")

    print(
        json.dumps(
            {
                "status": "passed",
                "relaxedCompleted": relaxed_report.get("completed"),
                "strictExitCode": strict.returncode,
                "strictReadinessStatus": strict_report.get("readinessStatus"),
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
