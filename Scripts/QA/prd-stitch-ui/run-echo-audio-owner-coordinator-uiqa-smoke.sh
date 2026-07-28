#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS="${SWIFT_ACTIVE_COMPILATION_CONDITIONS:-DEBUG UI_QA_SIMULATOR}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataEchoAudioOwnerCoordinatorSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/echo-audio-owner-coordinator-uiqa-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
SCREENSHOT_PATH="$OUTPUT_DIR/01-echo-audio-owner-coordinator-uiqa-smoke.png"
RESULT_COPY_PATH="$OUTPUT_DIR/echo-audio-owner-coordinator-smoke-result.json"
REPORT_PATH="$OUTPUT_DIR/report.md"
COMPLETION_PATTERN="EchoAudioOwnerCoordinatorSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[echo-audio-owner-coordinator-uiqa-smoke] $*" >&2
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
RESULT_FILE="$DATA_CONTAINER/Documents/echo-audio-owner-coordinator-smoke-result.json"
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

echo "[echo-audio-owner-coordinator-uiqa-smoke] Launching auto-run harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" DJRunEchoAudioOwnerCoordinatorSmoke > "$RUNTIME_LOG" 2>&1 &
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

for required in \
  completed \
  captureAcquired \
  tencentPreemptedCapture \
  staleCaptureReleaseIgnored \
  captureRestored \
  tencentFailurePreservedCapture \
  staleRoleReleaseIgnored; do
  grep -Eq "\"$required\"[[:space:]]*:[[:space:]]*true" "$RESULT_FILE" \
    || fail "Smoke assertion failed: $required"
done

grep -Eq '"finalOwner"[[:space:]]*:[[:space:]]*"none"' "$RESULT_FILE" \
  || fail "Smoke should release the injected coordinator lease"
grep -Eq '"transitionCount"[[:space:]]*:[[:space:]]*[1-9]' "$RESULT_FILE" \
  || fail "Smoke should record coordinator transitions"
grep -Eq '"voiceStatusText"[[:space:]]*:[[:space:]]*"音频归属校验完成"' "$RESULT_FILE" \
  || fail "Smoke should render its QA completion status"

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

cat > "$REPORT_PATH" <<EOF
# Echo Audio Owner Coordinator UIQA Smoke

Run ID: \`$RUN_ID\`

## Scope

- Simulator-only injected audio-session driver.
- No microphone, provider session, Tencent SDK, or system AVAudioSession side effect.
- Verifies capture -> Tencent preemption -> capture recovery, failed Tencent activation preservation, and stale role-release rejection.

## Evidence

- Bundle ID: \`$BUNDLE_ID\`
- Simulator: \`$SIMULATOR_UDID\`
- Result JSON: \`echo-audio-owner-coordinator-smoke-result.json\`
- Screenshot: \`01-echo-audio-owner-coordinator-uiqa-smoke.png\`
- Build log: \`build.log\`
- Runtime log: \`runtime.log\`
- OS log: \`oslog.log\`
EOF

echo "[echo-audio-owner-coordinator-uiqa-smoke] Build log: $BUILD_LOG"
echo "[echo-audio-owner-coordinator-uiqa-smoke] Runtime log: $RUNTIME_LOG"
echo "[echo-audio-owner-coordinator-uiqa-smoke] OS log: $OS_LOG"
echo "[echo-audio-owner-coordinator-uiqa-smoke] Result: $RESULT_COPY_PATH"
echo "[echo-audio-owner-coordinator-uiqa-smoke] Screenshot: $SCREENSHOT_PATH"
