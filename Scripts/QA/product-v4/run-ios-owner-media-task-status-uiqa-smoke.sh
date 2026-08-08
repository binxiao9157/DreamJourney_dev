#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-media-task-status-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_OUTPUT_DIR="$OUTPUT_DIR/install"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataOwnerMediaTaskStatusSmoke}"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-owner-media-task-status.png"
DETAIL_SCREENSHOT_PATH="$OUTPUT_DIR/02-owner-media-task-deletion-detail.png"
RESULT_COPY_PATH="$OUTPUT_DIR/owner-media-task-status-smoke-result.json"
DETAIL_RESULT_COPY_PATH="$OUTPUT_DIR/owner-media-task-deletion-detail-smoke-result.json"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  printf '[owner-media-task-status-smoke] %s\n' "$*" >&2
  [[ -f "$RUNTIME_LOG" ]] && tail -100 "$RUNTIME_LOG" >&2 || true
  exit 1
}

printf '[owner-media-task-status-smoke] Building and installing UIQA app...\n'
OUTPUT_DIR="$INSTALL_OUTPUT_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
LOCAL_BUNDLE_ID="${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}" \
LOCAL_DEVELOPMENT_TEAM="${LOCAL_DEVELOPMENT_TEAM:-2BTR77V3R8}" \
bash "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/owner-media-task-status-smoke-result.json"
DETAIL_RESULT_FILE="$DATA_CONTAINER/Documents/owner-media-task-deletion-detail-smoke-result.json"
rm -f "$RESULT_FILE" "$DETAIL_RESULT_FILE"

CONSOLE_PID=""
cleanup() {
  [[ -n "$CONSOLE_PID" ]] && kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '[owner-media-task-status-smoke] Launching status preview...\n'
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunOwnerMediaTaskStatusSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]]; do
  (( SECONDS < deadline )) || fail "Timed out waiting for UIQA result"
  sleep 1
done

cp "$RESULT_FILE" "$RESULT_COPY_PATH"
python3 - "$RESULT_FILE" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
expected_statuses = ["云端文件未同步", "文件已同步，处理暂不可用", "已处理", "访问已撤销"]
if payload.get("completed") is not True:
    raise SystemExit("media task status smoke did not complete")
if payload.get("statusTitles") != expected_statuses:
    raise SystemExit("media task statuses drifted")
if sorted(payload.get("retryActions") or []) != ["resumeUpload", "retryDeletion", "retryProcessing"]:
    raise SystemExit("media task retry actions drifted")
if payload.get("actionsEnabled") is not True:
    raise SystemExit("status smoke must render authorized actions")
if payload.get("unavailableReasonVisible") is not False:
    raise SystemExit("authorized status smoke must not render unavailable copy")
if payload.get("detailButtonVisible") is not True:
    raise SystemExit("media task detail route is not visible")
if payload.get("uploadRetryVisible") is not True or payload.get("processingRetryVisible") is not True or payload.get("deletionRetryVisible") is not True:
    raise SystemExit("media task retry actions are not visible")
if payload.get("candidateHandoffVisible") is not True:
    raise SystemExit("processed media must expose the Candidate handoff")
if payload.get("backendNetworkStarted") is not False:
    raise SystemExit("visual smoke must not call the backend")
if payload.get("persistentOwnerTruthWriteStarted") is not False:
    raise SystemExit("visual smoke must not persist Owner Truth data")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null

printf '[owner-media-task-status-smoke] Relaunching deletion detail with provider actions unavailable...\n'
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
: > "$RUNTIME_LOG"
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunOwnerMediaTaskStatusSmoke \
  DJOwnerMediaTaskDeletionDetailSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$DETAIL_RESULT_FILE" ]]; do
  (( SECONDS < deadline )) || fail "Timed out waiting for deletion detail UIQA result"
  sleep 1
done

cp "$DETAIL_RESULT_FILE" "$DETAIL_RESULT_COPY_PATH"
python3 - "$DETAIL_RESULT_FILE" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("completed") is not True:
    raise SystemExit("media deletion detail smoke did not complete")
if payload.get("stateTitle") != "访问已撤销":
    raise SystemExit("deletion detail state drifted")
if payload.get("actionsEnabled") is not False or payload.get("retryVisible") is not False:
    raise SystemExit("unavailable provider must hide deletion retry")
if payload.get("unavailableReasonVisible") is not True:
    raise SystemExit("unavailable provider reason is missing")
if payload.get("providerIdentifierVisible") is not False:
    raise SystemExit("deletion detail exposed a provider identifier")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$DETAIL_SCREENSHOT_PATH" >/dev/null

printf '[owner-media-task-status-smoke] Result: %s\n' "$RESULT_COPY_PATH"
printf '[owner-media-task-status-smoke] Screenshot: %s\n' "$SCREENSHOT_PATH"
printf '[owner-media-task-status-smoke] Detail result: %s\n' "$DETAIL_RESULT_COPY_PATH"
printf '[owner-media-task-status-smoke] Detail screenshot: %s\n' "$DETAIL_SCREENSHOT_PATH"
printf '[owner-media-task-status-smoke] Runtime log: %s\n' "$RUNTIME_LOG"
