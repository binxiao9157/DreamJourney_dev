#!/usr/bin/env python3
"""Contract check for the V4 unified non-device lane evidence runner."""

from __future__ import annotations

import json
import os
from pathlib import Path
import runpy
import tempfile


ROOT = Path(__file__).resolve().parents[3]
MODULE = runpy.run_path(str(ROOT / "Scripts/QA/product-v4/v4_non_device_release_lanes.py"))

load_registry = MODULE["load_registry"]
main = MODULE["main"]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


registry = ROOT / "Scripts/QA/product-v4/v4-non-device-release-lanes-v1.json"
backend_root = ROOT.parent / "DreamJourneyBackend"
lanes = load_registry(path=registry, ios_root=ROOT, backend_root=backend_root)
require(tuple(item["id"] for item in lanes) == ("m0", "stage2", "m1", "m2"), "lane order changed")
require(lanes[0]["defaultState"] == "publicCore", "M0 scope changed")
require(all(item["defaultOff"] for item in lanes[1:]), "extension lanes must remain default-off")
require(all(item["remainingGates"] for item in lanes), "all lanes require external/device disclosure")
command_ids = {
    command["id"]
    for lane in lanes
    for command in lane["commands"]
}
for required in (
    "backend-full-contract",
    "backend-provider-effect-reconciliation",
    "backend-runtime-auto-disable",
    "ios-owner-export-deletion",
    "ios-generic-iphoneos-build",
    "backend-media-provider-matrix",
    "backend-otp-provider-boundary",
    "backend-voice-clone-provider-lifecycle",
    "backend-voice-clone-echo-binding",
    "ios-voice-clone-provider-lifecycle",
    "ios-voice-clone-echo-binding",
    "backend-publication-formal-api",
    "backend-publication-visitor-access",
    "ios-publication-default-off-shell",
):
    require(required in command_ids, f"unified runner no longer covers {required}")

with tempfile.TemporaryDirectory() as temp_dir:
    output_root = Path(temp_dir) / "evidence"
    result = main(
        [
            "--output-root",
            str(output_root),
            "--run-id",
            "contract",
            "--lanes",
            "m1,m2",
        ]
    )
    require(result == 0, "dry-run must not execute any lane")
    manifest = json.loads((output_root / "contract/manifest.json").read_text(encoding="utf-8"))
    require(manifest["schemaVersion"] == "dreamjourney-v4-unified-non-device-evidence-v1", "schema changed")
    require(manifest["mode"] == "dryRun", "default runner mode must be dry-run")
    require(manifest["executionStatus"] == "notRun", "dry-run must remain notRun")
    require(manifest["releaseDecision"] == "NO_GO", "non-device evidence must never approve release")
    require(
        manifest["conclusions"]["nonDevice"]["status"] == "NON_DEVICE_NOT_RUN",
        "dry-run must not claim code complete",
    )
    require(
        manifest["conclusions"]["externalProvider"]["status"] == "WAITING_EXTERNAL_PROVIDER",
        "external provider gates must remain explicit",
    )
    require(
        manifest["conclusions"]["trueDevice"]["status"] == "WAITING_TRUE_DEVICE",
        "true-device gates must remain explicit",
    )
    require([item["id"] for item in manifest["lanes"]] == ["m1", "m2"], "lane filter changed")
    require(
        all(command["status"] == "notRun" for lane in manifest["lanes"] for command in lane["commands"]),
        "dry-run executed a command",
    )
    serialized = json.dumps(manifest, sort_keys=True).lower()
    for forbidden in ("backend_api_token", "access_token", "secret", "password"):
        require(forbidden not in serialized, f"manifest must not contain {forbidden}")

with tempfile.TemporaryDirectory() as temp_dir:
    temp = Path(temp_dir)
    ios_root = temp / "ios"
    backend_root = temp / "backend"
    (ios_root / "Scripts").mkdir(parents=True)
    backend_root.mkdir()
    (ios_root / "Scripts/pass.sh").write_text(
        "#!/usr/bin/env bash\nprintf 'token=%s\\n' \"$TEST_TOKEN\"\n",
        encoding="utf-8",
    )
    fixture = {
        "schemaVersion": "dreamjourney-v4-non-device-lane-registry-v1",
        "lanes": [],
    }
    for index, lane_id in enumerate(("m0", "stage2", "m1", "m2")):
        fixture["lanes"].append(
            {
                "id": lane_id,
                "title": lane_id,
                "defaultState": "publicCore" if index == 0 else "closedPilotDefaultOff",
                "defaultOff": index != 0,
                "requiredEnvironment": [],
                "commands": [
                    {
                        "id": "pass",
                        "repo": "ios",
                        "argv": ["bash", "Scripts/pass.sh"],
                        "timeoutSeconds": 10,
                    }
                ],
                "remainingGates": [{"kind": "DEVICE_REQUIRED", "id": f"{lane_id}Device"}],
            }
        )
    fixture_path = temp / "registry.json"
    fixture_path.write_text(json.dumps(fixture), encoding="utf-8")
    previous_token = os.environ.get("TEST_TOKEN")
    os.environ["TEST_TOKEN"] = "demo-super-secret-token"
    try:
        result = main(
            [
                "--registry",
                str(fixture_path),
                "--ios-root",
                str(ios_root),
                "--backend-root",
                str(backend_root),
                "--output-root",
                str(temp / "execute-evidence"),
                "--run-id",
                "execute",
                "--execute",
            ]
        )
    finally:
        if previous_token is None:
            os.environ.pop("TEST_TOKEN", None)
        else:
            os.environ["TEST_TOKEN"] = previous_token
    require(result == 0, "fixture execution should pass")
    executed_manifest = json.loads(
        (temp / "execute-evidence/execute/manifest.json").read_text(encoding="utf-8")
    )
    require(
        executed_manifest["conclusions"]["nonDevice"]["status"] == "NON_DEVICE_CODE_COMPLETE",
        "passing execution must emit the code-complete conclusion",
    )
    log = (temp / "execute-evidence/execute/m0/pass/command.log").read_text(encoding="utf-8")
    require("demo-super-secret-token" not in log, "command log leaked configured token")
    require("[REDACTED:TEST_TOKEN]" in log, "command log redaction drifted")
    require(
        not (temp / "execute-evidence/execute/m0/pass/command.raw.log").exists(),
        "raw command output must not remain in evidence",
    )

runner = (ROOT / "Scripts/QA/product-v4/run-v4-unified-non-device-evidence.sh").read_text(encoding="utf-8")
require("v4_non_device_release_lanes.py" in runner, "shell entrypoint drifted")
print("V4 unified non-device lane evidence contract check passed")
