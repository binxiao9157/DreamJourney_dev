#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 16}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataArchiveToEchoSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-archive-to-echo-completed.png"
RESULT_COPY_PATH="$OUTPUT_DIR/archive-to-echo-smoke-result.json"
COMPLETION_PATTERN="ArchiveToEchoSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[archive-to-echo-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[archive-to-echo-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[archive-to-echo-smoke] os log tail:" >&2
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
RESULT_FILE="$DATA_CONTAINER/Documents/archive-to-echo-smoke-result.json"
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

echo "[archive-to-echo-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJRunArchiveToEchoSmoke > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]] && ! grep -q "$COMPLETION_PATTERN" "$RUNTIME_LOG" "$OS_LOG" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    fail "Timed out waiting for $COMPLETION_PATTERN"
  fi
  sleep 1
done

if [[ -s "$RESULT_FILE" ]]; then
  cp "$RESULT_FILE" "$RESULT_COPY_PATH"
  COMPLETION_LINE="$(cat "$RESULT_FILE")"
else
  COMPLETION_LINE="$(grep -h "$COMPLETION_PATTERN" "$RUNTIME_LOG" "$OS_LOG" | tail -1)"
fi
echo "[archive-to-echo-smoke] $COMPLETION_LINE"

if [[ -s "$RESULT_FILE" ]]; then
  grep -Eq '"containsArchiveContext"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Prompt did not include archive context."
  grep -Eq '"availableItemCount"[[:space:]]*:[[:space:]]*1' "$RESULT_FILE" || fail "Analyzed archive item was not available to echo."
  grep -q '相册影像' "$RESULT_FILE" || fail "Expected photo archive entry was not present."
else
  [[ "$COMPLETION_LINE" == *"containsArchiveContext=true"* ]] || fail "Prompt did not include archive context."
  [[ "$COMPLETION_LINE" == *"available=1"* ]] || fail "Analyzed archive item was not available to echo."
  [[ "$COMPLETION_LINE" == *"entries=相册影像"* ]] || fail "Expected photo archive entry was not present."
fi

if grep -q "backend sync failed" "$RUNTIME_LOG" "$OS_LOG" 2>/dev/null; then
  fail "Unexpected backend sync failure appeared during QA smoke."
fi

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[archive-to-echo-smoke] Build log: $BUILD_LOG"
echo "[archive-to-echo-smoke] Runtime log: $RUNTIME_LOG"
echo "[archive-to-echo-smoke] OS log: $OS_LOG"
echo "[archive-to-echo-smoke] Result: $RESULT_COPY_PATH"
echo "[archive-to-echo-smoke] Screenshot: $SCREENSHOT_PATH"
