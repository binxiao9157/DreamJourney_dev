#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/b6-cold-start-read-recovery}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_OUTPUT_DIR="$OUTPUT_DIR/install"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataB6ColdStartRecovery}"
SEED_LOG="$OUTPUT_DIR/seed-runtime.log"
RECOVER_LOG="$OUTPUT_DIR/recover-runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SEED_SCREENSHOT="$OUTPUT_DIR/01-seed-queued.png"
RECOVER_SCREENSHOT="$OUTPUT_DIR/02-recovered-pending-review.png"
SEED_COPY="$OUTPUT_DIR/b6-cold-start-seed-result.json"
RECOVER_COPY="$OUTPUT_DIR/b6-cold-start-recover-result.json"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[b6-cold-start-recovery] $*" >&2
  [[ -f "$SEED_LOG" ]] && tail -80 "$SEED_LOG" >&2 || true
  [[ -f "$RECOVER_LOG" ]] && tail -80 "$RECOVER_LOG" >&2 || true
  [[ -f "$OS_LOG" ]] && tail -80 "$OS_LOG" >&2 || true
  exit 1
}

wait_for_file() {
  local file="$1"
  local deadline=$((SECONDS + WAIT_TIMEOUT))
  while [[ ! -s "$file" ]]; do
    if (( SECONDS >= deadline )); then
      fail "Timed out waiting for $file"
    fi
    sleep 1
  done
}

echo "[b6-cold-start-recovery] Building isolated simulator app..."
OUTPUT_DIR="$INSTALL_OUTPUT_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}" \
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}" \
bash "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_OUTPUT_DIR/install.env"
SEED_RESULT="$DATA_CONTAINER/Documents/b6-cold-start-seed-result.json"
RECOVER_RESULT="$DATA_CONTAINER/Documents/b6-cold-start-recover-result.json"
rm -f "$SEED_RESULT" "$RECOVER_RESULT"

OSLOG_PID=""
cleanup() {
  [[ -z "$OSLOG_PID" ]] || kill "$OSLOG_PID" >/dev/null 2>&1 || true
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

touch "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream \
  --style compact \
  --level debug \
  --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

echo "[b6-cold-start-recovery] Launching seed process..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunEchoLiveMemoryColdStartRecoverySmoke \
  DJB6ColdStartPhase=seed > "$SEED_LOG" 2>&1 &
wait_for_file "$SEED_RESULT"
cp "$SEED_RESULT" "$SEED_COPY"
xcrun simctl io "$SIMULATOR_UDID" screenshot "$SEED_SCREENSHOT" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID"
sleep 1

echo "[b6-cold-start-recovery] Launching recovery process with preserved data..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunEchoLiveMemoryColdStartRecoverySmoke \
  DJB6ColdStartPhase=recover > "$RECOVER_LOG" 2>&1 &
wait_for_file "$RECOVER_RESULT"
cp "$RECOVER_RESULT" "$RECOVER_COPY"
xcrun simctl io "$SIMULATOR_UDID" screenshot "$RECOVER_SCREENSHOT" >/dev/null

python3 - "$SEED_COPY" "$RECOVER_COPY" <<'PY'
import json
import sys

seed = json.load(open(sys.argv[1], encoding="utf-8"))
recover = json.load(open(sys.argv[2], encoding="utf-8"))

checks = {
    "seed completed": seed.get("completed") is True,
    "durable coordinate": seed.get("followUpRecordPresent") is True,
    "normal capture append": seed.get("appendPOSTCount") == 1,
    "normal capture end": seed.get("endPOSTCount") == 1,
    "normal capture ack": seed.get("ackPOSTCount") == 1,
    "normal capture admit": seed.get("admitPOSTCount") == 1,
    "recovery completed": recover.get("completed") is True,
    "different process": seed.get("processIdentifier") != recover.get("processIdentifier"),
    "same workflow": seed.get("workflowHash") == recover.get("workflowHash"),
    "automatic UI terminal": recover.get("statusIdentifier") == "echoLiveMemoryRecoveryPendingReview",
    # The launch fixture publishes one legal same-scope lease successor while
    # the Echo page is becoming active. That may fence the first read and issue
    # one replacement read; the workflow must still remain single-flight and
    # bounded rather than requiring an artificial exactly-once transport count.
    "bounded status GET": 1 <= recover.get("statusGETCount", 0) <= 2,
    "read-only recovery client": recover.get("recoveryClientIsReadOnly") is True,
    "actual backend adapter": recover.get("recoveryAdapter") == "DreamJourneyBackendClient",
    "trace present": recover.get("tracePresent") is True,
    "no microphone": recover.get("microphoneStarted") is False,
    "no new capture": recover.get("newCaptureCreated") is False,
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("failed checks: " + ", ".join(failed))
print(json.dumps({"checks": checks, "seed": seed, "recover": recover}, ensure_ascii=False, indent=2))
PY

if grep -E 'appendOwnerTruthInterview|endOwnerTruthInterview|acknowledgeOwnerTruthInterview|admitOwnerTruthInterview' "$RECOVER_LOG" "$OS_LOG" >/dev/null 2>&1; then
  fail "Recovery process emitted an interview write marker"
fi

echo "[b6-cold-start-recovery] PASS"
echo "[b6-cold-start-recovery] Seed result: $SEED_COPY"
echo "[b6-cold-start-recovery] Recovery result: $RECOVER_COPY"
echo "[b6-cold-start-recovery] Recovery screenshot: $RECOVER_SCREENSHOT"
