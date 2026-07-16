#!/usr/bin/env python3
import json
import pathlib
import sys


forbidden_keys = ("token", "credential", "password", "secret", "payload", "body", "content", "phone")


def load(path):
    return json.loads(pathlib.Path(path).read_text())


def validate_keys(value, location="root"):
    if isinstance(value, dict):
        for key, nested in value.items():
            lowered = key.lower()
            if any(forbidden in lowered for forbidden in forbidden_keys):
                raise SystemExit(f"forbidden evidence field at {location}.{key}")
            validate_keys(nested, f"{location}.{key}")
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            validate_keys(nested, f"{location}[{index}]")


def main():
    if len(sys.argv) not in {5, 6}:
        raise SystemExit("usage: evidence.py MODEL UI ARTIFACT_REPORT OUTPUT [BACKEND]")
    model_path, ui_path, artifact_report, output_path = sys.argv[1:5]
    backend_path = sys.argv[5] if len(sys.argv) == 6 else None
    model = load(model_path)
    ui = load(ui_path)
    backend = load(backend_path) if backend_path else None
    evidence = {
        "schemaVersion": 1,
        "workItem": "WI-S0-06-07",
        "status": "passed" if backend else "passedWithoutDeployedG2",
        "build": ui["build"],
        "policy": model["policy"],
        "features": model["features"],
        "routes": model["routes"],
        "deepLinks": ui["deepLinks"],
        "commands": backend["commands"] if backend else [],
        "deployed": {
            "verified": backend is not None,
            "policyVersion": backend.get("policyVersion") if backend else None,
            "hiddenRouteBypassCount": backend["routes"]["hiddenRouteBypassCount"] if backend else None,
        },
        "evidenceFiles": {
            "artifact": pathlib.Path(artifact_report).name,
            "model": pathlib.Path(model_path).name,
            "ui": pathlib.Path(ui_path).name,
            "backend": pathlib.Path(backend_path).name if backend_path else None,
        },
        "externalGates": {"G4": "openDeviceRegression"},
    }
    validate_keys(evidence)
    output = pathlib.Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print("Public Release Scope evidence bundle passed")


if __name__ == "__main__":
    main()
