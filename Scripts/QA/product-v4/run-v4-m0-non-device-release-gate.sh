#!/usr/bin/env bash
set -euo pipefail

# V4 M0 handoff gate: combine the already-scoped backend evidence with the
# iOS product surface, failure, release-boundary, XCTest, and generic iPhoneOS
# checks.  It does not claim real identity-provider or physical-device proof.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-v4-m0-non-device}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/qa/v4-m0-non-device-release-gate}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
STEP_FILE="$OUTPUT_DIR/steps.jsonl"
REPORT_PATH="$OUTPUT_DIR/report.md"
MANIFEST_PATH="$OUTPUT_DIR/manifest.json"

BACKEND_EVIDENCE_PATH="${BACKEND_EVIDENCE_PATH:-}"
REQUIRE_BACKEND_EVIDENCE="${REQUIRE_BACKEND_EVIDENCE:-1}"
RUN_UIQA="${RUN_UIQA:-1}"
RUN_PUBLIC_RELEASE_SCOPE="${RUN_PUBLIC_RELEASE_SCOPE:-1}"
RUN_XCTEST="${RUN_XCTEST:-1}"
RUN_IPHONEOS_GENERIC_BUILD="${RUN_IPHONEOS_GENERIC_BUILD:-1}"

LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}"
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}"
IOS_TEST_DESTINATION="${DJ_IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

[[ -n "$LOCAL_BUNDLE_ID" ]] || {
  printf '%s\n' 'LOCAL_BUNDLE_ID must be set' >&2
  exit 2
}
[[ "$LOCAL_BUNDLE_ID" != "com.gaominge.dreamjourney.app" ]] || {
  printf '%s\n' 'The unified non-device gate must not use the shared default bundle id' >&2
  exit 2
}
[[ -n "$LOCAL_DEVELOPMENT_TEAM" ]] || {
  printf '%s\n' 'LOCAL_DEVELOPMENT_TEAM must be set' >&2
  exit 2
}

mkdir -p "$OUTPUT_DIR/logs"
: > "$STEP_FILE"

record_step() {
  local name="$1"
  local status="$2"
  local log_path="$3"
  STEP_NAME="$name" STEP_STATUS="$status" STEP_LOG_PATH="$log_path" \
    python3 - "$STEP_FILE" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

with open(sys.argv[1], "a", encoding="utf-8") as handle:
    handle.write(json.dumps({
        "name": os.environ["STEP_NAME"],
        "status": os.environ["STEP_STATUS"],
        "log": os.environ["STEP_LOG_PATH"],
        "recordedAt": datetime.now(timezone.utc).isoformat(),
    }, ensure_ascii=False, sort_keys=True) + "\n")
PY
}

run_step() {
  local name="$1"
  shift
  local log_path="$OUTPUT_DIR/logs/${name//[^A-Za-z0-9._-]/_}.log"
  printf '== %s ==\n' "$name"
  if "$@" >"$log_path" 2>&1; then
    record_step "$name" "passed" "$log_path"
  else
    local code=$?
    record_step "$name" "failed" "$log_path"
    tail -80 "$log_path" >&2 || true
    exit "$code"
  fi
}

run_uiqa_step() {
  local name="$1"
  local script_path="$2"
  local derived_data_path="$OUTPUT_DIR/DerivedData-$name"
  run_step "$name" env \
    RUN_ID="$RUN_ID" \
    OUTPUT_ROOT="$OUTPUT_DIR/uiqa/$name" \
    DERIVED_DATA_PATH="$derived_data_path" \
    LOCAL_BUNDLE_ID="$LOCAL_BUNDLE_ID" \
    LOCAL_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
    bash "$script_path"
  # Only delete data this gate created. Logs, result JSON and screenshots live
  # outside this directory and remain part of the evidence bundle.
  rm -rf "$derived_data_path"
}

