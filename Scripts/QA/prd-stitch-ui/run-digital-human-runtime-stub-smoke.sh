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
UIQA_IDENTITY_CHALLENGE_CODE="${UIQA_IDENTITY_CHALLENGE_CODE:-uiqa-runtime-stub-code}"
UIQA_IDENTITY_BINDING_HMAC_KEY="uiqa-runtime-stub-identity-binding-key-0123456789"

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
  STORE_BACKEND=memory \
    BACKEND_API_TOKEN= \
    IDENTITY_BINDING_HMAC_KEY="$UIQA_IDENTITY_BINDING_HMAC_KEY" \
    IDENTITY_CHALLENGE_ADAPTER=synthetic \
    IDENTITY_CHALLENGE_SYNTHETIC_CODE="$UIQA_IDENTITY_CHALLENGE_CODE" \
    UIQA_DIGITAL_HUMAN_RUNTIME_STUB=1 \
    BACKEND_BIND_HOST="$BACKEND_BIND_HOST" \
    BACKEND_PORT="$BACKEND_PORT" \
    "$PYTHON_BIN" -c '
import os
import uvicorn

import app.main as main
from app.services.release_policy import ReleasePolicyCommandGate

# This process exists only for the runtime-stub smoke. Let the test traverse
# the authenticated server boundary and assert the scoped-broker fallback;
# production policy remains closed to this feature by default.
visible_features = set(main.RELEASE_POLICY_SERVICE._CLOSED_PILOT_OWNER_VISIBLE)
visible_features.add("digitalHumanLivePanel")
main.RELEASE_POLICY_SERVICE._CLOSED_PILOT_OWNER_VISIBLE = visible_features
main.RELEASE_POLICY_COMMAND_GATE = ReleasePolicyCommandGate(main.RELEASE_POLICY_SERVICE)

uvicorn.run(
    main.app,
    host=os.environ["BACKEND_BIND_HOST"],
    port=int(os.environ["BACKEND_PORT"]),
)
'
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
        },
        file,
    )
PY

PRIVATE_XCCONFIG="$OUTPUT_DIR/backend-private.xcconfig"
cat > "$PRIVATE_XCCONFIG" <<EOF
DREAMJOURNEY_BACKEND_BASE_URL =
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
  DJRunDigitalHumanRuntimeStubSmoke \
  "DJUIQAIdentityChallengeCode=$UIQA_IDENTITY_CHALLENGE_CODE" > "$RUNTIME_LOG" 2>&1 &
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
grep -Eq '"boundaryState"[[:space:]]*:[[:space:]]*"scopedBrokerRequired"' "$RESULT_FILE" || fail "Runtime must report the scoped broker boundary."
grep -Eq '"providerMode"[[:space:]]*:[[:space:]]*"blockedUntilScopedBroker"' "$RESULT_FILE" || fail "Provider mode should remain blocked until a scoped broker exists."
grep -Eq '"runtimeProvider"[[:space:]]*:[[:space:]]*"none"' "$RESULT_FILE" || fail "Blocked mode must not create a digital-human runtime."
grep -Eq '"runtimeIsRealSDKBacked"[[:space:]]*:[[:space:]]*false' "$RESULT_FILE" || fail "Blocked mode must not claim real Tencent SDK backing."
grep -Eq '"fallbackMode"[[:space:]]*:[[:space:]]*"textOnly"' "$RESULT_FILE" || fail "Blocked mode must fall back to text-only Echo."
grep -Eq '"visibleFallback"[[:space:]]*:[[:space:]]*true' "$RESULT_FILE" || fail "Blocked mode must render the explicit fallback state."
grep -Eq '"visibleFallbackDetail"[[:space:]]*:[[:space:]]*"数字人暂不可用，已回到普通回响"' "$RESULT_FILE" || fail "Fallback detail must remain explicit."
grep -Eq '"audioOwner"[[:space:]]*:[[:space:]]*"(volcengineLocalTTS|fallbackMuted)"' "$RESULT_FILE" || fail "Blocked mode must not retain Tencent as the audio owner."

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[digital-human-runtime-stub-smoke] Build log: $BUILD_LOG"
echo "[digital-human-runtime-stub-smoke] Backend log: $BACKEND_LOG"
echo "[digital-human-runtime-stub-smoke] Runtime log: $RUNTIME_LOG"
echo "[digital-human-runtime-stub-smoke] OS log: $OS_LOG"
echo "[digital-human-runtime-stub-smoke] Result: $RESULT_COPY_PATH"
echo "[digital-human-runtime-stub-smoke] Screenshot: $SCREENSHOT_PATH"
