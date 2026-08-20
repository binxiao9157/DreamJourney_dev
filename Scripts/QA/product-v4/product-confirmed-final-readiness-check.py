#!/usr/bin/env python3
from datetime import datetime, timezone
import importlib.util
from pathlib import Path


SCRIPT = Path(__file__).with_name("product-confirmed-final-readiness.py")
SPEC = importlib.util.spec_from_file_location("pc_e2_readiness", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def runtime(*, ready):
    return {
        "capabilitySnapshots": {
            "ownerTruthMediaStorage": {
                "externalVerified": ready,
                "providerReady": ready,
                "provider": "cos" if ready else "filesystem",
                "reason": "ready" if ready else "externalEvidenceMissing",
            },
            "ownerTruthMediaProcessing": {
                "externalVerified": ready,
                "enabled": ready,
                "providerReady": ready,
                "reason": "ready" if ready else "workerDisabled",
            },
            "archiveImageAnalysis": {
                "externalVerified": ready,
                "reason": "ready" if ready else "providerVisionUnsupported",
            },
            "voiceCloneShell": {
                "externalVerified": ready,
            },
        },
        "auth": {
            "identityChallenge": {
                "productionReady": ready,
                "providerMode": "production" if ready else "testAllowlist",
            },
            "crossAccountPolicy": {
                "productionEnforceReady": ready,
                "mode": "enforce" if ready else "shadow",
            },
        },
        "archiveImageAnalysis": {"supportsVision": ready},
        "voice": {
            "voiceClone": {
                "identityEligibilityProviderReady": ready,
                "trainingAdmissionReason": "ready" if ready else "identityLivenessProviderUnavailable",
            }
        },
        "notifications": {
            "apns": {
                "externalVerified": ready,
                "realProviderReady": ready,
                "reason": "ready" if ready else "apnsDisabled",
            }
        },
        "releasePolicy": {
            "publicationVisitorPolicy": {
                "status": "approved" if ready else "externalBlocked",
                "publication": {"enabled": ready},
                "visitor": {"enabled": ready},
            }
        },
    }


all_code = {name: True for name in MODULE.CODE_GATES}
instant = datetime(2026, 8, 20, tzinfo=timezone.utc)
blocked = MODULE.build_report(runtime(ready=False), all_code, observed_at=instant)
assert blocked["code"]["state"] == "ready"
assert blocked["externalConfiguration"]["state"] == "blocked"
assert blocked["deviceAcceptance"]["state"] == "pending"
assert blocked["releaseDecision"] == "noGo"

device = {name: True for name in MODULE.DEVICE_GATES}
ready = MODULE.build_report(runtime(ready=True), all_code, device, observed_at=instant)
assert ready["code"]["state"] == "ready"
assert ready["externalConfiguration"]["state"] == "ready"
assert ready["deviceAcceptance"]["state"] == "ready"
assert ready["releaseDecision"] == "go"

missing_code = dict(all_code)
missing_code["genericIPhoneOSBuild"] = False
blocked_code = MODULE.build_report(runtime(ready=True), missing_code, device, observed_at=instant)
assert blocked_code["code"]["state"] == "blocked"
assert blocked_code["releaseDecision"] == "noGo"

print("PC-E2 readiness evidence-class separation check passed")
