#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

SCHEME="${SCHEME:-DreamJourney}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/DerivedDataDigitalHumanRuntimeStubSmoke}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
BUILD_LOG="$OUTPUT_DIR/build.log"
BACKEND_LOG="$OUTPUT_DIR/backend.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
OS_LOG="$OUTPUT_DIR/oslog.log"
RESULT_COPY_PATH="$OUTPUT_DIR/digital-human-runtime-stub-smoke-result.json"
SCREENSHOT_PATH="$OUTPUT_DIR/01-digital-human-runtime-stub.png"
LOCAL_CONFIG_PATH="$ROOT_DIR/DreamJourney/Resources/LocalConfig.plist"
LOCAL_CONFIG_BACKUP_PATH="$OUTPUT_DIR/LocalConfig.plist.backup"
COMPLETION_PATTERN="DigitalHumanRuntimeStubSmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-60}"
BACKEND_PORT="${BACKEND_PORT:-3100}"
DEFAULT_BACKEND_HOST="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"
BACKEND_BIND_HOST="${BACKEND_BIND_HOST:-0.0.0.0}"
BACKEND_BASE_URL="${BACKEND_BASE_URL:-http://$DEFAULT_BACKEND_HOST:$BACKEND_PORT}"
BACKEND_HEALTH_URL="${BACKEND_HEALTH_URL:-http://127.0.0.1:$BACKEND_PORT/health}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[digital-human-runtime-stub-smoke] $*" >&2
  if [[ -f "$BACKEND_LOG" ]]; then
    echo "[digital-human-runtime-stub-smoke] backend log tail:" >&2
    tail -80 "$BACKEND_LOG" >&2 || true
  fi
  if [[ -f "$RUNTIME_LOG" ]]; then
    echo "[digital-human-runtime-stub-smoke] runtime log tail:" >&2
    tail -100 "$RUNTIME_LOG" >&2 || true
  fi
  if [[ -f "$OS_LOG" ]]; then
    echo "[digital-human-runtime-stub-smoke] os log tail:" >&2
    tail -100 "$OS_LOG" >&2 || true
  fi
  exit 1
}

BACKEND_PID=""
CONSOLE_PID=""
OSLOG_PID=""
LOCAL_CONFIG_BACKED_UP=0
cleanup() {
  if [[ -n "$CONSOLE_PID" ]]; then
    kill "$CONSOLE_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$OSLOG_PID" ]]; then
    kill "$OSLOG_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$BACKEND_PID" ]]; then
    kill "$BACKEND_PID" >/dev/null 2>&1 || true
    wait "$BACKEND_PID" >/dev/null 2>&1 || true
  fi
  if [[ "$LOCAL_CONFIG_BACKED_UP" == "1" ]]; then
    cp "$LOCAL_CONFIG_BACKUP_PATH" "$LOCAL_CONFIG_PATH" >/dev/null 2>&1 || true
  else
    rm -f "$LOCAL_CONFIG_PATH"
  fi
}
trap cleanup EXIT

[[ -d "$BACKEND_ROOT" ]] || fail "Backend repo missing at $BACKEND_ROOT"
PYTHON_BIN="${PYTHON_BIN:-$BACKEND_ROOT/.venv/bin/python}"
if [[ ! -x "$PYTHON_BIN" ]]; then
  PYTHON_BIN="python3"
fi

echo "[digital-human-runtime-stub-smoke] Starting memory backend at $BACKEND_BASE_URL..."
(
  cd "$BACKEND_ROOT"
  STORE_BACKEND=memory BACKEND_API_TOKEN= "$PYTHON_BIN" -m uvicorn app.main:app --host "$BACKEND_BIND_HOST" --port "$BACKEND_PORT"
) > "$BACKEND_LOG" 2>&1 &
BACKEND_PID="$!"

deadline=$((SECONDS + 20))
until curl -fsS "$BACKEND_HEALTH_URL" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    fail "Timed out waiting for backend health."
  fi
  sleep 1
done

if [[ -f "$LOCAL_CONFIG_PATH" ]]; then
  cp "$LOCAL_CONFIG_PATH" "$LOCAL_CONFIG_BACKUP_PATH"
  LOCAL_CONFIG_BACKED_UP=1
fi
/usr/bin/python3 <<PY
import plistlib
from pathlib import Path

path = Path("$LOCAL_CONFIG_PATH")
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("wb") as file:
    plistlib.dump(
        {
            "DreamJourneyBackendBaseURL": "$BACKEND_BASE_URL",
            "DreamJourneyBackendAPIToken": "",
        },
        file,
    )
PY

PRIVATE_XCCONFIG="$OUTPUT_DIR/backend-private.xcconfig"
cat > "$PRIVATE_XCCONFIG" <<EOF
DREAMJOURNEY_BACKEND_BASE_URL =
DREAMJOURNEY_BACKEND_API_TOKEN =
EOF

