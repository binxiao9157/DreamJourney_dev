#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataNotificationRuntimeRouteUIQASmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/notification-runtime-route-uiqa-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-notification-runtime-route-uiqa-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/notification-runtime-route-uiqa-smoke-result.json"
COMPLETION_PATTERN="NotificationRuntimeRouteSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[notification-runtime-route-uiqa-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    tail -80 "$OS_LOG" >&2 || true
  fi
  exit 1
}

INSTALL_ENV_PATH="$OUTPUT_DIR/install.env" \
BUILD_LOG="$BUILD_LOG" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
OUTPUT_DIR="$OUTPUT_DIR" \
SCHEME="$SCHEME" \
CONFIGURATION="$CONFIGURATION" \
SIMULATOR_NAME="$SIMULATOR_NAME" \
SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
"$SCRIPT_DIR/run-installable-simulator-uiqa.sh"

# shellcheck source=/dev/null
source "$OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/notification-runtime-route-uiqa-smoke-result.json"
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

echo "[notification-runtime-route-uiqa-smoke] Launching route harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJRunNotificationRuntimeRouteSmoke > "$RUNTIME_LOG" 2>&1 &
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

python3 - "$RESULT_FILE" <<'PY'
import json
import sys

result = json.load(open(sys.argv[1], encoding="utf-8"))

def require(condition, message):
    if not condition:
        raise SystemExit(message)

require(result.get("completed") is True, "route UIQA did not complete")
for key in (
    "timeLetterRouteSelectedArchive",
    "echoRouteSelectedEcho",
    "deepLinkRouteSelectedArchive",
    "crossOwnerRouteIgnored",
    "staleGenerationRouteIgnored",
    "malformedDeepLinkIgnored",
    "pendingRoutesDrained",
):
    require(result.get(key) is True, f"route UIQA assertion failed: {key}")
require(result.get("initialSelectedTabIndex") == 1, "Echo tab should be the neutral initial tab")
require(result.get("finalSelectedTabIndex") == 0, "last valid safe route should select Archive")
require(result.get("validRouteDeliveryCount") == 3, "expected three valid route deliveries")
require(result.get("rejectedRouteCount", 0) >= 3, "expected cross-owner, stale, and malformed rejections")
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[notification-runtime-route-uiqa-smoke] Build log: $BUILD_LOG"
echo "[notification-runtime-route-uiqa-smoke] Runtime log: $RUNTIME_LOG"
echo "[notification-runtime-route-uiqa-smoke] OS log: $OS_LOG"
echo "[notification-runtime-route-uiqa-smoke] Result: $RESULT_COPY_PATH"
echo "[notification-runtime-route-uiqa-smoke] Screenshot: $SCREENSHOT_PATH"