verify_backend_evidence() {
  [[ -n "$BACKEND_EVIDENCE_PATH" ]] || {
    printf '%s\n' 'BACKEND_EVIDENCE_PATH is required for a complete M0 non-device gate' >&2
    exit 2
  }
  [[ -f "$BACKEND_EVIDENCE_PATH" ]] || {
    printf 'Backend evidence does not exist: %s\n' "$BACKEND_EVIDENCE_PATH" >&2
    exit 2
  }
  python3 - "$BACKEND_EVIDENCE_PATH" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("schemaVersion") != "dreamjourney-v4-m0-non-device-evidence-v1":
    raise SystemExit("backend evidence schema mismatch")
if not payload.get("backendCommit"):
    raise SystemExit("backend evidence must include backendCommit")
if payload.get("status") != "passed":
    raise SystemExit("backend evidence must be complete and passed")
if not all(step.get("status") == "passed" for step in payload.get("steps") or []):
    raise SystemExit("backend evidence contains a non-passing step")
PY
  cp "$BACKEND_EVIDENCE_PATH" "$OUTPUT_DIR/backend-manifest.json"
}

finalize_evidence() {
  local exit_status=$?
  V4_ROOT_DIR="$ROOT_DIR" \
  V4_RUN_ID="$RUN_ID" \
  V4_OUTPUT_DIR="$OUTPUT_DIR" \
  V4_REQUIRE_BACKEND_EVIDENCE="$REQUIRE_BACKEND_EVIDENCE" \
  V4_RUN_UIQA="$RUN_UIQA" \
  V4_RUN_PUBLIC_RELEASE_SCOPE="$RUN_PUBLIC_RELEASE_SCOPE" \
  V4_RUN_XCTEST="$RUN_XCTEST" \
  V4_RUN_IPHONEOS_GENERIC_BUILD="$RUN_IPHONEOS_GENERIC_BUILD" \
  V4_GATE_EXIT_STATUS="$exit_status" \
  python3 - "$STEP_FILE" "$MANIFEST_PATH" "$REPORT_PATH" <<'PY'
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

steps_path = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
report_path = Path(sys.argv[3])
root = Path(os.environ["V4_ROOT_DIR"])
steps = [json.loads(line) for line in steps_path.read_text(encoding="utf-8").splitlines() if line.strip()]
commit = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
configuration = {
    "backendEvidenceRequired": os.environ["V4_REQUIRE_BACKEND_EVIDENCE"] == "1",
    "uiqa": os.environ["V4_RUN_UIQA"] == "1",
    "publicReleaseScope": os.environ["V4_RUN_PUBLIC_RELEASE_SCOPE"] == "1",
    "xctest": os.environ["V4_RUN_XCTEST"] == "1",
    "genericIPhoneOSBuild": os.environ["V4_RUN_IPHONEOS_GENERIC_BUILD"] == "1",
}
complete = all(configuration.values()) and os.environ["V4_GATE_EXIT_STATUS"] == "0"
status = "passed" if complete else ("failed" if os.environ["V4_GATE_EXIT_STATUS"] != "0" else "incomplete")
manifest = {
    "schemaVersion": "dreamjourney-v4-m0-non-device-evidence-v1",
    "runId": os.environ["V4_RUN_ID"],
    "generatedAt": datetime.now(timezone.utc).isoformat(),
    "iosCommit": commit,
    "configuration": configuration,
    "status": status,
    "steps": steps,
    "remainingGates": [
        {
            "kind": "EXTERNAL_BLOCKED",
            "id": "real-identity-provider",
            "detail": "The backend proof uses an explicit fixture-session refresh after confirming the real identity path fails closed.",
        },
        {
            "kind": "DEVICE_REQUIRED",
            "id": "wave-7-physical-device-acceptance",
            "detail": "Microphone, photo permission, foreground/background recovery, notification navigation, and device performance are intentionally not covered here.",
        },
    ],
}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
lines = [
    "# V4 M0 Unified Non-device Release Gate",
    "",
    f"- Run ID: `{manifest['runId']}`",
    f"- iOS commit: `{commit}`",
    f"- Status: `{manifest['status']}`",
    "- Backend evidence: `backend-manifest.json` when required.",
    "",
    "## Passed steps",
]
lines.extend(f"- `{step['name']}`" for step in steps)
lines.extend([
    "",
    "## Remaining gates",
    "- `EXTERNAL_BLOCKED`: real SMS/identity provider validation.",
    "- `DEVICE_REQUIRED`: Wave 7 physical-device acceptance.",
    "",
    f"- Manifest: `{manifest_path.name}`",
])
report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
  return "$exit_status"
}

trap finalize_evidence EXIT

cd "$ROOT_DIR"

