#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$WORKSPACE_ROOT/DreamJourneyBackend}"

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
BACKEND_PORT="${BACKEND_PORT:-3112}"
BACKEND_BASE_URL="${BACKEND_BASE_URL:-http://127.0.0.1:$BACKEND_PORT}"
BACKEND_HEALTH_URL="${BACKEND_HEALTH_URL:-http://127.0.0.1:$BACKEND_PORT/health}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/product-v4/identity-challenge-login-recovery/$RUN_ID}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/tmp/visual-qa/product-v4/DerivedDataIdentityChallengeLoginRecovery}"
BUILD_LOG="$OUTPUT_DIR/build.log"
BACKEND_LOG="$OUTPUT_DIR/backend.log"
RUNTIME_LOG="$OUTPUT_DIR/runtime.log"
RESULT_COPY_PATH="$OUTPUT_DIR/identity-challenge-login-recovery-smoke-result.json"
SCREENSHOT_PATH="$OUTPUT_DIR/01-identity-challenge-login-recovery.png"
LOCAL_CONFIG_PATH="$ROOT_DIR/DreamJourney/Resources/LocalConfig.plist"
LOCAL_CONFIG_BACKUP_PATH="$OUTPUT_DIR/LocalConfig.plist.backup"
UIQA_CODE="${UIQA_IDENTITY_CHALLENGE_CODE:-uiqa-login-recovery-code}"
UIQA_HMAC_KEY="uiqa-login-recovery-hmac-key-0123456789abcdef"
COMPLETION_PATTERN="IdentityChallengeLoginRecoverySmoke completed"
LOG_WAIT_TIMEOUT="${LOG_WAIT_TIMEOUT:-45}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

fail() {
  echo "[identity-challenge-login-recovery] $*" >&2
  for log in "$BACKEND_LOG" "$RUNTIME_LOG"; do
    if [[ -f "$log" ]]; then
      echo "[identity-challenge-login-recovery] $(basename "$log") tail:" >&2
      tail -80 "$log" >&2 || true
    fi
  done
  exit 1
}

BACKEND_PID=""
CONSOLE_PID=""
LOCAL_CONFIG_BACKED_UP=0
cleanup() {
  if [[ -n "$CONSOLE_PID" ]]; then
    kill "$CONSOLE_PID" >/dev/null 2>&1 || true
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

(
  cd "$BACKEND_ROOT"
  ENVIRONMENT=development \
    STORE_BACKEND=memory \
    BACKEND_API_TOKEN= \
    IDENTITY_BINDING_HMAC_KEY="$UIQA_HMAC_KEY" \
    IDENTITY_BINDING_HMAC_KEY_VERSION=v1 \
    IDENTITY_CHALLENGE_ADAPTER=synthetic \
    IDENTITY_CHALLENGE_SYNTHETIC_CODE="$UIQA_CODE" \
    AUTH_LEGACY_PHONE_LOGIN_ENABLED=false \
    BACKEND_BIND_HOST=127.0.0.1 \
    BACKEND_PORT="$BACKEND_PORT" \
    "$PYTHON_BIN" -m uvicorn app.main:app \
      --host 127.0.0.1 \
      --port "$BACKEND_PORT"
) > "$BACKEND_LOG" 2>&1 &
BACKEND_PID="$!"

deadline=$((SECONDS + 20))
until curl -fsS "$BACKEND_HEALTH_URL" >/dev/null 2>&1; do
  if (( SECONDS >= deadline )); then
    fail "Timed out waiting for local backend health"
  fi
  sleep 1
done

if [[ -f "$LOCAL_CONFIG_PATH" ]]; then
  cp "$LOCAL_CONFIG_PATH" "$LOCAL_CONFIG_BACKUP_PATH"
  LOCAL_CONFIG_BACKED_UP=1
fi
python3 - "$LOCAL_CONFIG_PATH" "$BACKEND_BASE_URL" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
with path.open("wb") as output:
    plistlib.dump({"DreamJourneyBackendBaseURL": sys.argv[2]}, output)
PY

PRIVATE_XCCONFIG="$OUTPUT_DIR/backend-private.xcconfig"
printf 'DREAMJOURNEY_BACKEND_BASE_URL =\n' > "$PRIVATE_XCCONFIG"

INSTALL_ENV_PATH="$OUTPUT_DIR/install.env" \
BUILD_LOG="$BUILD_LOG" \
DERIVED_DATA_PATH="$DERIVED_DATA_PATH" \
OUTPUT_DIR="$OUTPUT_DIR" \
SIMULATOR_NAME="$SIMULATOR_NAME" \
SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' \
XCCONFIG_PATH="$PRIVATE_XCCONFIG" \
  "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-installable-simulator-uiqa.sh"

# shellcheck source=/dev/null
source "$OUTPUT_DIR/install.env"
RESULT_FILE="$DATA_CONTAINER/Documents/identity-challenge-login-recovery-smoke-result.json"
rm -f "$RESULT_FILE"

touch "$RUNTIME_LOG"
xcrun simctl launch --console "$SIMULATOR_UDID" "$BUNDLE_ID" \
  DJRunIdentityChallengeLoginRecoverySmoke \
  "DJUIQAIdentityChallengeCode=$UIQA_CODE" > "$RUNTIME_LOG" 2>&1 &
CONSOLE_PID="$!"

deadline=$((SECONDS + LOG_WAIT_TIMEOUT))
while [[ ! -s "$RESULT_FILE" ]] \
  && ! grep -q "$COMPLETION_PATTERN" "$RUNTIME_LOG" 2>/dev/null; do
  if (( SECONDS >= deadline )); then
    fail "Timed out waiting for $COMPLETION_PATTERN"
  fi
  sleep 1
done

[[ -s "$RESULT_FILE" ]] || fail "Result file was not written"
cp "$RESULT_FILE" "$RESULT_COPY_PATH"

python3 - "$RESULT_FILE" "$UIQA_CODE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
raw = path.read_text(encoding="utf-8")
result = json.loads(raw)
assert result.get("completed") is True, result
assert result.get("providerMode") == "synthetic", result
assert result.get("challengeState") == "active", result
assert result.get("deliveryState") == "delivered", result
assert result.get("recoveryState") == "notRequired", result
assert result.get("stateContractVersion") == 1, result
assert result.get("contractVersion") == 1, result
assert result.get("authSessionAdopted") is True, result
assert result.get("authSessionCleared") is True, result
assert "13800009999" not in raw
assert sys.argv[2] not in raw
print(json.dumps(result, ensure_ascii=False, sort_keys=True))
PY

xcrun simctl io "$SIMULATOR_UDID" screenshot "$SCREENSHOT_PATH" >/dev/null
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "[identity-challenge-login-recovery] Result: $RESULT_COPY_PATH"
echo "[identity-challenge-login-recovery] Screenshot: $SCREENSHOT_PATH"
echo "[identity-challenge-login-recovery] Build log: $BUILD_LOG"
echo "[identity-challenge-login-recovery] Backend log: $BACKEND_LOG"
echo "[identity-challenge-login-recovery] Runtime log: $RUNTIME_LOG"
