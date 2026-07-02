#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataTimeLetterDispatchReminderSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/time-letter-dispatch-reminder-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-time-letter-dispatch-reminder.png"
RESULT_COPY_PATH="$OUTPUT_DIR/time-letter-dispatch-reminder-smoke-result.json"
COMPLETION_PATTERN="TimeLetterDispatchReminderSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[time-letter-dispatch-reminder-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[time-letter-dispatch-reminder-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[time-letter-dispatch-reminder-smoke] os log tail:" >&2
    tail -80 "$OS_LOG" >&2 || true
  fi
  exit 1
}

INSTALL_OUTPUT_DIR="$OUTPUT_DIR/installable-simulator"
echo "[time-letter-dispatch-reminder-smoke] Building and installing local QA bundle..."
OUTPUT_DIR="$INSTALL_OUTPUT_DIR" \
BUILD_LOG="$BUILD_LOG" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
SIMULATOR_NAME="$SIMULATOR_NAME" \
SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
"$SCRIPT_DIR/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/time-letter-dispatch-reminder-smoke-result.json"
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

echo "[time-letter-dispatch-reminder-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJRunTimeLetterDispatchReminderSmoke > "$RUNTIME_LOG" 2>&1 &
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

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Smoke did not complete."
grep -Eq '"deliveryStatus"[[:space:]]*:[[:space:]]*"delivered"' "$RESULT_FILE" || fail "Delivered status should win over local due state."
grep -Eq '"reminderCount"[[:space:]]*:[[:space:]]*1' "$RESULT_FILE" || fail "Mailbox reminder should be counted once."
grep -Eq '"dueLetterIds"' "$RESULT_FILE" || fail "Result should include dueLetterIds."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[time-letter-dispatch-reminder-smoke] Build log: $BUILD_LOG"
echo "[time-letter-dispatch-reminder-smoke] Runtime log: $RUNTIME_LOG"
echo "[time-letter-dispatch-reminder-smoke] OS log: $OS_LOG"
echo "[time-letter-dispatch-reminder-smoke] Result: $RESULT_COPY_PATH"
echo "[time-letter-dispatch-reminder-smoke] Screenshot: $SCREENSHOT_PATH"
