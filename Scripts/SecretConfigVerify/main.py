#!/usr/bin/env python3
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(".")
INFO_PLIST = ROOT / "DreamJourney/Resources/Info.plist"
LOCAL_CONFIG = "DreamJourney/Resources/LocalConfig.plist"

SENSITIVE_INFO_KEYS = [
    "AMapAPIKey",
    "DeepSeekAPIKey",
    "VolcEngineAPIKey",
    "VoiceCloneAPIKey",
    "VolcEngineRealtimeAPIKey",
    "VolcEngineAppID",
    "VolcEngineAppKey",
    "VolcEngineAppToken",
    "SafetyGuardAPIKey",
]


def fail(message: str) -> None:
    print(f"SecretConfig verification failed: {message}", file=sys.stderr)
    sys.exit(1)


def run_git(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def is_allowed_placeholder(value: object) -> bool:
    if value is None:
        return True
    if not isinstance(value, str):
        return False
    trimmed = value.strip()
    return (
        not trimmed
        or trimmed.startswith("YOUR_")
        or trimmed.startswith("$(")
        or "PLACEHOLDER" in trimmed.upper()
    )


with INFO_PLIST.open("rb") as handle:
    info = plistlib.load(handle)

for key in SENSITIVE_INFO_KEYS:
    if not is_allowed_placeholder(info.get(key)):
        fail(f"{INFO_PLIST}:{key} must be a placeholder or build setting, not a real local secret")

if run_git(["check-ignore", "-q", LOCAL_CONFIG]).returncode != 0:
    fail(f"{LOCAL_CONFIG} must be ignored by git")

if run_git(["ls-files", "--error-unmatch", LOCAL_CONFIG]).returncode == 0:
    fail(f"{LOCAL_CONFIG} must not be tracked")

tracked = run_git(["ls-files", "-z"])
if tracked.returncode != 0:
    fail("unable to list tracked files")

secret_patterns = [
    re.compile(rb"sk-[A-Za-z0-9_-]{16,}"),
]

for raw_path in tracked.stdout.split(b"\0"):
    if not raw_path:
        continue
    path = Path(raw_path.decode("utf-8", errors="ignore"))
    if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".mp4", ".wasm", ".gz", ".framework"}:
        continue
    try:
        data = path.read_bytes()
    except OSError:
        continue
    if b"\0" in data[:4096]:
        continue
    for pattern in secret_patterns:
        if pattern.search(data):
            fail(f"{path} contains a token-shaped secret; move it to ignored LocalConfig.plist or Scheme env")

print("SecretConfig verification passed")
