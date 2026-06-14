#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
SMOKE = ROOT / "Scripts/BackendAuthenticatedSmoke/main.py"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def fail(message: str) -> None:
    print(f"BackendAuthenticatedSmoke contract verification failed: {message}", file=sys.stderr)
    sys.exit(1)


if not SMOKE.exists():
    fail("Scripts/BackendAuthenticatedSmoke/main.py should exist")

smoke = SMOKE.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

checks = [
    (
        "smoke should self-test FastAPI token enforcement without external network",
        "run_self_test" in smoke and "TestClient(app)" in smoke and "BACKEND_API_TOKEN" in smoke,
    ),
    (
        "smoke should prove /health stays public",
        '"/health"' in smoke and "health" in smoke and "200" in smoke,
    ),
    (
        "smoke should prove /config/runtime requires token when BACKEND_API_TOKEN is set",
        '"/config/runtime"' in smoke and "401" in smoke and "Authorization" in smoke,
    ),
    (
        "smoke should support authenticated remote smoke with env-provided URL and token",
        "DREAMJOURNEY_BACKEND_BASE_URL" in smoke and "DREAMJOURNEY_BACKEND_API_TOKEN" in smoke,
    ),
    (
        "smoke should verify runtime response is redacted",
        "assert_no_secret_leaks" in smoke and "assert_runtime_shape" in smoke and "capabilities" in smoke,
    ),
    (
        "phase1 verification should include the authenticated backend smoke",
        "BackendAuthenticatedSmoke/main.py" in phase1,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"- {message}", file=sys.stderr)
    fail(f"{len(failed)} contract check(s) failed")

print("BackendAuthenticatedSmoke contract verification passed")
