#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/real_device_acceptance_verify.sh"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"RealDeviceAcceptance verification failed: {message}", file=sys.stderr)
        sys.exit(1)


require(SCRIPT.exists(), "real-device acceptance verifier script should exist")

script = SCRIPT.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

for fragment in [
    "set -euo pipefail",
    "Usage:",
    "EVIDENCE_DIR",
    "RealDeviceNoDemoStateVerify/main.py",
    "--strict",
    "Real device acceptance evidence verified",
]:
    require(fragment in script, f"verifier script missing {fragment!r}")

require(
    "RealDeviceAcceptanceVerify/main.py" in phase1,
    "phase1 verification should include the real-device acceptance script gate",
)

print("RealDeviceAcceptance verification passed")
