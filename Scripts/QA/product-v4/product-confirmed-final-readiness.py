#!/usr/bin/env python3
"""Build the PC-E2 readiness report without conflating evidence classes."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import urllib.request


CODE_GATES = (
    "backendFinalClosure",
    "iosFinalClosure",
    "genericIPhoneOSBuild",
)
DEVICE_GATES = (
    "microphonePermissionAndCapture",
    "foregroundBackgroundRecovery",
    "audioPlaybackAndInterruption",
    "photoAndFileImport",
    "apnsArrival",
    "screenshotsAndLogs",
)


def _mapping(value):
    return value if isinstance(value, dict) else {}


def _path(value, *keys):
    current = value
    for key in keys:
        current = _mapping(current).get(key)
    return current


def _external_gates(runtime):
    snapshots = _mapping(runtime.get("capabilitySnapshots"))
    identity = _mapping(_path(runtime, "auth", "identityChallenge"))
    ownership = _mapping(_path(runtime, "auth", "crossAccountPolicy"))
    image = _mapping(runtime.get("archiveImageAnalysis"))
    voice_clone = _mapping(_path(runtime, "voice", "voiceClone"))
    apns = _mapping(_path(runtime, "notifications", "apns"))
    publication_policy = _mapping(
        _path(runtime, "releasePolicy", "publicationVisitorPolicy")
    )
    publication = _mapping(publication_policy.get("publication"))
    visitor = _mapping(publication_policy.get("visitor"))

    storage = _mapping(snapshots.get("ownerTruthMediaStorage"))
    processing = _mapping(snapshots.get("ownerTruthMediaProcessing"))
    image_snapshot = _mapping(snapshots.get("archiveImageAnalysis"))
    voice_snapshot = _mapping(snapshots.get("voiceCloneShell"))
    checks = {
        "productionOTP": (
            identity.get("productionReady") is True,
            str(identity.get("providerMode") or "unavailable"),
        ),
        "ownershipEnforce": (
            ownership.get("productionEnforceReady") is True,
            str(ownership.get("mode") or "unknown"),
        ),
        "privateObjectStorage": (
            storage.get("externalVerified") is True
            and storage.get("providerReady") is True
            and str(storage.get("provider") or "") != "filesystem",
            str(storage.get("reason") or "externalEvidenceMissing"),
        ),
        "mediaProcessing": (
            processing.get("externalVerified") is True
            and processing.get("enabled") is True
            and processing.get("providerReady") is True,
            str(processing.get("reason") or "externalEvidenceMissing"),
        ),
        "imageVisionProvider": (
            image_snapshot.get("externalVerified") is True
            and image.get("supportsVision") is True,
            str(image_snapshot.get("reason") or "externalEvidenceMissing"),
        ),
        "voiceIdentityAndProvider": (
            voice_snapshot.get("externalVerified") is True
            and voice_clone.get("identityEligibilityProviderReady") is True,
            str(voice_clone.get("trainingAdmissionReason") or "externalEvidenceMissing"),
        ),
        "apnsProvider": (
            apns.get("externalVerified") is True
            and apns.get("realProviderReady") is True,
            str(apns.get("reason") or "externalEvidenceMissing"),
        ),
        "publicationVisitorApproval": (
            publication_policy.get("status") == "approved"
            and publication.get("enabled") is True
            and visitor.get("enabled") is True,
            str(publication_policy.get("status") or "externalEvidenceMissing"),
        ),
    }
    return {
        name: {"state": "ready" if ready else "blocked", "reason": reason}
        for name, (ready, reason) in checks.items()
    }


def build_report(runtime, code_results, device_evidence=None, observed_at=None):
    normalized_code = {
        name: {
            "state": "ready" if code_results.get(name) is True else "blocked",
            "reason": "verified" if code_results.get(name) is True else "evidenceMissing",
        }
        for name in CODE_GATES
    }
    external = _external_gates(runtime)
    supplied_device = _mapping(device_evidence)
    device = {
        name: {
            "state": "ready" if supplied_device.get(name) is True else "pending",
            "reason": "verifiedOnDevice" if supplied_device.get(name) is True else "deviceEvidenceMissing",
        }
        for name in DEVICE_GATES
    }
    code_ready = all(item["state"] == "ready" for item in normalized_code.values())
    external_ready = all(item["state"] == "ready" for item in external.values())
    device_ready = all(item["state"] == "ready" for item in device.values())
    release_ready = code_ready and external_ready and device_ready
    timestamp = observed_at or datetime.now(timezone.utc)
    return {
        "schemaVersion": 1,
        "status": "ready" if release_ready else "blocked",
        "releaseDecision": "go" if release_ready else "noGo",
        "observedAt": timestamp.isoformat(),
        "code": {
            "state": "ready" if code_ready else "blocked",
            "gates": normalized_code,
        },
        "externalConfiguration": {
            "state": "ready" if external_ready else "blocked",
            "gates": external,
        },
        "deviceAcceptance": {
            "state": "ready" if device_ready else "pending",
            "gates": device,
        },
        "summary": {
            "codeReadyCount": sum(item["state"] == "ready" for item in normalized_code.values()),
            "codeGateCount": len(normalized_code),
            "externalReadyCount": sum(item["state"] == "ready" for item in external.values()),
            "externalGateCount": len(external),
            "deviceReadyCount": sum(item["state"] == "ready" for item in device.values()),
            "deviceGateCount": len(device),
        },
    }


def _load_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _load_runtime(args):
    if args.runtime_json:
        return _load_json(args.runtime_json)
    if args.runtime_url:
        with urllib.request.urlopen(args.runtime_url, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    raise SystemExit("--runtime-json or --runtime-url is required")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime-json")
    parser.add_argument("--runtime-url")
    parser.add_argument("--device-evidence-json")
    parser.add_argument("--output")
    parser.add_argument(
        "--code-gate",
        action="append",
        default=[],
        choices=CODE_GATES,
    )
    args = parser.parse_args()
    runtime = _load_runtime(args)
    code_results = {name: name in args.code_gate for name in CODE_GATES}
    device = _load_json(args.device_evidence_json) if args.device_evidence_json else None
    report = build_report(runtime, code_results, device)
    serialized = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(serialized, encoding="utf-8")
    print(serialized, end="")


if __name__ == "__main__":
    main()
