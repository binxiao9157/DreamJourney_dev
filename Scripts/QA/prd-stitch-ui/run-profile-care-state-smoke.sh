#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataProfileCareStateSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/profile-care-state-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_DIR="$OUTPUT_DIR/install"
BUILD_LOG="$INSTALL_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-profile-care-state-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/profile-care-state-smoke-result.json"
COMPLETION_PATTERN="ProfileCareStateSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"

fail() {
  echo "[profile-care-state-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[profile-care-state-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[profile-care-state-smoke] os log tail:" >&2
    tail -80 "$OS_LOG" >&2 || true
  fi
  exit 1
}

echo "[profile-care-state-smoke] Building and installing UIQA app..."
OUTPUT_DIR="$INSTALL_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
CONFIGURATION=Debug \
SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG UI_QA_SIMULATOR" \
  "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/profile-care-state-smoke-result.json"
rm -f "$RESULT_FILE"

CONSOLE_PID=""
OSLOG_PID=""
cleanup() {
  if [[ -n "$CONSOLE_PID" ]]; then
    kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$OSLOG_PID" ]]; then
    kill "$OSLOG_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

touch "$RUNTIME_LOG" "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream \
  --style compact \
  --level debug \
  --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

echo "[profile-care-state-smoke] Launching care state harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJUITestBypassLogin \
  DJRunProfileCareStateSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]] && ! grep -q "$COMPLETION_PATTERN" "$RUNTIME_LOG" "$OS_LOG" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    fail "Timed out waiting for $COMPLETION_PATTERN"
  fi
  sleep 1
done

[[ -s "$RESULT_FILE" ]] || fail "Result file was not written."
cp "$RESULT_FILE" "$RESULT_COPY_PATH"
cat "$RESULT_FILE"
echo

python3 - "$RESULT_COPY_PATH" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    result = json.load(handle)

if result.get("completed") is not True:
    raise SystemExit(f"Profile care state smoke did not complete: {result}")
if result.get("profileTabSelected") is not True:
    raise SystemExit(f"Profile tab should be selected: {result}")

states = result.get("states") or []
profile_states = {state.get("profileState") for state in states}
dashboard_states = {
    (state.get("dashboard") or {}).get("dashboardState")
    for state in states
}
expected = {"profileCareStateEmpty", "profileCareStateStale", "profileCareStateFailed"}
if profile_states != expected:
    raise SystemExit(f"Profile states mismatch: {profile_states}")
if dashboard_states != expected:
    raise SystemExit(f"Dashboard states mismatch: {dashboard_states}")
for state in states:
    if state.get("profileRetryActionTitle") != "重新同步":
        raise SystemExit(f"profile retry title missing: {state}")
    if state.get("profileRetryVisible") is not True:
        raise SystemExit(f"profile retry should be visible: {state}")
    dashboard = state.get("dashboard") or {}
    if dashboard.get("dashboardActionTitle") != "重新同步":
        raise SystemExit(f"dashboard action title missing: {state}")
    if dashboard.get("dashboardHasStateCard") is not True:
        raise SystemExit(f"dashboard state card missing: {state}")
PY

sleep 1
xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[profile-care-state-smoke] Build log: $BUILD_LOG"
echo "[profile-care-state-smoke] Runtime log: $RUNTIME_LOG"
echo "[profile-care-state-smoke] OS log: $OS_LOG"
echo "[profile-care-state-smoke] Result: $RESULT_COPY_PATH"
echo "[profile-care-state-smoke] Screenshot: $SCREENSHOT_PATH"
