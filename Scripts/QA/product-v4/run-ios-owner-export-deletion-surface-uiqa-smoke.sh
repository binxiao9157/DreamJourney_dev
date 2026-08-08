#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-export-deletion-surface-smoke}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
PROFILE_RUNTIME_LOG="$OUTPUT_DIR/profile-runtime.log"
PROFILE_RESULT_COPY_PATH="$OUTPUT_DIR/profile-data-export-status-smoke-result.json"
PROFILE_SCREENSHOT_PATH="$OUTPUT_DIR/03-profile-data-export-status.png"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"

RUN_ID="$RUN_ID" \
OUTPUT_ROOT="$OUTPUT_ROOT" \
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataOwnerExportDeletionSurfaceSmoke}" \
bash "$ROOT_DIR/Scripts/QA/product-v4/run-ios-owner-media-task-status-uiqa-smoke.sh"

# shellcheck disable=SC1090
source "$OUTPUT_DIR/install/install.env"
PROFILE_RESULT_FILE="$DATA_CONTAINER/Documents/profile-data-export-status-smoke-result.json"
rm -f "$PROFILE_RESULT_FILE"

CONSOLE_PID=""
cleanup() {
  [[ -n "$CONSOLE_PID" ]] && kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '[owner-export-deletion-surface-smoke] Launching Profile export status...\n'
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunProfileFamilyPersonaReleaseSmoke \
  DJEnableProfileHiddenBranches \
  DJProfileDataExportStatusSmoke > "$PROFILE_RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$PROFILE_RESULT_FILE" ]]; do
  if (( SECONDS >= deadline )); then
    tail -120 "$PROFILE_RUNTIME_LOG" >&2 || true
    exit 1
  fi
  sleep 1
done

cp "$PROFILE_RESULT_FILE" "$PROFILE_RESULT_COPY_PATH"
python3 - "$PROFILE_RESULT_FILE" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding="utf-8"))
if payload.get("completed") is not True:
    raise SystemExit("Profile data-export status smoke did not complete")
if payload.get("rowVisible") is not True:
    raise SystemExit("Profile data-export row is not visible in QA closed pilot")
if payload.get("rowSubtitle") != "数据副本生成中":
    raise SystemExit("Profile data-export status subtitle drifted")
if payload.get("renderedRowSubtitle") != "数据副本生成中":
    raise SystemExit("Profile data-export status subtitle was not rendered")
if payload.get("profileAttachedToWindow") is not True:
    raise SystemExit("Profile data-export status screen was not attached to the window")
if payload.get("backendNetworkStarted") is not False:
    raise SystemExit("Profile status visual smoke must not call the backend")
if payload.get("persistentExportJobStarted") is not False:
    raise SystemExit("Profile status visual smoke must not create an export job")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$PROFILE_SCREENSHOT_PATH" >/dev/null

printf '[owner-export-deletion-surface-smoke] Profile result: %s\n' "$PROFILE_RESULT_COPY_PATH"
printf '[owner-export-deletion-surface-smoke] Profile screenshot: %s\n' "$PROFILE_SCREENSHOT_PATH"
printf '[owner-export-deletion-surface-smoke] Profile runtime log: %s\n' "$PROFILE_RUNTIME_LOG"
