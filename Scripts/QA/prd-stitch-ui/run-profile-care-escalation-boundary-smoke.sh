#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataProfileCareEscalationBoundarySmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/profile-care-escalation-boundary-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INSTALL_DIR="$OUTPUT_DIR/install"
BUILD_LOG="$INSTALL_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-profile-care-escalation-boundary.png"
RESULT_COPY_PATH="$OUTPUT_DIR/profile-care-escalation-boundary-smoke-result.json"
COMPLETION_PATTERN="ProfileCareEscalationBoundarySmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"

fail() {
  echo "[profile-care-escalation-boundary-smoke] $*" >&2
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[profile-care-escalation-boundary-smoke] runtime log tail:" >&2
    tail -80 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[profile-care-escalation-boundary-smoke] os log tail:" >&2
    tail -80 "$OS_LOG" >&2 || true
  fi
  exit 1
}

echo "[profile-care-escalation-boundary-smoke] Building and installing UIQA app..."
OUTPUT_DIR="$INSTALL_DIR" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
CONFIGURATION=Debug \
SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG UI_QA_SIMULATOR" \
  "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck disable=SC1090
source "$INSTALL_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/profile-care-escalation-boundary-smoke-result.json"
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

echo "[profile-care-escalation-boundary-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJUITestBypassLogin DJRunProfileCareEscalationBoundarySmoke > "$RUNTIME_LOG" 2>&1 &
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
grep -Eq '"schemaVersion"[[:space:]]*:[[:space:]]*"profileCareEscalationDraft.v1"' "$RESULT_FILE" || fail "Schema version changed."
grep -Eq '"deliveryState"[[:space:]]*:[[:space:]]*"draftOnly"' "$RESULT_FILE" || fail "Escalation must remain draft-only."
grep -Eq '"requiresHumanReview"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Escalation must require human review."
grep -Eq '"backendContractConnected"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Backend contact contract must stay disconnected."
grep -Eq '"willContactThirdParty"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Escalation smoke must not contact a third party."
grep -Eq '"allowsEmergencyUse"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Escalation smoke must not claim emergency support."
grep -Eq '"containsRawTranscript"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Escalation smoke must not include raw transcript."
grep -Eq '"profileTabSelected"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Smoke should select the profile tab before screenshot."

sleep 1
xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[profile-care-escalation-boundary-smoke] Build log: $BUILD_LOG"
echo "[profile-care-escalation-boundary-smoke] Runtime log: $RUNTIME_LOG"
echo "[profile-care-escalation-boundary-smoke] OS log: $OS_LOG"
echo "[profile-care-escalation-boundary-smoke] Result: $RESULT_COPY_PATH"
echo "[profile-care-escalation-boundary-smoke] Screenshot: $SCREENSHOT_PATH"