INSTALL_ENV_PATH="$OUTPUT_DIR/install.env" \
BUILD_LOG="$BUILD_LOG" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
OUTPUT_DIR="$OUTPUT_DIR" \
SCHEME="$SCHEME" \
CONFIGURATION="$CONFIGURATION" \
SIMULATOR_NAME="$SIMULATOR_NAME" \
SWIFT_ACTIVE_COMPILATION_CONDITIONS="$SWIFT_ACTIVE_COMPILATION_CONDITIONS" \
XCCONFIG_PATH="$PRIVATE_XCCONFIG" \
"$SCRIPT_DIR/run-installable-simulator-uiqa.sh"

# shellcheck source=/dev/null
source "$OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/digital-human-runtime-stub-smoke-result.json"
rm -f "$RESULT_FILE"

touch "$RUNTIME_LOG" "$OS_LOG"
xcrun simctl spawn "$SIMULATOR_UDID" log stream \
  --style compact \
  --level debug \
  --predicate 'process == "DreamJourney"' > "$OS_LOG" 2>&1 &
OSLOG_PID="$!"
sleep 1

echo "[digital-human-runtime-stub-smoke] Launching runtime stub harness..."
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJRunDigitalHumanRuntimeStubSmoke > "$RUNTIME_LOG" 2>&1 &
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

grep -Eq '"completed"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Runtime stub smoke did not complete."
grep -Eq '"provider"[[:space:]]*:[[:space:]]*"tencent"' "$RESULT_FILE" || fail "Provider should be tencent."
grep -Eq '"providerMode"[[:space:]]*:[[:space:]]*"mockContract"' "$RESULT_FILE" || fail "Provider mode should be mockContract."
grep -Eq '"runtimeProvider"[[:space:]]*:[[:space:]]*"tencent"' "$RESULT_FILE" || fail "Runtime provider should be tencent."
grep -Eq '"runtimeProviderMode"[[:space:]]*:[[:space:]]*"mockContract"' "$RESULT_FILE" || fail "Runtime provider mode should be mockContract."
grep -Eq '"runtimeIsRealSDKBacked"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Runtime stub smoke must not claim real Tencent SDK backing."
grep -Eq '"runtimeFactoryFallbackReason"[[:space:]]*:' "$RESULT_FILE" || fail "Runtime factory fallback reason should be reported."
grep -Eq '"driveMode"[[:space:]]*:[[:space:]]*"streamText"' "$RESULT_FILE" || fail "Drive mode should be streamText."
grep -Eq '"fallbackMode"[[:space:]]*:[[:space:]]*"audioOnly"' "$RESULT_FILE" || fail "Fallback should be audioOnly."
grep -Eq '"audioOnlyFallbackState"[[:space:]]*:[[:space:]]*"degraded"' "$RESULT_FILE" || fail "Audio-only runtime should report degraded."
grep -Eq '"runtimeSpeakingState"[[:space:]]*:[[:space:]]*"speaking' "$RESULT_FILE" || fail "Tencent stub should reach speaking state."
grep -Eq '"runtimeStateAfterFinal"[[:space:]]*:[[:space:]]*"ready"' "$RESULT_FILE" || fail "Tencent stub should return to ready after final chunk."
grep -Eq '"allowInterrupt"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Session policy should allow interrupt."
grep -Eq '"proactiveSpeechAllowed"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Session policy should disallow proactive speech."
grep -Eq '"credentialMode"[[:space:]]*:[[:space:]]*"backend-issued-mock"' "$RESULT_FILE" || fail "Credential mode should be backend-issued-mock."
grep -Eq '"leaseStatus"[[:space:]]*:[[:space:]]*"active"' "$RESULT_FILE" || fail "Session lease should start active."
grep -Eq '"leaseHeartbeatStatus"[[:space:]]*:[[:space:]]*"active"' "$RESULT_FILE" || fail "Session lease heartbeat should succeed."
grep -Eq '"leaseReleaseStatus"[[:space:]]*:[[:space:]]*"released"' "$RESULT_FILE" || fail "Session lease should be released after the smoke."
grep -Eq '"defaultReleaseVisible"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Digital human panel must be visible by default."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[digital-human-runtime-stub-smoke] Build log: $BUILD_LOG"
echo "[digital-human-runtime-stub-smoke] Backend log: $BACKEND_LOG"
echo "[digital-human-runtime-stub-smoke] Runtime log: $RUNTIME_LOG"
echo "[digital-human-runtime-stub-smoke] OS log: $OS_LOG"
echo "[digital-human-runtime-stub-smoke] Result: $RESULT_COPY_PATH"
echo "[digital-human-runtime-stub-smoke] Screenshot: $SCREENSHOT_PATH"