if [[ "$REQUIRE_BACKEND_EVIDENCE" == "1" ]]; then
  run_step "backend-evidence" verify_backend_evidence
fi

run_step "ios-git-diff-check" git diff --check

for static_check in \
  Scripts/QA/product-v4/owner-truth-interview-product-boundary-surface-check.py \
  Scripts/QA/product-v4/product-v4-ios-owner-truth-closed-pilot-candidate-review-check.py \
  Scripts/QA/product-v4/product-v4-ios-owner-truth-text-source-capture-check.py \
  Scripts/QA/product-v4/product-v4-ios-owner-media-unified-creation-check.py \
  Scripts/QA/product-v4/product-v4-ios-owner-truth-answer-correction-check.py \
  Scripts/QA/product-v4/product-v4-ios-owner-truth-context-citation-check.py \
  Scripts/QA/product-v4/owner-truth-guided-recommendation-activation-static-check.py
do
  run_step "$(basename "${static_check%.py}")" python3 "$static_check"
done

run_step "account-lease-runtime" bash Scripts/QA/product-v4/run-account-lease-runtime-gate.sh

if [[ "$RUN_XCTEST" == "1" ]]; then
  run_step "owner-truth-xctest" xcodebuild test \
    -workspace "$ROOT_DIR/DreamJourney.xcworkspace" \
    -scheme DreamJourney \
    -configuration Debug \
    -destination "$IOS_TEST_DESTINATION" \
    -only-testing:DreamJourneyTests/OwnerTruthContractsTests \
    -derivedDataPath "$OUTPUT_DIR/DerivedDataOwnerTruthContractsTests" \
    DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER="$LOCAL_BUNDLE_ID" \
    DREAMJOURNEY_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
    CODE_SIGNING_ALLOWED=NO
  rm -rf "$OUTPUT_DIR/DerivedDataOwnerTruthContractsTests"
fi

if [[ "$RUN_UIQA" == "1" ]]; then
  run_uiqa_step "owner-media-unified-creation" Scripts/QA/product-v4/run-ios-owner-media-unified-creation-uiqa-smoke.sh
  run_uiqa_step "natural-input-product" Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-product-surface-smoke.sh
  run_uiqa_step "candidate-review-ready" Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-proposal-review-ready-smoke.sh
  run_uiqa_step "candidate-response-mismatch" Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-confirmation-fail-closed-smoke.sh
  run_uiqa_step "candidate-source-inactive" Scripts/QA/prd-stitch-ui/run-owner-truth-interview-candidate-confirmation-source-inactive-smoke.sh
fi

if [[ "$RUN_PUBLIC_RELEASE_SCOPE" == "1" ]]; then
  run_step "public-release-scope" env \
    RUN_ID="$RUN_ID" \
    OUTPUT_ROOT="$OUTPUT_DIR/public-release-scope" \
    RUN_RELEASE_ARTIFACT=1 \
    RUN_BACKEND_G2=0 \
    BACKEND_ROOT="$ROOT_DIR/../DreamJourneyBackend" \
    bash Scripts/QA/prd-stitch-ui/run-public-release-scope-regression.sh
  rm -rf "$OUTPUT_DIR/public-release-scope/$RUN_ID/DerivedDataReleaseSimulator"
  rm -rf "$OUTPUT_DIR/public-release-scope/$RUN_ID/release-artifact/release-build/DerivedData"
fi

if [[ "$RUN_IPHONEOS_GENERIC_BUILD" == "1" ]]; then
  run_step "iphoneos-generic-build" env \
    RUN_ID="$RUN_ID" \
    OUTPUT_ROOT="$OUTPUT_DIR/iphoneos-generic-build" \
    DERIVED_DATA_PATH="$OUTPUT_DIR/DerivedDataIPhoneOSGenericBuild" \
    LOCAL_BUNDLE_ID="$LOCAL_BUNDLE_ID" \
    LOCAL_DEVELOPMENT_TEAM="$LOCAL_DEVELOPMENT_TEAM" \
    bash Scripts/QA/prd-stitch-ui/run-iphoneos-generic-build.sh
  rm -rf "$OUTPUT_DIR/DerivedDataIPhoneOSGenericBuild"
fi

printf 'V4 M0 unified non-device gate finished: %s\n' "$REPORT_PATH"
