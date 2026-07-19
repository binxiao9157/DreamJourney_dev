#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataEchoDelayedReplyNotificationSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-echo-delayed-reply-notification-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/echo-delayed-reply-notification-smoke-result.json"
COMPLETION_PATTERN="EchoDelayedReplyNotificationSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[echo-delayed-reply-notification-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[echo-delayed-reply-notification-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[echo-delayed-reply-notification-smoke] os log tail:" >&2
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
RESULT_FILE="$DATA_CONTAINER/Documents/echo-delayed-reply-notification-smoke-result.json"
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

echo "[echo-delayed-reply-notification-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJRunEchoDelayedReplyNotificationSmoke > "$RUNTIME_LOG" 2>&1 &
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
grep -Eq '"delayMinutesInRange"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Delay minutes should stay within PRD range."
grep -Eq '"storedDelayedReply"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Delayed reply should be persisted."
grep -Eq '"localNotificationContractPresent"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Local notification contract changed."
grep -Eq '"restoredWaitingState"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Delayed reply should restore as waiting after app restart."
grep -Eq '"restoredWaitingMinutesInRange"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Restored waiting minutes should stay within remaining countdown range."
grep -Eq '"restoredDelayedReplyIdMatched"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Restored delayed reply should match persisted id."
grep -Eq '"expiredDelayedReplyAwaitingServer"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Expired delayed reply should wait for a server result."
grep -Eq '"expiredDelayedReplyPreserved"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Expired delayed reply should remain locally scoped until a server receipt exists."
grep -Eq '"pendingNotificationMatched"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Pending local notification request should exist."
grep -Eq '"pendingNotificationIdentifierMatched"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Pending local notification identifier should match."
grep -Eq '"pendingNotificationTriggerMatched"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Pending local notification trigger should match."
grep -Eq '"pendingNotificationUserInfoMatched"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Pending local notification userInfo should match delayed reply."
grep -Eq '"trigger"[[:space:]]*:[[:space:]]*"tenRoundBaseline"' "$RESULT_FILE" || fail "Ten-round baseline trigger should be persisted."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[echo-delayed-reply-notification-smoke] Build log: $BUILD_LOG"
echo "[echo-delayed-reply-notification-smoke] Runtime log: $RUNTIME_LOG"
echo "[echo-delayed-reply-notification-smoke] OS log: $OS_LOG"
echo "[echo-delayed-reply-notification-smoke] Result: $RESULT_COPY_PATH"
echo "[echo-delayed-reply-notification-smoke] Screenshot: $SCREENSHOT_PATH"
